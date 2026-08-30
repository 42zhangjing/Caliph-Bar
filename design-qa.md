# CaliphBar Side Notch 设计验收

## 视觉真值

- 主参考：`/var/folders/19/54vhtbcd5_56kjlrdrp4n8qh0000gn/T/codex-clipboard-7677bfa3-aea1-4494-91c8-2a6e0634b09e.png`（2000 × 2000）
- 主参考近景：`/var/folders/19/54vhtbcd5_56kjlrdrp4n8qh0000gn/T/codex-clipboard-04c28550-36ac-4965-9e57-56460cad9d5f.png`（261 × 582）
- 动态参考：`/Users/chengyu/Downloads/1000050786_小萌GIF_20260830_213801.gif`（264 × 240，204 帧）
- 实现截图：`/tmp/caliphbar-final-desktop-v2.png`（3840 × 2486，macOS 1920 × 1243 @2x）
- 指针近景：`/tmp/caliphbar-pointer-detail-v2.png`（840 × 480）
- 同屏比较：`/tmp/caliphbar-design-comparison-v2.png`（参考近景在左，实现状态在右）

## 验收状态

- 屏幕：内建主屏，逻辑视口 1920 × 1243。
- 侧栏：右侧、展开态，物理屏幕边缘 0 间隙。
- 详情：Codex 选中态，指针中心与 Codex 行中心对齐。
- 指针：30pt 长针尖；卡片边缘先向内回收 12pt，再以镜像三次贝塞尔过渡到针尖；针尖与侧栏保持 8pt 空隙。
- 圆环：内底为黑色；未选中 Provider 的官方彩色 Logo 不降亮度。
- 信息语义：继续使用剩余额度和剩余色阶，没有照搬参考图的 Used 语义。

## 对照发现与修正

1. 初始详情卡跟随整条侧栏中心，而不是点击项：改为按 Provider 行中心计算锚点。
2. 初始上下轮廓靠近 Claude/Gemini：侧栏增高到 344pt，并增加首尾留白。
3. 初始 Mini Notch 在透明窗口中居中，视觉上没有贴边：改为按左右侧显式贴齐，窗口继续使用物理屏幕 frame。
4. 初始指针短且与卡片分离：详情卡与指针改为同一个 Path。
5. 第一版一体指针根部向外鼓：移除外伸肩部，改成向卡片内部回收的双凹 S 曲线，并让控制点在针根处保持连续方向。
6. 初始浮窗入场动画留下 12pt 偏移：改为直接落在目标 frame，仅保留透明度过渡；实测最终间隙为 8pt。

## 交互检查

- Claude、Codex、Gemini 使用同一套精确行中心锚点。
- 侧栏已实测从右侧拖到左侧，再拖回右侧；两侧均贴物理屏幕边缘。
- 自动折叠使用窗口级 mouseMoved 监听，移入展开、移出延迟折叠。
- 状态栏入口继续打开完整详情面板；侧栏点击打开紧凑单 Provider 面板。

## 可接受差异

- P3：参考图使用白色单色 Logo；本项目按既定品牌规范保留官方彩色 SVG。
- P3：参考图展示 Used；本项目按产品规范继续展示 Remaining。
- P3：圆环内底按本轮用户确认恢复为黑色。

## 结论

没有发现 P0、P1 或 P2 级视觉/交互问题。

final result: passed
