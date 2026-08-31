# 第三方说明

CaliphBar 的小型 macOS 工具架构参考了 [momenbuilds/throttle](https://github.com/momenbuilds/throttle)。该项目使用 MIT License。部分窗口管理、用量数据源和降级设计源自此项目，原始 Throttle 版权声明保留在 `LICENSE` 中。

CodexBar 由 Peter Steinberger 及贡献者开发。CaliphBar 在工程设计中参考了它的 Provider 边界、Claude/Codex 认证行为、Keychain 授权弹窗控制、缓存数据标记、刷新机制，以及已经公开记录的 Antigravity 本地额度协议，包括进程发现、本地 loopback language-server 接口与 quota-summary 字段语义。

CaliphBar 的 Antigravity 探测器是独立的小型实现，没有内置或复制 CodexBar 代码库。

CodexBar 使用 MIT License。Copyright (c) 2026 Peter Steinberger.

所有 Provider 名称和商标均归各自权利人所有。CaliphBar 与 Anthropic、OpenAI 或 Google 没有关联。
