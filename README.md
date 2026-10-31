# proxy-rules

个人路由规则集与 Geo 镜像，供 Sing-Box / PassWall 一类客户端使用。不含代理节点，也不含订阅源。

## direct-personal（直连）

- 国内银行及相关域名
- Microsoft / Microsoft Store / Live / Office / Azure / Xbox / Windows Update 家族
- OneDrive / SharePoint 家族
- Steam 下载与内容 CDN（游戏下载走直连）
- 家庭用私有局域网网段

## proxy-personal（强制代理）

- Steam 商店、社区、结账与登录（与下载 CDN 直连分开）
- GitHub 及相关（github.com、githubusercontent、githubassets、github.io、ghcr 等）
- Grok / xAI
- Cursor / cursor.sh 相关

## 引用（分支 `main`）

- Raw：`https://raw.githubusercontent.com/qiaoyy1983/proxy-rules/main/sing-box/rule-set/<name>.json`
- jsDelivr：`https://cdn.jsdelivr.net/gh/qiaoyy1983/proxy-rules@main/sing-box/rule-set/<name>.json`

`<name>` 如 `direct-personal`、`proxy-personal`；同路径亦可引用 `.srs` 与 `geo/`、`passwall/`。
