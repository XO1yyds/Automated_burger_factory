# Automated_burger_factory · 自动化汉堡店

基于 TapTap Maker / UrhoX Lua 的自动化汉堡工厂白盒 Demo。

聚光灯 GameJam 参赛项目。

当前有效版本为 V0.7，用户已在本次上传任务中明确确认按已验收版本处理。包含 V0.6 十天工厂经营、静态美术、四向四帧角色动画、UI 美术、背景音乐与音效。完成记录见 `docs/v07-release.md`，GitHub 快照范围见 `docs/github-v07-upload.md`。安卓真机仍待验证。

## 当前功能

- 垂直正交俯视镜头、角色移动与 Shift 双倍奔跑、单件手持和原料/地面物品交换。
- 手工煎肉与汉堡组装，自动三槽烹饪、自动汉堡组合设备。
- 建筑选择、放置、旋转、移动、拆除、连续建造及场景投影固定。
- 汉堡店与自动化车间切换，离开车间后生产继续。
- 实体传送带：0.5 格/秒、单输入单输出、FIFO、容量与回堵、禁止闭环及重叠。
- 十字拓展接口、直通隔离接口、转角隔离接口，缓存台六槽及后进先出输出。
- 建筑 A/B 选择、路径预览与调整、独立确认、连续布线。
- 订单、五份店内交付库存、收银交付、十天日循环、准备/营业/暂停、每日结算与日初重试。
- V0.3统一HUD、五类建造选型、场景对象卡、缓存先选后执行、统计、设置与阶段教学。
- 手机横屏输入：固定/浮动摇杆、外圈奔跑、共享动作按钮、双指平移/缩放及失焦释放输入。
- 传送带单段电脑/手机统一按住0.35秒后拖动，无四向按钮；端点/转角保留先选再拖及键盘编辑。
- 天花板传物电缆：常规隐藏、无碰撞，网格接线/分叉/删线，每网至多一个下单组件。
- 下单组件依附已有库存，与交付组件互斥；提供下单、本机库存、网络与任务四页签。成品固定进入本机库存，按实际入库事件计进度；网络改变保留任务，玩家可主动取消。
- 整网请求式电缆运输2件/秒，共用原车间烹饪与组合设备，不自动交顾客订单。
- 普通库存2×4/24件，空手后进先出取物、持物拒绝交互，允许网络和传送带输入；缓存台2×2/6件，保留原位选取、存取交换。
- 下单终端本机库存按品类任取；手满时取出物落地，地满拒绝。交付组件依附库存或缓存，收银台同步内容并按订单品类交付。
- 电缆编辑和管理中，已接线设备显示金框青色插头、未接线设备在编辑中显示灰框；普通游玩隐藏。
- V0.6逐日引导：手工→手搬自动设备→传送带→电缆网络→批量下单→交付连接→扩建优化；订单件数与上限随天数提升，可自愿接受效率加量单。
- 车间扩大为36×28，店内比例不变；金币、按件收入、购置费用、持有建筑回收与唯一供货点重放。
- 开始画面与本地经营存档；Maker原生文件沙箱、双槽校验与回退，保留加工、物流、库存、任务与入账进度，不计算离线收益。
- V0.4正式静态资源、四向四帧角色动画与统一UI美术已接入；手持、操作、待机思考、走路和奔跑由动作状态驱动。
- V0.7背景音乐与11类音效已接入，支持总音量、音乐、音效、静音、试听及默认值。
- Windows一键启动器附带预览存档保护：应对Maker 0.0.36每轮清理临时缓存，备份至本地`.local-saves/v06`后在新窗口加载前恢复；该目录不上传Git，安卓原生存储待真机验收。

## 目录

| 路径 | 内容 |
| --- | --- |
| `scripts/main.lua` | 游戏入口 |
| `scripts/Factory/` | 玩法模块及自检模块 |
| `assets/` | 当前项目资源与生成来源记录；部分美术为未接入提案 |
| `docs/` | 需求、设计、验证证据、验收流程及 V0.3 UI规范 |
| `launch-demo.ps1` | 当前 Windows 本机启动脚本 |
| `preview-save-bridge.ps1` | Windows临时预览存档保护，仅处理本项目两个有效经营槽 |
| `待回收/` | 本地隔离的旧工具/临时脚本/日志，含逐文件恢复清单，不上传GitHub |

## 运行说明

游戏需要 TapTap Maker / UrhoX 的运行环境和引擎资源。本仓库是项目源码快照，不是可独立双击运行的成品安装包。引擎文档、示例、`urhox-libs` 参考库、Maker 认证与本机 Runtime 不上传，需通过官方 Maker 本地开发流程配置。

在已具备对应环境的项目目录中，可使用官方本地预览：

```powershell
taptap-maker preview start --target-dir "项目绝对路径" --json
```

`launch-demo.ps1` 目前对应原开发机的 Node 路径和已安装 Maker 0.0.36；其他机器需先核对这些路径与版本。原开发机桌面快捷方式不属于独立游戏程序。

## 版本与验证边界

- V0.5用户验收完成；开发端依附组件领域32项、既有V0.5领域73项、实际UrhoX场景35项通过。接口修订后42个Lua文件语法通过、LSP 0 Error；细节和验证范围见 `docs/v05-attached-development-status.md`。上传操作仅核对源码、快照和远端提交，不重复宣称完整玩法验收。
- Windows 本地预览仍存在 `Cube/Day/DaySpecularHDR.dds` 缺失与 `themis_x64.dll` 加载错误；进程运行不代表工具完整就绪检查通过。
- 触屏控件与白模UI已实现；小米14 / Android15真机仍未测，也未生成Android安装包。正式UI美术与员工四帧动画已接入；未选用的设计图和旧动画试稿保留本地。店内两台初始自动设备已移除，手工台与车间自动机保留。
- V0.6用户已确认验收；开发端80项领域/存档、31项原生场景、5项预览存档保护检查通过，51个Lua解析与LSP零ERROR，Windows跨进程继续已验证。UI偏好独立保留，V0.5没有可迁移经营档。各轮验收表原记录保留，不把整体确认伪造为逐项测试数据或安卓真机通过。
- 本次 GitHub 备份不触发 Maker 提交、远端构建或发布。

## 开发入口

- V0.7验收版本：[`docs/v07-release.md`](docs/v07-release.md)
- V0.7音频接入证据：[`docs/v07-delivery.md`](docs/v07-delivery.md)
- V0.7 GitHub更新范围：[`docs/github-v07-upload.md`](docs/github-v07-upload.md)

- V0.6状态与证据：[`docs/v06-development-status.md`](docs/v06-development-status.md)
- V0.6完成记录：[`docs/v06-release.md`](docs/v06-release.md)
- V0.6 GitHub更新范围：[`docs/github-v06-upload.md`](docs/github-v06-upload.md)
- V0.6策划：[`docs/v06-development-plan.md`](docs/v06-development-plan.md)
- V0.6人工验收：[`docs/v06-manual-acceptance.md`](docs/v06-manual-acceptance.md)
- V0.5完成记录：[`docs/v05-release.md`](docs/v05-release.md)
- V0.5最终修订与验证：[`docs/v05-attached-development-status.md`](docs/v05-attached-development-status.md)
- V0.5策划规则：[`docs/v05-order-automation-development-plan.md`](docs/v05-order-automation-development-plan.md)
- V0.5最终验收流程：[`docs/v05-attached-manual-acceptance.md`](docs/v05-attached-manual-acceptance.md)
- 当前画面与功能：[`docs/current-game-ui-information.md`](docs/current-game-ui-information.md)
- 实体物流统一验收：[`docs/conveyor-acceptance.md`](docs/conveyor-acceptance.md)
- R4 编辑交互记录：[`docs/conveyor-editing-fixes.md`](docs/conveyor-editing-fixes.md)
- 下一阶段 UI 需求：[`docs/ui-next-stage-requirements-draft.md`](docs/ui-next-stage-requirements-draft.md)
- V0.3验收清单：[`docs/ui-v03-manual-acceptance.md`](docs/ui-v03-manual-acceptance.md)
- V0.3修复与验证：[`docs/ui-v03-review-fixes.md`](docs/ui-v03-review-fixes.md)
- 本地待回收清单：[`docs/v03-cleanup-manifest.md`](docs/v03-cleanup-manifest.md)
- 手机 UI 通用清单：[`docs/mobile-ui-planning-checklist.md`](docs/mobile-ui-planning-checklist.md)

下一阶段先填写并核对策划，再由用户明确授权功能开发。仓库中的本地路径与历史诊断仅作为项目记录，迁移机器时需要重新核实。
