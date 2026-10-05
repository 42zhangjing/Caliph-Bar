# Reset Radar 公共情报层

CaliphBar 使用 [AIHOT Codex 重置监控](https://aihot.news/codex-reset)。公共事件与账户真实额度、百分比和账户重置倒计时完全独立，公共接口不接收本地凭据、对话或额度。

## 来源与协议

- JSON：`GET https://aihot.news/api/v1/codex-resets/recent`。
- 2026-10-05 核对 [官方 OpenAPI](https://aihot.news/openapi-v1.json) 与实时响应；schemaVersion 为 1，忽略未知可选字段，不支持的 schema major 明确失败。
- 每 10 分钟轮询，包括手动打开面板或刷新；使用 `If-None-Match`、ETag 与系统自动压缩，User-Agent 为 `aihot-api/2.0.0 CaliphBar`。
- 15 秒请求、20 秒资源超时；429/503 尊重 Retry-After（至少 10 分钟）。
- recent 包含近 7 天及仍待生效事件。每次替换快照，不拼接历史，撤回、更正立即生效。
- 独立 AIHOT 缓存 key，不读取旧 Codex Radar 概率缓存。304 只刷新本次读取时间，不冒充来源的新核验时间。
- 核验时间以 checkedAt（回退 monitor.lastVerifiedAt）为准，不用事件日期或 HTTP 请求时间替代。monitor 的 delayed、attention、unknown，缺少核验时间，以及来源/本地读取超过两小时，均显示陈旧。

## 事件语义

直接额度重置优先展示，待生效直接重置优先于历史已确认记录；只有重置卡事件时明确显示重置卡，不解释为额度已恢复。适用范围优先使用 presentation.scopeLabel，缺失时显示未说明，绝不由旧兼容字段 label 推断全员适用。

- announced：已宣布，WATCH。
- in_progress：进行中，HOT。
- expired_unconfirmed：预计窗口已过、等待确认，WATCH。
- likely_completed：AIHOT 判断应已生效但未确认，WATCH。
- confirmed：历史已确认记录，QUIET；不表示用户账户到账，不作为新的进行中信号。
- 无事件或未知事件类型：没有可确认的新重置事件。

`estimate` 是 AIHOT 派生预计窗口，`schedule` 是公告原时间转换，均不是到账凭证。`confirmedAt` 是确认帖时间，不是精确执行或个人到账时间。界面中文和英文分别呈现这些语义，不通过帖子里的“done”等关键词猜测状态。不显示旧来源的 24/48 小时概率，不预测尚未宣布的下一次重置。

陈旧判断先于活跃状态；旧公告不会永久压过陈旧提示。通知仍只在 WATCH/HOT 明显升级时发出，首次启动不重放旧事件。公共接口失败不会阻塞账户刷新。

## 本机确认

本机额度跃升必须来自新的 Codex LIVE 观测，并伴随重置边界变化；只有新鲜公共 WATCH/HOT 直接重置信号同时存在，才显示本机关联确认。少量本地百分比/重置时间记录仅存设备，不上传。

## 使用规则

已核对 [AIHOT 公开使用规则 1.1](https://aihot.news/terms)（2026-09-30）。个人非商业、公益非商业和组织内部使用允许免费访问；匿名访问不等于无限再分发许可。对外商业产品、收费服务、公开镜像或批量公开再分发等需提前取得书面授权。CaliphBar 展示来源 AIHOT 并链接回原页面；只保存本机必要的小快照，不托管共享镜像。开源代码许可不等于 AIHOT 服务或内容许可，未来商业发行前重新核验授权范围。
