# proxy-rules（个人翻墙规则集）

只维护**路由规则 / Geo 镜像**，不托管节点或订阅。由 Debian 中枢每日自动拉取公开源并合并个人定制后推送到本仓库。

## 客户端怎么填

仓库：`https://github.com/qiaoyy1983/proxy-rules`（分支 `main`）

### GUI.for.SingBox / sing-box

个人额外直连（source JSON，始终可用）：

- `https://raw.githubusercontent.com/qiaoyy1983/proxy-rules/main/sing-box/rule-set/direct-personal.json`
- `https://cdn.jsdelivr.net/gh/qiaoyy1983/proxy-rules@main/sing-box/rule-set/direct-personal.json`

个人额外代理（薄名单）：

- `https://raw.githubusercontent.com/qiaoyy1983/proxy-rules/main/sing-box/rule-set/proxy-personal.json`
- `https://cdn.jsdelivr.net/gh/qiaoyy1983/proxy-rules@main/sing-box/rule-set/proxy-personal.json`

二进制 rule-set（`.srs`，若本构建已产出）：

- `.../sing-box/rule-set/direct-personal.srs`
- `.../sing-box/rule-set/proxy-personal.srs`

**国内直连主体**请用公开 CN 库（本仓库已镜像，也可直链官方 latest）：

- 本仓：`geo/geosite-cn.db`、`geo/geoip-cn.db`
- 官方：`https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite-cn.db`
- 官方：`https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip-cn.db`

个人 rule-set **只做额外直连**（家里 NAS 网段、`sub.peterlogs.com` 等），不要指望它替代 `geosite-cn`。

### 旁路由 / PassWall / Xray

- `https://raw.githubusercontent.com/qiaoyy1983/proxy-rules/main/passwall/geosite.dat`
- `https://raw.githubusercontent.com/qiaoyy1983/proxy-rules/main/passwall/geoip.dat`

来源：Loyalsoldier/v2ray-rules-dat（构建时写入 `meta.json` 的 tag）。

## 更新频率

- systemd user timer：每天 **05:17 Asia/Shanghai**
- unit：`~/.config/systemd/user/proxy-rules-build.timer` / `.service`
- 失败：写入 `logs/build.log`，并经中枢已有 `~/.config/alert-bot`（ALERT_BOT_TOKEN / ALERT_CHAT_ID）发 Telegram；告警不可用时**仅记日志**

## 目录

```
custom/                 # 个人源文件（改这里）
sing-box/rule-set/      # 生成的 rule-set JSON / SRS
geo/                    # sing-geosite / sing-geoip 镜像
passwall/               # Loyalsoldier dat 镜像
meta.json               # 构建时间与源 tag、文件 sha256
scripts/build-and-publish.sh
backups/bak-*/          # 每次构建前快照（本地，不入库）
```

## 回滚

1. 本地：`cp -a backups/bak-YYYYMMDD-HHMMSS/* .` 后重新 `git add -A && git commit`（有 token 再 push）
2. 已推送：`git log --oneline` → `git revert <bad>` → `git push`，或硬回退到上一 commit 后 force-with-lease（慎用）
3. 客户端：改回上一个可用 raw URL / 或暂时改用官方 latest 直链

## 构建机说明

- 主机：Debian 中枢 `/home/peter/proxy-rules`
- 不碰腾讯订阅机、马来节点、PassWall 节点配置
- 推送需要 fine-grained PAT（`contents:write`）；无 token 时只本地构建 + commit，不 push

## 本机

- 目录：`/home/peter/proxy-rules`
- sing-box 二进制：`/home/peter/proxy-rules/.bin/sing-box`（gitignore，不入库）
- 首次 GitHub 推送：需 fine-grained PAT（`contents: write`），放入 `~/secrets/GITHUB_TOKEN` 或环境变量后重跑构建脚本。
