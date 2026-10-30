# proxy-rules

个人路由规则与 Geo 镜像仓库（**不含节点 / 订阅**）。由构建机定时拉取公开源、合并  后推送。

## 引用方式

分支：

Sing-box rule-set（JSON）：

- 
- 
- jsDelivr：

二进制 （同目录）： / 

Geo 镜像：、、、  
PassWall / Xray dat：、

个人 rule-set 只是**额外**名单；国内直连主体请仍使用  / （本仓镜像或官方 latest）。

## 客户端建议（geosite 类目）

在客户端路由中优先引用公开类目（本仓已镜像 ），个人 rule-set 作补充：

| 用途 | 建议 geosite 类目 |
|------|-------------------|
| 中国银行 | （可选 ） |
| 微软全家桶 | （可选 、、、） |
| OneDrive |  |
| 游戏平台下载 CDN |  |
| Steam（整包，含商店+CDN） |  — 若要「下载直连 / 商店代理」，请用本仓  +  拆分，勿只靠  |

## 更新

- 定时：每天约 05:17（Asia/Shanghai）自动重建并推送
- 构建元数据：
- 失败记 ；若配置了告警则额外通知

## 回滚

commit eb0b27a6fa9fe49cfb1e6678b75124c945706ddb
Author: YuanYuan Qiao <qiaoyy@qq.com>
Date:   Fri Oct 30 18:17:09 2026 +0800

    chore: accept GITHUB_PROXY_RULES_PAT for publish

commit 99608b0fcbb78a11c54ac3315b925a914409456f
Author: YuanYuan Qiao <qiaoyy@qq.com>
Date:   Fri Oct 30 18:15:33 2026 +0800

    docs: note alert-bot notify and local paths

commit 0a00c69e2cd6a035539d82b2ff9e5aac01e6aa74
Author: YuanYuan Qiao <qiaoyy@qq.com>
Date:   Fri Oct 30 18:15:21 2026 +0800

    chore: rebuild proxy-rules 20261030-181419 (geosite 20261028111806 geoip 20261012 v2ray 202610292204)

commit 388d150566842bea25e6ad65ba00f494d4b6387d
Author: YuanYuan Qiao <qiaoyy@qq.com>
Date:   Fri Oct 30 18:13:42 2026 +0800

    chore: rebuild proxy-rules 20261030-181214 (geosite 20261028111806 geoip 20261012 v2ray 202610292204) →  → push；或客户端暂时改用官方 geosite/geoip latest。
