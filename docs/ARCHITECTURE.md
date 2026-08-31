# CaliphBar 架构

## 产品边界

CaliphBar 是一款轻量的 macOS 菜单栏额度监控工具。项目应保持小巧、本地优先和容易扩展，不要演变成通用的多 Provider 平台框架。

最重要的架构规则是，账户真实数据和公共情报是同一 App 中两个分离的层。

```text
                           CaliphBar
                              │
             ┌────────────────┴────────────────┐
             │                                 │
      第 1 层  账户真实数据              第 2 层  公共情报
      “我的额度是多少”              “全局正在发生什么”
             │                                 │
      Claude / Codex /                Reset Radar / 未来公共信号
      Antigravity 本机数据
             │                                 │
             └────────────── UI 组合 ─────────────┘
```

公共情报可以提供背景、警报和概率，不能覆盖、重新解释或冒充账户真实额度和重置时间。

## 核心模型

账户 Provider 返回统一的 `ProviderFetchResult` / `ProviderSnapshot`。共享 UI 只消费 snapshot，不包含 Provider 特定的网络、凭据或解析逻辑。

每个 Provider 负责

- 数据源发现
- 身份验证与凭据边界
- 数据解析
- 回退顺序
- 错误语义

共享 App 服务负责

- 定时器与分 Provider 刷新协调
- 最近一次有效快照
- 通知
- 开机启动
- 选择状态与界面展示

## 账户真实数据

### Claude

优先从 Anthropic 读取真实 usage。后台 Keychain 读取保持非交互式。实时读取失败时，近期有效快照可标记为 `STALE`；只有符合回退条件时才可使用本地日志估算，并标记为 `ESTIMATED`。

### Codex

优先调用官方本机 `app-server` JSON-RPC 方法 `account/rateLimits/read`。成功回应属于账户真实数据，标记为 `LIVE`。CaliphBar 不读取 Codex OAuth token，不直接调用 ChatGPT 私有 HTTP usage 接口。

某些 macOS 上的 alpha CLI 会在 stdin 保持打开时缓冲 JSONL stdout。CaliphBar 因此执行有时限、只读的单次握手和快照请求，然后关闭 stdin 使官方响应刷出。该读取按普通刷新周期重复，不会阻塞 Claude 或 Antigravity 先行回填。

`rateLimitsByLimitId` 中的模型特定窗口属于账户真实数据。例如 Codex Spark 限制应作为额外窗口显示，不得折叠进普通两条额度。映射5 小时/周额度时优先使用窗口时长元数据，不依赖传输槽位顺序。

本地 `rollout-*.jsonl` 只是回退证据。已过重置时间的窗口会被丢弃，可用回退只能标记为 `STALE`。

### Antigravity

CaliphBar 发现正在运行的 Antigravity 本地 language server，并请求 loopback quota summary。也可使用已支持且正在运行的本地回退。自签名 TLS 信任放宽只允许用于 loopback 主机。

## 公共情报层

公共情报必须与 Provider snapshot 管线独立，使第三方中断无法让 Claude、Codex 或 Antigravity 显示为不可用。

```text
RadarClient
  ├─ 获取公共摘要
  ├─ 可选的已授权 API
  └─ schema 验证

RadarCache
  ├─ 最近一次有效 payload
  ├─ ETag / Last-Modified
  └─ 旧数据时长

RadarInterpreter
  ├─ 保留来源状态和证据
  ├─ 派生可展示的严重程度
  └─ 不虚构来源事实

RadarNotifier
  ├─ 状态迁移去重
  └─ 只发送高价值提醒
```

详见 `docs/CODEX_RADAR_INTELLIGENCE.md`。

## UI 界面

- 屏幕边缘侧栏用于快速查看 Provider 和剩余额度。
- 紧凑详情面板保持固定外部尺寸，Provider 悬停切换时平滑移动指针。Codex/Antigravity 可显示最多四条额度窗口。
- 菜单栏完整面板包含 Provider 切换、设置和更完整的信息，切换时保持稳定尺寸。
- Reset Radar 在完整面板中属于次级公共情报，可选择作为独立的第四项常驻模块。

## 持久化

UserDefaults 只保存轻量 UI 偏好和当前选择。最近一次有效的账户快照单独缓存。公共情报缓存与账户快照完全分开，使 schema 和旧数据策略可以独立演进。

## 网络原则

- 每个网络请求都有明确超时。
- 语义安全时，失败应保留近期有用数据并标记为旧数据。
- Loopback TLS 例外不得应用到远程主机。
- 凭据和秘密 header 不得进入诊断。
- 公共端点属于第三方依赖，不得阻塞账户真实数据刷新。

## 扩展 CaliphBar

新增账户 Provider 时，实现 `UsageProvider` 并隔离 Provider 特定代码。新增公共情报源时，不得把它伪装成账户 Provider。应在情报层增加独立模型、缓存和通知，然后组合到合适的 UI。
