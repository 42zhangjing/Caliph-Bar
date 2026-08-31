# CaliphBar 发布指南

## 当前发行状态

- 仓库为 Private。
- Release 只对已授权的仓库成员可见。
- App 同时包含 `arm64` 和 `x86_64`。
- 当前使用 ad-hoc 签名，没有 Apple Developer ID 公证，因此 Release 必须标为预发布/测试版。

## 本地构建与验证

```bash
swift test
./build-app.sh
lipo -info CaliphBar.app/Contents/MacOS/CaliphBar
codesign --verify --deep --strict CaliphBar.app
```

预期架构为 `arm64` 和 `x86_64`。

UI 改动还需执行 `design-qa.md` 中的本机验收。CI 通过只能证明可编译、测试通过、架构正确和签名结构有效，不能代替视觉与交互验收。

## 本机安装

```bash
./install.sh
```

脚本会完成下面的操作。

1. 重新构建 App。
2. 退出正在运行的 CaliphBar。
3. 将已安装的旧 App 移到 `~/.Trash/CaliphBar-old-<时间>.app`。
4. 将新 App 安装到 `/Applications`，没有权限时改用 `~/Applications`。
5. 启动新版。

旧 App 保留在废纸篓中，在确认新版正常前可恢复。

## 生成发布包

```bash
./package-release.sh
```

默认输出

```text
dist/CaliphBar-v<版本>-macOS-universal.zip
dist/CaliphBar-v<版本>-macOS-universal.zip.sha256
```

打包脚本会先重新构建，不会直接重用未确认来源的 App。

## GitHub Release 流程

`.github/workflows/release.yml` 监听 `v*` 标签。推送标签后会

1. 检查 tag 版本是否与 `build-app.sh` 中的 App 版本一致。
2. 检查 `docs/releases/<tag>.md` 是否存在。
3. 运行 `swift test`。
4. 构建和打包 Universal App。
5. 上传 ZIP 和 SHA-256 文件。
6. 创建私有预发布。

发布前先确认 `main` 已包含工作流和对应发布说明，然后执行

```bash
git tag v0.2.0
git push origin v0.2.0
```

不得将同一 tag 移向不同 commit。发布有问题时创建新的补丁版本。

## 下载安装和 Gatekeeper

使用者从 Release 下载 ZIP，解压后将 `CaliphBar.app` 拖入“应用程序”。首次启动应先右键并选择“打开”。

当前包没有 Apple 公证，macOS 仍拦截时，在确认 ZIP 来自私有仓库且 SHA-256 匹配后可执行

```bash
xattr -dr com.apple.quarantine /Applications/CaliphBar.app
```

校验下载文件

```bash
shasum -a 256 -c CaliphBar-v0.2.0-macOS-universal.zip.sha256
```

## 发布前检查

- 核心测试通过
- Universal Binary 构建通过
- code signature 验证通过
- Provider 语义没有悄然改变
- 用户可见字符串已本地化
- 文档与数据源/发布流程一致
- 实质 UI 改动已通过本地视觉与交互检查
- tag、App 版本和发布说明一致
- ZIP 可解压，内含可执行的 App
- Release 资产的 SHA-256 与本地结果一致

## 未来的正式发行

如果以后需要面向公众提供无警告的正式安装体验，还需要

1. 稳定的 Apple Developer ID 签名
2. Apple 公证和 stapling
3. 签名凭据的 GitHub Actions Secrets 管理
4. 更新机制或明确的手动更新策略
5. 重新核对第三方公共数据的署名和分发条款

签名、公证凭据不得进入仓库。
