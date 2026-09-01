# CaliphBar

CaliphBar 是一款轻量的 macOS 菜单栏应用，用来查看 Claude Code、Codex 和 Antigravity 的额度与重置时间。它可以将一条小型侧栏常驻在屏幕边缘，也可从菜单栏打开完整管理面板。

> 当前仓库为私有项目。GitHub Release 只对已授权的仓库成员可见。

## 下载与安装

从仓库的 [Releases](https://github.com/42zhangjing/Caliph-Bar/releases) 页面下载最新的 `CaliphBar-v*-macOS-universal.zip`。压缩包同时支持 Apple Silicon 和 Intel Mac，系统要求为 macOS 13 或更高版本。

1. 退出正在运行的 CaliphBar。
2. 解压下载文件。
3. 将旧的 `/Applications/CaliphBar.app` 移到废纸篓。
4. 将新的 `CaliphBar.app` 拖入“应用程序”。
5. 第一次启动时，右键应用并选择“打开”。

更新时不需要清理偏好设置或缓存。新旧版本使用同一个 Bundle ID，替换 App 不会丢失语言、侧栏位置等设置。不要同时运行两份 CaliphBar。

当前测试包使用 ad-hoc 签名，尚未经过 Apple Developer ID 公证。如果 macOS 仍然拦截，可在确认文件来自本私有仓库后执行

```bash
xattr -dr com.apple.quarantine /Applications/CaliphBar.app
```

## 当前功能

### 额度数据

- **Claude Code**  可用 Claude Code 凭据存在时，从 Anthropic OAuth usage 接口读取准确账户用量。后台 Keychain 读取不会弹出系统授权框。实时数据暂时不可用时，优先保留最近一次有效值，之后才使用本机 JSONL 日志估算，并明确标记为 `ESTIMATED`。
- **Codex**  优先通过本机 Codex `app-server` 的 `account/rateLimits/read` 读取当前额度。本地 rollout JSONL 只是回退数据，过期窗口不会显示为 `LIVE`。CaliphBar 不估算 Codex 额度，也不直接调用 ChatGPT 私有后端。
- **Antigravity**  从正在运行的 Antigravity 2.x 本机 `language_server` 读取真实 quota summary。也支持已登录且已运行的 `agy` 进程作为本机回退。应用不抓取 Antigravity UI，不调用 Google 远程 OAuth 额度接口。
- **Reset Radar**  独立读取 Codex Radar 公共结构化摘要，显示额外重置信号和 24/48 小时概率。它属于公共情报，不会改动或冒充用户的真实 Codex 额度。

### 界面与交互

- 默认三项侧栏的可见尺寸为 `62 × 288` pt，开启独立 Radar 后为 `62 × 328` pt。
- 侧栏是一条连续的自定义贝塞尔路径，可停靠在屏幕左侧或右侧。
- 侧栏外观支持“经典把手”与“优雅剪影”切换：剪影模式基于 35 条原生矢量贝塞尔子路径绘制，未悬停时保持极简黑色剪影，悬停时 4 处身体部位定点（Claude=头部、Codex=胸部、Antigravity=臀部、Radar=底座）自然淡入显现，并精准联动详情卡片。
- 支持上下拖动、左右切换、恢复居中和自动收起；剪影模式在收起（152 pt）与展开（360 pt）间保持等比无缝过渡。
- 悬停在 Provider 上时显示固定尺寸的紧凑详情卡，切换时卡片不会跳动改变大小。
- 菜单栏主面板使用等宽 Provider 切换和稳定尺寸。
- 侧栏圆环内芯可在深色与暖瓷白之间显式切换；浅色方案会同步校准 Provider 标志与 Radar 色彩，并持久保存选择。
- 菜单栏和侧栏额度共用同一快照、百分比取整与阈值语义，并根据各自的浅色或深色背景保持可读对比。
- 设置支持简体中文、English 和跟随系统。
- 开关会同时显示开/关文字和颜色状态，不再只显示白色胶囊。
- Provider 分别刷新并及时回填，不必等最慢的数据源。
- 额度和概率数字使用系统等宽数字，数值变化时不会水平抖动。

### 其他功能

- 额度低于设定阈值时，每个窗口只通知一次。
- Radar 只在信号明显升级时通知，避免重复打扰。
- 支持开机启动。
- 账户数据每 60 秒自动刷新，Radar 每 5 分钟独立刷新。
- 保存最近一次可用的真实账户快照。
- 生成同时包含 `arm64` 与 `x86_64` 的 Universal Binary。

## 数据状态怎么理解

- `LIVE`  当前数据源的实时读取。
- `STALE`  实时读取失败后显示的较旧本机数据。
- `ESTIMATED`  基于本地记录得出的估算值，不是账户的精确额度。
- `OFFLINE`  暂时没有可用数据。
- Radar 的“数据超 2 小时未更新”  表示 24/48 小时概率来自旧缓存，不表示重置机会已经错过。

## 本地开发与安装

需要 macOS 13 以及 Xcode 或 Xcode Command Line Tools。

```bash
swift test
./build-app.sh
open CaliphBar.app
```

`build-app.sh` 会生成 ad-hoc 签名的 Universal App，Bundle ID 为

```text
dev.chengyu.caliphbar
```

安装到“应用程序”并启动

```bash
./install.sh
```

该脚本会退出正在运行的 CaliphBar，将旧 App 移到废纸篓，再安装和打开新版。

生成 Release ZIP 和 SHA-256 校验文件

```bash
./package-release.sh
```

项目使用 SwiftPM，可在 Xcode 中直接打开 `Package.swift`，不需要生成 `.xcodeproj`。

## 数据来源与安全边界

### Claude

CaliphBar 依次检查 `~/.claude/.credentials.json`、macOS Keychain 中的 `Claude Code-credentials`、Anthropic usage 接口、最近的有效快照和本地 Claude 日志估算。后台读取不会主动弹出 Keychain 授权。如果需要授权，只有用户在设置中主动点击“修复权限”才会触发。

### Codex

CaliphBar 使用只读、有时限的本机 JSON-RPC 交互请求 `account/rateLimits/read`。它不读取 Codex OAuth token，不尝试绕过或延长额度。当 app-server 不可用时，只会从本地 rollout JSONL 中寻找未过期的历史观测。

### Antigravity

CaliphBar 只连接字面地址 `127.0.0.1` 或 `localhost` 的 Antigravity 本机服务。自签名 TLS 信任放宽不会被应用到远程主机。日志和问题报告中不得出现 CSRF token 或凭据。

### Reset Radar

当前版本每 5 分钟读取

```text
https://codexradar.com/current.json
```

请求中不包含 Codex 凭据、本地额度或对话内容。Radar 缓存与账户额度快照完全分离。界面中的概率使用中性样式，只有“值得关注”和“强信号”状态会引入黄/红紧迫色。

## 产品架构

CaliphBar 始终分开两类信息。

```text
第 1 层  账户真实数据
用户自己的额度、数据源状态和重置时间

第 2 层  公共情报
社区/公开重置信号和历史概率
```

公共情报可以增加背景和提醒，不能改写账户真实数据。详见 `docs/ARCHITECTURE.md`。

## 项目结构

```text
Sources/
  CaliphBarCore/       Provider 模型、解析和数据获取
  CaliphBar/           App 状态、服务和 UI
Tests/                 核心解析与模型测试
Resources/             图标与资源
docs/                  架构、维护、发布与 Radar 文档
```

## 维护文档

- `AGENTS.md`  AI Agent 和人类维护者都必须遵守的工作约定
- `docs/ARCHITECTURE.md`  产品与数据层架构
- `docs/MAINTENANCE.md`  跨 Agent 维护、调试与本机安装流程
- `docs/RELEASE.md`  构建、打包和 Release 检查清单
- `docs/CODEX_RADAR_INTELLIGENCE.md`  Reset Radar 公共情报架构
- `design-qa.md`  持久的 UI 与交互回归检查清单

GitHub `main` 是项目唯一可信的持久状态。新对话或新 Agent 应从仓库恢复上下文，不要把聊天记忆当作当前代码。

## 隐私

CaliphBar 是本地优先应用。Claude 凭据只会发往 Anthropic 自己的 usage 接口；Codex 额度通过本地 CLI app-server 查询；Antigravity 通过回环地址读取；Radar 只执行普通的公共数据 GET 请求。应用不运行 CaliphBar 后端，不上传对话、凭据、额度历史或使用记录。

不要在 issue、日志、截图或聊天中粘贴 credential 文件、Keychain 值、OAuth token、cookie、CSRF token 或 API key。

## 开源与签名说明

项目当前保留 MIT `LICENSE` 和第三方声明，仓库可见性为 Private。`build-app.sh` 使用 ad-hoc 签名保持稳定 Bundle ID。如需无警告的公开发行，还需要稳定的 Apple Developer ID 签名和公证。
