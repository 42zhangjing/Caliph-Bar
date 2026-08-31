# CaliphBar 维护手册

这是在不同 Agent、对话和 Mac 之间维护 CaliphBar 的操作手册。

## 新对话怎么恢复上下文

新维护者不应要求用户重新讲一遍项目历史。应从 GitHub 开始。

1. 读取 `README.md`。
2. 读取 `AGENTS.md`。
3. 读取 `docs/ARCHITECTURE.md` 和与任务相关的文档。
4. 检查最新 `main`、近期提交/PR 和 CI。
5. 读取当前实现文件后再提出方案。

可以在新对话中使用下面的指令。

```text
继续维护我的 GitHub 项目 42zhangjing/Caliph-Bar。
先读取 README.md 和 AGENTS.md，检查最新 main、近期 PR 和 CI，从仓库恢复项目上下文。不要根据聊天记忆推测当前代码。然后处理我的下一个要求。
```

## 日常改动流程

```text
main
  ↓
聚焦的功能分支
  ↓
实现 + 测试 + 文档
  ↓
PR
  ↓
macOS CI
  ↓
合并
  ↓
必要时在本机安装和视觉验收
```

不要将无关的 UI、Provider 和构建系统改动堆进同一个巨大分支。

## 改代码之前

```bash
git status
git branch --show-current
git log -5 --oneline
git fetch origin
git rev-list --left-right --count HEAD...origin/main
```

如果存在本地改动，先报告并保留。没有明确授权，不得用 `git reset --hard` 解决分歧。

## 合并后的本机安装

本机 Agent 只负责安装和验证时，使用受限指令。

```text
不要修改源代码。

cd Caliph-Bar
git checkout main
git pull --ff-only origin main
git rev-parse HEAD

./build-app.sh
./install.sh

验证指定行为并只回报截图/结果。不要提交或推送改动。
```

`install.sh` 会自动退出旧进程，将旧 App 移到废纸篓，再安装和启动新版。需要精确复现时，在指令中附上预期 commit SHA。

## 调试 Provider

### Claude

只报告不敏感状态，例如是否找到凭据、数据源状态、百分比、重置时间和用户可见错误。不得输出 credential JSON 或 Keychain 值。

### Codex

优先检查 `app-server` 返回的 `rateLimits` 结构。只读取额度所需字段，不得输出对话内容。实时读取失败时，才检查本地 rollout 的未过期窗口。缺少真实数据时应显示不可用，不得估算。

### Antigravity

可以检查进程名、PID、loopback 监听端口、响应状态和清理过的 quota bucket 元数据。不得打印 CSRF token 或其他凭据。

## 公共数据源维护

对 Reset Radar 或未来公共情报源

- 编码前核对当前端点和 schema
- 检查署名、授权和访问频率要求
- 使用独立缓存
- 容忍未知或新增字段
- 优先使用来源定义的严重程度/概率
- 保存足够的状态指纹来跨重启去重通知
- 中断不得影响账户 Provider

## UI 回归维护

修改侧栏或详情面前先读取 `design-qa.md`。静态截图无法证明动效和悬停问题已解决。涉及动效时，优先保留 5–10 秒的屏幕录像，不要只比较多张静态图。

侧栏轮廓是高风险视觉表面。修改时应保留窗口尺寸、内容安全区、屏幕外防缝、左右镜像和图标坐标，优先只调整必要的贝塞尔控制点。

## 依赖约束

CaliphBar 应保持轻量。增加 package/framework 前先确认 Foundation、AppKit 或 SwiftUI 是否已能干净完成任务。不要为一个小功能引入庞大的传递依赖树。

## 文档漂移

Provider、端点、回退顺序、UI 约束、版本或发布步骤改变时，在同一 PR 中更新持久文档。实现已变成真实数据时，删除 `placeholder`、`unimplemented` 等过期描述。
