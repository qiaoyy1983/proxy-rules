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

