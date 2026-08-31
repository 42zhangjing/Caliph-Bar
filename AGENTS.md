# CaliphBar Agent 维护指南

这是 CaliphBar 的持久交接契约，适用于 AI Agent 和人类维护者。GitHub `main` 是代码和项目上下文的唯一可信来源。不得把聊天记忆当作项目当前状态。

## 每次任务的起点

1. 读取 `README.md`、本文件和 `docs/` 中与任务相关的文档。
2. 拉取最新仓库状态，检查 `main`、最近提交/PR、CI 和工作区。
3. 工作区有未提交内容时必须保留。没有用户明确授权，不得 reset、checkout 覆盖或丢弃。
4. 修复之前先从当前代码确认实际行为，不得假设旧对话仍与 `main` 一致。

建议预检

```bash
git fetch origin
git checkout main
git pull --ff-only origin main
git status
git log -5 --oneline
```

## 维护与所有权模型

- GitHub 保存持久的项目记忆和标准代码。
- ChatGPT、Codex、Antigravity 和 Claude 都可以作为可替换的维护者。
- 日常 Git 机械操作不应由用户手工协调。
- 仓库当前为 Private。Release 资产、Actions 日志和 PR 不得包含任何凭据或私人数据。

能通过 GitHub 完成的实质改动，通常执行下面的完整链路。

```text
功能分支 → 实现 → 测试/CI → PR → 合并
```

最终验收依赖用户 Mac 时，给本地 Agent 一段只允许拉取、构建、安装、启动和回报结果的指令。

## 分支与合并

- 始终保持 `main` 可构建。
- 非小改动使用聚焦的功能分支。
- 提交应尺寸可审查，提交信息应说清改了什么。
- 功能改动和实质 UI 改动需要 PR。
- 必须等要求的 CI 通过后才能合并。
- 不得通过删除或削弱测试来绕过失败，除非产品行为本身已明确改变，且新测试已记录新行为。

## 必需验证

根据改动范围执行

```bash
swift test
./build-app.sh
lipo -info CaliphBar.app/Contents/MacOS/CaliphBar
codesign --verify --deep --strict CaliphBar.app
```

当前 Agent 不在 macOS 上运行时，GitHub Actions 是 macOS 编译/构建的权威检查。实质 UI 改动还必须执行 `design-qa.md` 中的本机视觉和交互验收。

## 产品架构约束

CaliphBar 有两个必须独立的数据层。

### 第 1 层  账户真实数据

该层回答“我的真实额度现在是多少”。

- Claude Code 优先使用 Anthropic usage 数据，回退必须明确区分 `STALE` 和 `ESTIMATED`。
- Codex 优先使用本机 `app-server` 的 `account/rateLimits/read`。本地 `rollout-*.jsonl` 只能作为 `STALE` 回退，不得估算额度。
- Antigravity 使用本机 loopback quota summary 或已支持的本地回退。

公共/社区预测绝不得混入这些百分比和重置时间。

### 第 2 层  公共情报

该层回答“全局是否正在发生异常，我是否需要关心”。例如 Reset Radar 信号、公开重置证据和历史分布。该层在视觉和语义上都必须与账户真实数据分开。详见 `docs/CODEX_RADAR_INTELLIGENCE.md`。

## Provider 安全约束

### Codex

- 默认保持本地优先。
- 实时额度通过官方本机 app-server 读取。
- 不得估算 Codex 额度。
- 本地真实数据已足够时，不得为了方便增加 ChatGPT 私有后端请求。
- 不得尝试绕过或延长额度限制。

### Claude

- 后台 Keychain 读取必须保持非交互式。
- 只有用户的明确操作可以触发 macOS 授权弹窗。
- 不得在日志、截图、issue 或诊断中打印/存储 OAuth token。
- `LIVE`、`STALE`、`ESTIMATED` 和 `OFFLINE` 是实质不同的状态，必须保持可区分。

### Antigravity

- 优先使用本机 `language_server`。
- TLS 信任放宽只能用于字面地址 `127.0.0.1` 和 `localhost`。
- 不得抓取 Antigravity UI。
- 不得在日志或问题报告中暴露 CSRF token 或凭据。
- 没有明确产品决定时，不得悄然增加远程 Google OAuth 额度路径。

## UI 约束

- 浮窗和详情面使用自定义 `NSPanel`，不使用 `NSPopover`。
- 边缘侧栏是一条连续的自定义路径，不得拆成 `Capsule + connector`。
- 展开与收起状态的轮廓以 `Resources/Shapes/caliph-edge-tab.svg` 为唯一几何母版；`SideNotchShape.swift` 必须精确转录该 Path 并保持 `210:1138` 等比缩放，不得近似重画、独立拉伸宽高或用通用圆角形状替换。
- 左右停靠必须严格镜像。
- 默认三项可见尺寸为 `62 × 288` pt，可选四项 Radar 模式为 `62 × 328` pt。屏幕外防缝区不得裁掉上下可见端点。
- 侧栏转角使用曲率逐渐降为 0 的贝塞尔控制点，不得用通用 squircle 替换整条非对称轮廓。
- Provider 切换不得改变紧凑详情卡的外部尺寸。
- 悬停切换只在活动 Provider 真正改变时更新，指针平滑移动。
- 设置必须始终可从完整菜单栏面板进入。
- 支持简体中文、English 和跟随系统，不得增加未本地化的用户可见英文。
- 开关必须明确显示开/关状态。Provider 切换和设置分段的可见区域必须与真实点击区域一致。
- Radar 概率使用中性样式，不得冒用账户额度的红黄绿环。用户可见状态必须明确，不得使用有歧义的 `QUIET`。
- 动效保持克制和仪器感。数据/内容使用短 ease-out，只有侧栏触感交互可使用 spring。

修改 UI 前必须读取 `design-qa.md`。

## 公共情报和第三方数据

集成任何第三方公共 JSON/API 之前必须

1. 从官方文档或实时数据确认端点和当前 schema。
2. 检查署名、派生使用和访问频率要求。
3. 不得把“公网可访问”等同于“可无限制再分发”。
4. 增加超时、独立缓存、旧数据标记和 schema 版本容忍。
5. 公共数据中断不得影响账户真实数据。
6. 必须区分来源事实和 CaliphBar 派生解读。

## 发布和本机安装

- 构建版本、安装方式、ad-hoc 签名限制和 Release 流程以 `docs/RELEASE.md` 为准。
- 发布标签必须与 App 内版本号一致。
- 当前 Release 必须标为私有测试版/预发布，直到完成 Developer ID 签名和公证。
- 替换已安装 App 时，先退出旧进程，并将旧 App 移到废纸篓作为可恢复备份。

本机验收指令模板

```text
不要修改源代码。

cd Caliph-Bar
git checkout main
git pull --ff-only origin main
git rev-parse HEAD

./build-app.sh
./install.sh
pkill CaliphBar 2>/dev/null || true
open /Applications/CaliphBar.app

验证指定行为并回报结果。不要提交或推送改动。
```

需要可复现时，必须附上预期的 `main` commit SHA。

## 文档责任

架构、Provider、发布步骤、数据语义或持久交互约束变化时，必须在同一 PR 中更新对应文档。未来维护者应能只依靠仓库恢复项目上下文。
