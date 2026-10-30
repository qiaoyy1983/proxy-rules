#!/usr/bin/env bash
# Build personal proxy rule-sets + mirror geo packages; optionally push to GitHub.
# Asia/Shanghai. Failures exit non-zero and notify if alert-bot configured.
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE"
export TZ=Asia/Shanghai
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="$BASE/logs/build.log"
mkdir -p "$BASE"/{logs,backups,geo,passwall,sing-box/rule-set,custom,.bin,scripts}

exec > >(tee -a "$LOG") 2>&1
echo "===== build start $STAMP ====="

on_fail() {
  local rc=$?
  echo "===== build FAILED rc=$rc at $(date '+%F %T %Z') ====="
  "$BASE/scripts/notify-fail.sh" "proxy-rules build FAILED on Debian hub rc=$rc at $(date '+%F %T %Z'). See $LOG" || true
  exit "$rc"
}
trap on_fail ERR

# --- backup previous published artifacts ---
BAK="$BASE/backups/bak-$STAMP"
mkdir -p "$BAK"
for d in geo passwall sing-box meta.json README.md; do
  if [[ -e "$BASE/$d" ]]; then
    cp -a "$BASE/$d" "$BAK/" 2>/dev/null || true
  fi
done
# prune old backups keep last 14
ls -1dt "$BASE"/backups/bak-* 2>/dev/null | tail -n +15 | xargs -r rm -rf --

UA='proxy-rules-builder/1.0 (+personal; Debian hub)'
TMP=$(mktemp -d)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

download_sha() {
  # args: url out_path sha_url
  local url="$1" out="$2" sha_url="$3"
  echo "[dl] $url"
  curl -fsSL --retry 3 --retry-delay 2 -A "$UA" -o "$out" "$url"
  local expected actual
  expected=$(curl -fsSL --retry 3 -A "$UA" "$sha_url" | awk 'NF{print $1; exit}')
  actual=$(sha256sum "$out" | awk '{print $1}')
  if [[ -z "$expected" || "$expected" != "$actual" ]]; then
    echo "[err] sha256 mismatch for $out expected=$expected actual=$actual" >&2
    return 1
  fi
  echo "[ok] $(basename "$out") sha256=$actual"
}

# --- ensure sing-box binary (user-local) ---
ensure_singbox() {
  local bin="$BASE/.bin/sing-box"
  if [[ -x "$bin" ]]; then
    "$bin" version 2>/dev/null | head -1 >&2 || true
    printf '%s
' "$bin"
    return 0
  fi
  echo "[info] fetching sing-box linux-amd64 to .bin/" >&2
  local api tag asset url
  api=$(curl -fsSL -A "$UA" https://api.github.com/repos/SagerNet/sing-box/releases/latest)
  tag=$(jq -r '.tag_name' <<<"$api")
  asset=$(jq -r '.assets[].name' <<<"$api" | grep -E '^sing-box-.*-linux-amd64\.tar\.gz$' | grep -vE 'glibc|musl' | head -1 || true)
  if [[ -z "$asset" ]]; then
    asset=$(jq -r '.assets[].name' <<<"$api" | grep -E 'linux-amd64.*\.tar\.gz$' | head -1 || true)
  fi
  if [[ -z "$asset" ]]; then
    echo "[warn] no sing-box linux-amd64 asset; skip compile" >&2
    return 1
  fi
  url=$(jq -r --arg n "$asset" '.assets[] | select(.name==$n) | .browser_download_url' <<<"$api")
  curl -fsSL --retry 3 -A "$UA" -o "$TMP/sing-box.tgz" "$url"
  tar -xzf "$TMP/sing-box.tgz" -C "$TMP"
  local found
  found=$(find "$TMP" -type f -name sing-box | head -1)
  if [[ -z "$found" ]]; then
    echo "[warn] sing-box binary not in archive" >&2
    return 1
  fi
  install -m 0755 "$found" "$bin"
  echo "[ok] installed sing-box $tag -> $bin" >&2
  "$bin" version 2>&1 | head -1 >&2 || true
  printf '%s
' "$bin"
}

# --- pull geo packages ---
GEOSITE_API=$(curl -fsSL -A "$UA" https://api.github.com/repos/SagerNet/sing-geosite/releases/latest)
GEOIP_API=$(curl -fsSL -A "$UA" https://api.github.com/repos/SagerNet/sing-geoip/releases/latest)
V2RAY_API=$(curl -fsSL -A "$UA" https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest)

GEOSITE_TAG=$(jq -r '.tag_name' <<<"$GEOSITE_API")
GEOIP_TAG=$(jq -r '.tag_name' <<<"$GEOIP_API")
V2RAY_TAG=$(jq -r '.tag_name' <<<"$V2RAY_API")

echo "[meta] sing-geosite=$GEOSITE_TAG sing-geoip=$GEOIP_TAG v2ray-rules-dat=$V2RAY_TAG"

base_url_asset() {
  # repo_api_json asset_name -> browser_download_url
  jq -r --arg n "$2" '.assets[] | select(.name==$n) | .browser_download_url' <<<"$1"
}

for pair in \
  "geosite.db|$GEOSITE_API" \
  "geosite-cn.db|$GEOSITE_API" \
  "geoip.db|$GEOIP_API" \
  "geoip-cn.db|$GEOIP_API"
do
  name=${pair%%|*}
  api=${pair#*|}
  url=$(base_url_asset "$api" "$name")
  sha=$(base_url_asset "$api" "${name}.sha256sum")
  download_sha "$url" "$BASE/geo/$name" "$sha"
done

for name in geosite.dat geoip.dat; do
  url=$(base_url_asset "$V2RAY_API" "$name")
  sha=$(base_url_asset "$V2RAY_API" "${name}.sha256sum")
  download_sha "$url" "$BASE/passwall/$name" "$sha"
done

# --- build personal rule-set JSON ---
read_lines() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  awk '
    /^[[:space:]]*#/ {next}
    /^[[:space:]]*$/ {next}
    { gsub(/\r/,""); print }
  ' "$f"
}

mapfile -t DIRECT_DOMAINS < <(read_lines "$BASE/custom/direct-domains.txt")
mapfile -t DIRECT_SUFFIX < <(read_lines "$BASE/custom/direct-domain-suffix.txt")
mapfile -t DIRECT_CIDR < <(read_lines "$BASE/custom/direct-ip-cidr.txt")
mapfile -t PROXY_DOMAINS < <(read_lines "$BASE/custom/proxy-domains.txt")
mapfile -t PROXY_SUFFIX < <(read_lines "$BASE/custom/proxy-domain-suffix.txt")

python3 - "$BASE" <<'PY'
import json, sys, pathlib
base = pathlib.Path(sys.argv[1])

def load(name):
    p = base / "custom" / name
    if not p.exists():
        return []
    out = []
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip().replace("\r", "")
        if not line or line.startswith("#"):
            continue
        out.append(line)
    return out

def norm_suffix(items):
    # sing-box domain_suffix is without leading dot typically; accept either
    return [s.lstrip(".") for s in items]

direct_domains = load("direct-domains.txt")
direct_suffix = norm_suffix(load("direct-domain-suffix.txt"))
direct_cidr = load("direct-ip-cidr.txt")
proxy_domains = load("proxy-domains.txt")
proxy_suffix = norm_suffix(load("proxy-domain-suffix.txt"))

def build(rules_parts):
    rules = []
    for part in rules_parts:
        if part:
            rules.append(part)
    return {"version": 2, "rules": rules}

direct_rules = []
if direct_domains:
    direct_rules.append({"domain": direct_domains})
if direct_suffix:
    direct_rules.append({"domain_suffix": direct_suffix})
if direct_cidr:
    direct_rules.append({"ip_cidr": direct_cidr})

proxy_rules = []
if proxy_domains:
    proxy_rules.append({"domain": proxy_domains})
if proxy_suffix:
    proxy_rules.append({"domain_suffix": proxy_suffix})

direct = build(direct_rules)
proxy = build(proxy_rules)

out_dir = base / "sing-box" / "rule-set"
out_dir.mkdir(parents=True, exist_ok=True)
(out_dir / "direct-personal.json").write_text(json.dumps(direct, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
(out_dir / "proxy-personal.json").write_text(json.dumps(proxy, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("[ok] wrote direct-personal.json rules=%d" % len(direct["rules"]))
print("[ok] wrote proxy-personal.json rules=%d" % len(proxy["rules"]))
PY

# --- compile .srs if sing-box available ---
SB=""
if SB_PATH=$(ensure_singbox); then
  SB="$SB_PATH"
fi
if [[ -n "$SB" && -x "$SB" ]]; then
  "$SB" rule-set compile "$BASE/sing-box/rule-set/direct-personal.json" -o "$BASE/sing-box/rule-set/direct-personal.srs"
  "$SB" rule-set compile "$BASE/sing-box/rule-set/proxy-personal.json" -o "$BASE/sing-box/rule-set/proxy-personal.srs"
  echo "[ok] compiled .srs"
else
  echo "[warn] sing-box unavailable; JSON source only (no .srs)"
  rm -f "$BASE/sing-box/rule-set/"*.srs
fi

# --- meta.json ---
python3 - "$BASE" "$GEOSITE_TAG" "$GEOIP_TAG" "$V2RAY_TAG" "$STAMP" <<'PY'
import json, sys, pathlib, hashlib, os
base = pathlib.Path(sys.argv[1])
geosite_tag, geoip_tag, v2ray_tag, stamp = sys.argv[2:6]

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

files = []
for rel in [
    "sing-box/rule-set/direct-personal.json",
    "sing-box/rule-set/direct-personal.srs",
    "sing-box/rule-set/proxy-personal.json",
    "sing-box/rule-set/proxy-personal.srs",
    "geo/geosite.db", "geo/geosite-cn.db", "geo/geoip.db", "geo/geoip-cn.db",
    "passwall/geosite.dat", "passwall/geoip.dat",
    "custom/direct-domains.txt", "custom/direct-ip-cidr.txt", "custom/proxy-domains.txt",
]:
    p = base / rel
    if p.exists():
        files.append({"path": rel, "bytes": p.stat().st_size, "sha256": sha(p)})

meta = {
    "build_time": stamp,
    "timezone": "Asia/Shanghai",
    "sources": {
        "sing-geosite": {"repo": "SagerNet/sing-geosite", "tag": geosite_tag},
        "sing-geoip": {"repo": "SagerNet/sing-geoip", "tag": geoip_tag},
        "v2ray-rules-dat": {"repo": "Loyalsoldier/v2ray-rules-dat", "tag": v2ray_tag},
    },
    "files": files,
    "notes": "Personal rule-sets are additive extras; clients should also use geosite-cn/geoip-cn for mainland direct.",
}
(base / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("[ok] meta.json files=%d" % len(files))
PY

# --- README ---
HAS_SRS=0
[[ -f "$BASE/sing-box/rule-set/direct-personal.srs" ]] && HAS_SRS=1
cat > "$BASE/README.md" <<README
# proxy-rules

个人路由规则与 Geo 镜像仓库（**不含节点 / 订阅**）。由构建机定时拉取公开源、合并 `custom/` 后推送。

## 引用方式

分支：`main`

Sing-box rule-set（JSON）：

- `https://raw.githubusercontent.com/qiaoyy1983/proxy-rules/main/sing-box/rule-set/direct-personal.json`
- `https://raw.githubusercontent.com/qiaoyy1983/proxy-rules/main/sing-box/rule-set/proxy-personal.json`
- jsDelivr：`https://cdn.jsdelivr.net/gh/qiaoyy1983/proxy-rules@main/sing-box/rule-set/<name>.json`

二进制 `.srs`（同目录）：`direct-personal.srs` / `proxy-personal.srs`

Geo 镜像：`geo/geosite.db`、`geo/geosite-cn.db`、`geo/geoip.db`、`geo/geoip-cn.db`  
PassWall / Xray dat：`passwall/geosite.dat`、`passwall/geoip.dat`

个人 rule-set 只是**额外**名单；国内直连主体请仍使用 `geosite-cn` / `geoip-cn`（本仓镜像或官方 latest）。

## 客户端建议（geosite 类目）

在客户端路由中优先引用公开类目（本仓已镜像 `geo/geosite.db`），个人 rule-set 作补充：

| 用途 | 建议 geosite 类目 |
|------|-------------------|
| 中国银行 | `category-bank-cn`（可选 `category-finance`） |
| 微软全家桶 | `microsoft`（可选 `microsoft@cn`、`azure`、`xbox`、`msn`） |
| OneDrive | `onedrive` |
| 游戏平台下载 CDN | `category-game-platforms-download` |
| Steam（整包，含商店+CDN） | `steam` — 若要「下载直连 / 商店代理」，请用本仓 `direct-personal` + `proxy-personal` 拆分，勿只靠 `steam` |

## 更新

- 定时：每天约 05:17（Asia/Shanghai）自动重建并推送
- 构建元数据：`meta.json`
- 失败记 `logs/`；若配置了告警则额外通知

## 回滚

`git log` → `git revert <bad>` → push；或客户端暂时改用官方 geosite/geoip latest。
README

# --- git commit ---
git -C "$BASE" add -A
if git -C "$BASE" diff --cached --quiet; then
  echo "[info] no changes to commit"
else
  git -C "$BASE" commit -m "chore: rebuild proxy-rules $STAMP (geosite $GEOSITE_TAG geoip $GEOIP_TAG v2ray $V2RAY_TAG)"
fi

# --- push only with token ---
TOKEN=""
if [[ -n "${GITHUB_PROXY_RULES_PAT:-}" ]]; then TOKEN="$GITHUB_PROXY_RULES_PAT"; fi
if [[ -z "$TOKEN" && -n "${GITHUB_TOKEN:-}" ]]; then TOKEN="$GITHUB_TOKEN"; fi
if [[ -z "$TOKEN" && -n "${GH_TOKEN:-}" ]]; then TOKEN="$GH_TOKEN"; fi
# secret files (KEY=value env or bare token). Never echo values.
SECRET_CANDIDATES=(
  "$HOME/secrets/github-proxy-rules-pat"
  "$HOME/secrets/GITHUB_TOKEN"
  "$HOME/secrets/GH_TOKEN"
  "$HOME/secrets/github-token"
)
for f in "${SECRET_CANDIDATES[@]}"; do
  if [[ -f "$f" ]]; then
    if grep -q '=' "$f" 2>/dev/null; then
      # shellcheck disable=SC1090
      set -a; source "$f"; set +a
      TOKEN="${GITHUB_PROXY_RULES_PAT:-${GITHUB_TOKEN:-${GH_TOKEN:-$TOKEN}}}"
    else
      TOKEN=$(head -1 "$f" | tr -d '\r\n')
    fi
    break
  fi
done

REPO_SSH="git@github.com:qiaoyy1983/proxy-rules.git"
REPO_HTTPS="https://github.com/qiaoyy1983/proxy-rules.git"

if [[ -z "$TOKEN" ]]; then
  echo "[skip] no GITHUB_TOKEN/GH_TOKEN — local commit only; 待 PAT 首推"
  echo "EXPECTED_RAW=https://raw.githubusercontent.com/qiaoyy1983/proxy-rules/main/sing-box/rule-set/direct-personal.json"
else
  # configure remote with x-access-token (token not printed)
  if git -C "$BASE" remote get-url origin >/dev/null 2>&1; then
    git -C "$BASE" remote set-url origin "https://x-access-token:${TOKEN}@github.com/qiaoyy1983/proxy-rules.git"
  else
    git -C "$BASE" remote add origin "https://x-access-token:${TOKEN}@github.com/qiaoyy1983/proxy-rules.git"
  fi
  # create repo if missing
  HTTP=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/repos/qiaoyy1983/proxy-rules || true)
  if [[ "$HTTP" == "404" ]]; then
    echo "[info] creating public repo qiaoyy1983/proxy-rules"
    curl -fsS -X POST -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" \
      https://api.github.com/user/repos \
      -d '{"name":"proxy-rules","description":"Personal proxy rule-sets and geo mirrors (no nodes)","private":false,"auto_init":false}' >/dev/null
  fi
  git -C "$BASE" push -u origin main
  # scrub token from remote URL after push
  git -C "$BASE" remote set-url origin "$REPO_HTTPS"
  echo "[ok] pushed to $REPO_HTTPS"
fi

echo "===== build done $(date '+%F %T %Z') ====="
