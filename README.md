# Automated_burger_factory · 自动化汉堡店

基于 TapTap Maker / UrhoX Lua 的自动化汉堡工厂白盒 Demo。

聚光灯 GameJam 参赛项目。

本仓库保存 V0.3 UI 与触屏版本，含本轮人工反馈修复：场景锚定对象卡、教学关闭、传送带单段长按拖动。开发端检查与用户人工验收分别记录，V0.3仍有待复验和手机未测项目。

## 当前功能

- 垂直正交俯视镜头、角色移动与 Shift 双倍奔跑、单件手持和原料/地面物品交换。
- 手工煎肉与汉堡组装，自动三槽烹饪、自动汉堡组合设备。
- 建筑选择、放置、旋转、移动、拆除、连续建造及场景投影固定。
- 汉堡店与自动化车间切换，离开车间后生产继续。
- 实体传送带：0.5 格/秒、单输入单输出、FIFO、容量与回堵、禁止闭环及重叠。
- 十字拓展接口、直通隔离接口、转角隔离接口，缓存台六槽及后进先出输出。
- 建筑 A/B 选择、路径预览与调整、独立确认、连续布线。
- 订单、五份交付库存、收银交付、三天日循环、暂停、每日结算与重新开始。
- V0.3统一HUD、五类建造选型、场景对象卡、缓存先选后执行、统计、设置与阶段教学。
- 手机横屏输入：固定/浮动摇杆、外圈奔跑、共享动作按钮、双指平移/缩放及失焦释放输入。
- 传送带单段电脑/手机统一按住0.35秒后拖动，无四向按钮；端点/转角保留先选再拖及键盘编辑。

## 目录

| 路径 | 内容 |
| --- | --- |
| `scripts/main.lua` | 游戏入口 |
| `scripts/Factory/` | 玩法模块及自检模块 |
| `assets/` | 当前项目资源与生成来源记录；部分美术为未接入提案 |
| `docs/` | 需求、设计、验证证据、验收流程及 V0.3 UI规范 |
| `launch-demo.ps1` | 当前 Windows 本机启动脚本 |
| `待回收/` | 本地隔离的旧工具/临时脚本/日志，含逐文件恢复清单，不上传GitHub |

## 运行说明

游戏需要 TapTap Maker / UrhoX 的运行环境和引擎资源。本仓库是项目源码快照，不是可独立双击运行的成品安装包。引擎文档、示例、`urhox-libs` 参考库、Maker 认证与本机 Runtime 不上传，需通过官方 Maker 本地开发流程配置。

在已具备对应环境的项目目录中，可使用官方本地预览：

```powershell
taptap-maker preview start --target-dir "项目绝对路径" --json
```

`launch-demo.ps1` 目前对应原开发机的 Node 路径和已安装 Maker 0.0.36；其他机器需先核对这些路径与版本。原开发机桌面快捷方式不属于独立游戏程序。

## 版本与验证边界

- V0.3反馈修复开发端回归：403项唯一断言通过、0失败；33个Lua文件语法通过，LSP 0 Error。详情见 `docs/ui-v03-review-fixes.md`。本次上传核对源码SHA256及语法，没有重新执行完整玩法或视觉验收。
- Windows 本地预览仍存在 `Cube/Day/DaySpecularHDR.dds` 缺失与 `themis_x64.dll` 加载错误；进程运行不代表工具完整就绪检查通过。
- 触屏控件与白模UI已实现；小米14 / Android15真机仍未测，也未生成Android安装包。正式UI美术、员工美术与设计图不代表已接入游戏。店内两台初始自动设备已移除，手工台与车间自动机保留。
- 本轮无游戏进度存档；只保存本机UI偏好。验收清单保留用户已反馈结果，U06/U37/U38/U53仍需人工复验。
- 本次 GitHub 备份不触发 Maker 提交、远端构建或发布。

## 开发入口

- 当前画面与功能：[`docs/current-game-ui-information.md`](docs/current-game-ui-information.md)
- 实体物流统一验收：[`docs/conveyor-acceptance.md`](docs/conveyor-acceptance.md)
- R4 编辑交互记录：[`docs/conveyor-editing-fixes.md`](docs/conveyor-editing-fixes.md)
- 下一阶段 UI 需求：[`docs/ui-next-stage-requirements-draft.md`](docs/ui-next-stage-requirements-draft.md)
- V0.3验收清单：[`docs/ui-v03-manual-acceptance.md`](docs/ui-v03-manual-acceptance.md)
- V0.3修复与验证：[`docs/ui-v03-review-fixes.md`](docs/ui-v03-review-fixes.md)
- 本地待回收清单：[`docs/v03-cleanup-manifest.md`](docs/v03-cleanup-manifest.md)
- 手机 UI 通用清单：[`docs/mobile-ui-planning-checklist.md`](docs/mobile-ui-planning-checklist.md)

下一阶段先填写并核对策划，再由用户明确授权功能开发。仓库中的本地路径与历史诊断仅作为项目记录，迁移机器时需要重新核实。
