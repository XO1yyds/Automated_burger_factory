# 自动化汉堡店 · Tap 积分台账

更新时间：2026-10-18。时间采用 Asia/Shanghai 时区。

第一版动作方案修订v5（2026-10-18）：

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | -- | -- | -- | -- |
| 2026-10-18 | maker_status_lite | 第一版方案修订前核对项目 | 否 | 平台未返回 | 未取得 | MAKER-FREE；绑定正常；0.0.36未升级 |
| 2026-10-18 | edit_image | 第一版可见动作幅度、无眼部动作正面待机8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；一次4097×2731生成；原图/请求/返回保留；8帧候选最终final统一头脸，未返回用量或余额 |
| 2026-10-18 | preview status | v5资源导出后状态核对 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload14 stopped/process_alive=false；未重启 |

肩部局部修订v4（2026-10-18）：

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | -- | -- | -- | -- |
| 2026-10-18 | maker_status_lite | 肩部修订前核对项目 | 否 | 平台未返回 | 未取得 | MAKER-FREE；绑定正常；沿用0.0.36，未升级 |
| 2026-10-18 | edit_image | 肩部微抬关键姿势v4 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；一次512×512编辑，原图仍含非肩部变化，仅作姿势参考；最终8帧按用户限定的肩部Y约束本地导出，不宣称8次AI生成 |
| 2026-10-18 | preview status | 肩部修订导出后核查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload14 stopped/process_alive=false，未重启 |

本轮新增（2026-10-18，V0.4角色动画样板）：

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | -- | -- | -- | -- |
| 2026-10-18 | maker_status_lite | 续作前核对项目绑定 | 否 | 平台未返回 | 未取得 | MAKER-FREE；绑定存在；0.0.36，未升级 |
| 2026-10-18 | edit_image | 员工正面待机4帧样板v1 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；仅一次；2048×1152原图及完整请求/结果保留；用户要求先修改，具体位置待补充；未扩量 |
| 2026-10-18 | preview status | 样板资源导出后会话检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload14 stopped/process_alive=false；未重启 |
| 2026-10-18 | edit_image | 正面待机v2：按用户修改8帧/不眨眼/降低幅度 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；原图4096×2731，发梢跨槽判为布局失败；保留请求/平台结果，不作为可用图集 |
| 2026-10-18 | edit_image | 正面待机v3：八槽布局修正 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；原图4097×2731；8帧/4fps，512/256候选已导出，最新目录front_idle_8f_v3_aligned；待审核；未返回扣费/余额 |
| 2026-10-18 | preview status | 8帧修订资源导出后检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload14 stopped/process_alive=false；未重启；证据docs/v04-character-animation-preview-status.json |

规则见 [双线开发与积分调度规则](tap-credit-policy.md)。本文件为积分记录的唯一维护入口。

## 余额与有效期

| 积分类型（使用优先级） | 当前余额 | 周期总额度 | 到期/重置时间 | 最近查询 | 证据 |
| --- | --- | --- | --- | --- | --- |
| 即将过期的活动积分 | 未取得 | 未取得 | 未取得 | 尚未查询 | 无 |
| 奖励积分 | 未取得 | 未取得 | 未取得 | 尚未查询 | 无 |
| 周期赠送积分 | 未取得 | 未取得 | 未取得 | 尚未查询 | 无 |
| 长期保留积分 | 未取得 | 未取得 | 未取得 | 尚未查询 | 无 |

具体积分只填写平台真实数据。“未取得”不代表余额为零。

## 操作与积分记录

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | ----- | ---- | ---- | -- |
| 2026-10-12 | Maker CLI 安装与初始化 | 创建并初始化“自动化汉堡店”，验证 MCP 和开发环境 | 否 | 平台未返回 | 未取得 | 从旧跟踪表迁移；按新版归类为 MAKER-FREE，未取得实际扣费数字 |
| 2026-10-14 | maker_status_lite | Phase 1 开始前状态查询 | 否 | 平台未返回 | 未取得 | MAKER-FREE；绑定项目、Git、Python、Lua LSP 就绪 |
| 2026-10-14 | CLI preview status | 初始预览检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；Runtime 缺失，会话停止 |
| 2026-10-14 | CLI preview install | 安装 Windows Runtime | 否 | 平台未返回 | 未取得 | MAKER-FREE；安装成功 |
| 2026-10-14 | CLI preview status | 首轮代码完成后检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；Runtime 就绪，会话停止 |
| 2026-10-14 | lua_lsp diagnostic | 首轮 Error 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview start | 打开 Windows 白盒预览 | 否 | 平台未返回 | 未取得 | MAKER-FREE；session 58a91ec3-4513-4c26-a541-42ea8b45785b，reload 0 |
| 2026-10-14 | lua_lsp diagnostic | 首轮 Warning 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；16 Warning，后续收敛 |
| 2026-10-14 | CLI preview status | 非提升权限会话查询 | 否 | 平台未返回 | 未取得 | MAKER-FREE；宿主身份未确认，无重复启动 |
| 2026-10-14 | CLI preview logs | 授权查询本轮日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；确认原会话存活 |
| 2026-10-14 | CLI preview logs --tail | 首轮游戏加载确认 | 否 | 平台未返回 | 未取得 | MAKER-FREE；READY，存在 Runtime 资源/DLL 错误 |
| 2026-10-14 | CLI preview status | 自检代码更新后检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；原会话存活 |
| 2026-10-14 | lua_lsp diagnostic | 自检代码 Error 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview refresh | 运行真实物理和交互自检 | 否 | 平台未返回 | 未取得 | MAKER-FREE；同一 session，reload 1 |
| 2026-10-14 | CLI preview logs --tail | 读取机制自检结果 | 否 | 平台未返回 | 未取得 | MAKER-FREE；7 PASS，failures=0 |
| 2026-10-14 | lua_lsp diagnostic | 自检版本 Warning 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error，4 Warning |
| 2026-10-14 | lua_lsp diagnostic | 最终版本 Error 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview status | 验收版本更新后检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；原会话存活 |
| 2026-10-14 | CLI preview refresh | 加载关闭自检的验收版本 | 否 | 平台未返回 | 未取得 | MAKER-FREE；同一 session，reload 2 |
| 2026-10-14 | CLI preview logs --tail | 最终版本加载确认 | 否 | 平台未返回 | 未取得 | MAKER-FREE；READY，无已观察到的游戏 Lua 异常 |
| 2026-10-14 | CLI preview check | 最终预览证据检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；FAIL，Runtime 资源/DLL 错误，未验证画面 |
| 2026-10-14 | lua_lsp diagnostic | 最终完整诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error，1 Warning，1 Hint |
| 2026-10-14 | lua_lsp diagnostic | 图 1/图 2 初版代码 Error 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview status | 新镜头/地图首批修改后状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；会话已停止，未自动启动 |
| 2026-10-14 | lua_lsp diagnostic | 新版 Warning 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；自检数组索引的 nil 提示，后续补充断言 |
| 2026-10-14 | lua_lsp diagnostic | 新版自检代码 Error 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error、0 Warning |
| 2026-10-14 | CLI preview status | 第二批布局修改后状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；会话仍停止，等待重新打开授权 |
| 2026-10-14 | CLI preview start | 用户同意后重新打开纯俯视版本 | 否 | 平台未返回 | 未取得 | MAKER-FREE；session 5db4f9c8-3f4b-464e-b2e7-6fc23726e4af，reload 0 |
| 2026-10-14 | CLI preview logs --tail | 新版镜头、布局与机制自检日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；10 PASS，failures=0，游戏 READY |
| 2026-10-14 | lua_lsp diagnostic | 普通操作版本 Error 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error，1 Warning（关闭自检后的恒假条件） |
| 2026-10-14 | CLI preview status | 关闭自检后的会话检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；当前会话存活 |
| 2026-10-14 | CLI preview refresh | 切换普通操作版本 | 否 | 平台未返回 | 未取得 | MAKER-FREE；同一 session，reload 1，恢复玩家出生点 |
| 2026-10-14 | CLI preview logs --tail | 纯俯视普通操作版本最终日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 1，READY，旧资源/DLL 错误仍存在 |
| 2026-10-14 | CLI preview check | 新布局证据检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；FAIL，Runtime 日志错误，画面和中键/滚轮手感待人工验收 |
| 2026-10-14 | maker_status_lite | Phase 2 开发前状态查询 | 否 | 平台未返回 | 未取得 | MAKER-FREE；项目绑定及 Lua/Python 就绪 |
| 2026-10-14 | CLI preview status | Phase 2 开发前会话检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；会话存活，reload 1 |
| 2026-10-14 | lua_lsp diagnostic | Phase 2 初版 Error 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；发现颜色数组可空类型错误，运行前修正 |
| 2026-10-14 | CLI preview status | 首批物品代码修改后状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；会话存活，尚未加载存在静态错误的版本 |
| 2026-10-14 | lua_lsp diagnostic | 颜色参数修正后 Error 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | lua_lsp diagnostic | 物品适配 Warning 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；提示冗余断言与开发分支，后续整理 |
| 2026-10-14 | lua_lsp diagnostic | Items 模块单文件检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；无返回的 Error |
| 2026-10-14 | lua_lsp diagnostic | ItemChecks 模块单文件检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；无返回的 Error |
| 2026-10-14 | CLI preview status | 第一次物品自检前会话检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活 |
| 2026-10-14 | CLI preview refresh | 加载 Phase 2 物品自检版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；同一 session，reload 2 |
| 2026-10-14 | CLI preview logs --tail | 首次 Phase 2 自检日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；物品 22 PASS，Phase 1 回归 10 PASS |
| 2026-10-14 | lua_lsp diagnostic | 方块拐角占位防护 Error 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview status | 占位防护代码修改后状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 2 |
| 2026-10-14 | CLI preview refresh | 加载补充拐角检查的版本 | 否 | 平台未返回 | 未取得 | MAKER-FREE；同一 session，reload 3 |
| 2026-10-14 | CLI preview logs --tail | 完整 Phase 2 自检结果 | 否 | 平台未返回 | 未取得 | MAKER-FREE；物品 24 PASS、Phase 1 回归 10 PASS，failures=0 |
| 2026-10-14 | lua_lsp diagnostic | Phase 2 普通操作版本 Error 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error，4 Warning，1 Hint |
| 2026-10-14 | CLI preview status | 关闭自检后的会话检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 3 |
| 2026-10-14 | CLI preview refresh | 交付 Phase 2 普通操作版本 | 否 | 平台未返回 | 未取得 | MAKER-FREE；同一 session，reload 4，保留五份初始验收样品 |
| 2026-10-14 | CLI preview logs --tail | Phase 2 普通操作版本最终日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 4，Phase 2 READY；原 Runtime 资源/DLL 错误仍存在 |
| 2026-10-14 | CLI preview check | Phase 2 最终预览工具检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；FAIL，原因是 Runtime 日志错误，物品自检与视觉验收分别记录 |
| 2026-10-14 | lua_lsp diagnostic | Phase 2 最终完整诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error，4 Warning，1 Hint，均为开发开关/可选状态静态提示 |
| 2026-10-14 | CLI preview status | 修复前会话检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 4 |
| 2026-10-14 | lua_lsp diagnostic | 标签与地面互换代码检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | lua_lsp diagnostic | 上侧居中 UI 检查代码诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview status | 标签与地面互换代码修改后状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 4 |
| 2026-10-14 | CLI preview refresh | 加载标签与地面互换自检版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 5 |
| 2026-10-14 | CLI preview logs --tail | 标签与地面互换自检日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；地面互换、UI 布局检查通过 |
| 2026-10-14 | lua_lsp diagnostic | 原料点互换代码检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview status | 原料点互换修改后状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 5 |
| 2026-10-14 | CLI preview refresh | 加载原料点互换自检版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 6 |
| 2026-10-14 | CLI preview logs --tail | 完整标签与互换自检结果 | 否 | 平台未返回 | 未取得 | MAKER-FREE；29 项物品、10 项回归、2 项 UI 布局，41 PASS、0 失败 |
| 2026-10-14 | lua_lsp diagnostic | 关闭自动测试后的最终诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error、3 Warning、10 Hint |
| 2026-10-14 | CLI preview status | 关闭自检后的会话检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 6 |
| 2026-10-14 | CLI preview refresh | 标签与互换普通版本 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 7，自动检查关闭 |
| 2026-10-14 | CLI preview logs --tail | 普通版本加载日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 7 READY，原 Runtime 资源/DLL 错误仍存在 |
| 2026-10-14 | CLI preview check | 普通版本就绪检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；FAIL，Runtime reported a failure |
| 2026-10-14 | CLI preview logs --tail | 普通版本交互日志留证 | 否 | 平台未返回 | 未取得 | MAKER-FREE；记录地面互换、原料点换取、无空位保护，视觉待验收 |
| 2026-10-14 | maker_status_lite | Phase 3 开始前项目状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；已绑定；仅本地开发，缺项目配置由本地预览准备处理 |
| 2026-10-14 | CLI preview status | Phase 3 初始预览状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 7 |
| 2026-10-14 | lua_lsp diagnostic | 手工生产模块首次诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview status | 手工生产批次编辑后状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 7 |
| 2026-10-14 | CLI preview refresh | 加载手工生产边界检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 8 |
| 2026-10-14 | CLI preview logs --tail | 首轮手工生产检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；37 项 Phase 3 与 39 项 Phase 1/2，76 PASS |
| 2026-10-14 | lua_lsp diagnostic | 场景链路驱动诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview status | 场景链路批次编辑后状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 8 |
| 2026-10-14 | CLI preview refresh | 加载场景链路检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 9 |
| 2026-10-14 | CLI preview logs --tail | 场景链路首轮证据 | 否 | 平台未返回 | 未取得 | MAKER-FREE；路线 10 FAIL、UI 居中 1 FAIL；测试瞬移/布局时序待修正，未记通过 |
| 2026-10-14 | lua_lsp diagnostic | 测试驱动同步与布局等待修正 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview status | 测试驱动修正后状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 9 |
| 2026-10-14 | CLI preview refresh | 加载修正后的场景链路检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 10 |
| 2026-10-14 | CLI preview logs --tail | Phase 3 完整运行证据 | 否 | 平台未返回 | 未取得 | MAKER-FREE；89 PASS、0 失败；包含路线与居中 UI 检查 |
| 2026-10-14 | lua_lsp diagnostic | 关闭三项自动检查后的最终诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error、4 Warning、13 Hint |
| 2026-10-14 | CLI preview status | 关闭开发检查后的状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 10 |
| 2026-10-14 | CLI preview refresh | Phase 3 普通操作版本 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 11，自动自检关闭 |
| 2026-10-14 | CLI preview logs --tail | Phase 3 普通版本最终日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 11，Phase 3 READY，三项开发检查关闭 |
| 2026-10-14 | CLI preview check | Phase 3 普通版本就绪检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；FAIL，原 Runtime 资源/DLL 错误，业务通过和视觉待验收分别记录 |
| 2026-10-14 | maker_status_lite | 建筑标签修复前状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；已绑定，继续本地开发 |
| 2026-10-14 | CLI preview status | 建筑标签修复初始会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 11 |
| 2026-10-14 | lua_lsp diagnostic | 近距标签和位置检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview status | 标签编辑批次后状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 11 |
| 2026-10-14 | CLI preview refresh | 近距建筑标签自检版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 12 |
| 2026-10-14 | CLI preview logs --tail | 首轮标签检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；显示/隐藏通过；3 项位置 FAIL |
| 2026-10-14 | CLI preview status | 补充坐标诊断后状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 12 |
| 2026-10-14 | CLI preview refresh | 标签坐标诊断版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 13 |
| 2026-10-14 | CLI preview logs --tail | 诊断版加载状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；当时尚无自检日志 |
| 2026-10-14 | CLI preview logs --tail --limit 500 | 完整标签坐标诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；3 项位置 FAIL；记录实际射线坐标，不记作通过 |
| 2026-10-14 | lua_lsp diagnostic | 屏幕射线校准尝试 | 否 | 平台未返回 | 未取得 | MAKER-FREE；4 Error；Vector3 类型源未标注，已修正后复查 |
| 2026-10-14 | CLI preview status | 射线校准尝试状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 13 |
| 2026-10-14 | lua_lsp diagnostic | 补充 Vector3 类型来源后诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview refresh | 射线校准验证版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 14 |
| 2026-10-14 | CLI preview logs --tail | 射线校准验证 | 否 | 平台未返回 | 未取得 | MAKER-FREE；3 项位置 FAIL；仍受自动宽高比更新时序影响 |
| 2026-10-14 | lua_lsp diagnostic | 显式窗口宽高比修复诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview status | 宽高比修复后状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 14 |
| 2026-10-14 | CLI preview refresh | 显式宽高比标签验证版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 15 |
| 2026-10-14 | CLI preview logs --tail | 宽高比验证版加载状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；当时尚无自检日志 |
| 2026-10-14 | CLI preview logs --tail --limit 500 | 建筑标签最终几何验证 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 15，6 PASS、0 失败，含居中及 5px 间距 |
| 2026-10-14 | lua_lsp diagnostic | 关闭标签检查后的最终诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error、5 Warning、13 Hint |
| 2026-10-14 | CLI preview status | 关闭标签检查后的会话状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 15 |
| 2026-10-14 | CLI preview refresh | 建筑近距名称普通版本 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 16，四项开发检查关闭 |
| 2026-10-14 | CLI preview logs --tail | 建筑标签普通版最终日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 16，Phase 3 READY |
| 2026-10-14 | CLI preview check | 建筑标签普通版就绪检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；FAIL，原 Runtime 资源/DLL 错误仍存在，几何验证与视觉待验收分开记录 |
| 2026-10-14 | lua_lsp diagnostic | 恢复场景比例后的 Lua 检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview status | 恢复场景比例后的会话检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 16 |
| 2026-10-14 | CLI preview refresh | 恢复修改前场景比例 | 否 | 平台未返回 | 未取得 | MAKER-FREE；刷新原存活会话为 reload 17 |
| 2026-10-14 | CLI preview logs --tail | 恢复比例版本加载日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 17，Phase 3 READY |
| 2026-10-14 | CLI preview check | 恢复比例版本就绪检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；FAIL，原 Runtime 资源/DLL 错误仍存在 |
| 2026-10-14 | maker_status_lite | Phase 4–7 初始状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；状态已获取，按当前绑定项目开发 |
| 2026-10-14 | CLI preview status | Phase 4–7 初始本地会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 17 |
| 2026-10-14 | lua_lsp diagnostic | 自动设备模块检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | lua_lsp diagnostic | 自动场景链路检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview status | 自动设备验证前状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；原会话存活 |
| 2026-10-14 | CLI preview refresh | 自动设备验证版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 18 |
| 2026-10-14 | CLI preview logs | 自动设备与回归验证 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 18，141 PASS |
| 2026-10-14 | lua_lsp diagnostic | 世界昵称与建筑订单整合 | 否 | 平台未返回 | 未取得 | MAKER-FREE；1 Error |
| 2026-10-14 | lua_lsp diagnostic | 整合类型注释修正 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview status | 世界昵称验证前状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；原会话存活 |
| 2026-10-14 | CLI preview refresh | 世界昵称场景验证版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 19 |
| 2026-10-14 | CLI preview logs | Text3D 场景回归 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 19，141 PASS |
| 2026-10-14 | lua_lsp diagnostic | 新增 StageChecks | 否 | 平台未返回 | 未取得 | MAKER-FREE；3 Error |
| 2026-10-14 | lua_lsp diagnostic | 回调与上下文修正 | 否 | 平台未返回 | 未取得 | MAKER-FREE；1 Error |
| 2026-10-14 | CLI preview status | 建筑收银验证前状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；原会话存活 |
| 2026-10-14 | CLI preview refresh | 建筑收银整体验证版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 20 |
| 2026-10-14 | lua_lsp diagnostic | 上下文类型检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；仍1 Error；后续已修正 |
| 2026-10-14 | CLI preview logs | 建筑与收银回归 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 20，195 PASS |
| 2026-10-14 | lua_lsp diagnostic | 悬停回调参数检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；1 Error |
| 2026-10-14 | lua_lsp diagnostic | 悬停事件参数修正 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | CLI preview status | 最终统一验证前状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；原会话存活 |
| 2026-10-14 | CLI preview refresh | 最终统一验证版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 21 |
| 2026-10-14 | CLI preview logs | 统一 Runtime 验证 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 21，197 PASS、0失败，证据见phase4-7-evidence.json |
| 2026-10-14 | lua_lsp diagnostic | 关闭自检后的最终代码 | 否 | 平台未返回 | 未取得 | MAKER-FREE；8文件，0 Error、45 Warning、25 Hint |
| 2026-10-14 | CLI preview status | 普通版本刷新前状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 21 |
| 2026-10-14 | lua_lsp diagnostic | 警告详情读取 | 否 | 平台未返回 | 未取得 | MAKER-FREE；自动审批额度耗尽，未执行；返回拒绝文本而非诊断JSON |
| 2026-10-14 | CLI preview refresh | 普通版本首次刷新尝试 | 否 | 平台未返回 | 未取得 | MAKER-FREE；自动审批额度耗尽，未执行；不代表判定不安全 |
| 2026-10-14 | CLI preview status | 用户继续授权后的会话检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload 21 |
| 2026-10-14 | CLI preview refresh | 继续授权后正常版本刷新 | 否 | 平台未返回 | 未取得 | MAKER-FREE；2026-10-14 15:04，reload 22成功；自检关闭 |
| 2026-10-14 | CLI preview logs --tail --limit 500 | 正常版加载日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 22；首次工具输出截断，未作为完整JSON解析 |
| 2026-10-14 | CLI preview check | 正常版就绪检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 22，FAIL/退出码1；原资源/DLL错误仍存在 |
| 2026-10-14 | CLI preview logs --tail --limit 110 | 正常版完整末尾证据 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload 22，脚本READY、Game started successfully；无QA执行记录 |
| 2026-10-14 | maker_status_lite | 阶段8继续开发前状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；绑定项目，继续本地开发，不触发远端构建 |
| 2026-10-14 | lua_lsp diagnostic | 阶段8初次整合 | 否 | 平台未返回 | 未取得 | MAKER-FREE；6 Error；随后修正上下文类与回调类型 |
| 2026-10-14 | CLI preview status | 阶段8整合后会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload22 |
| 2026-10-14 | lua_lsp diagnostic | 整合类型修正 | 否 | 平台未返回 | 未取得 | MAKER-FREE；1 Error，动态键盘菜单索引待修正 |
| 2026-10-14 | CLI preview refresh | 阶段8初版普通预览 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload23；未声称完整验收 |
| 2026-10-14 | lua_lsp diagnostic | 统一检查开关与菜单索引修正 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error/72 Warning/45 Hint |
| 2026-10-14 | CLI preview status | 首轮统一测试前会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload23 |
| 2026-10-14 | CLI preview refresh | 阶段4–8首轮测试版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload24 |
| 2026-10-14 | CLI preview logs --limit 600 | 首轮日志获取 | 否 | 平台未返回 | 未取得 | MAKER-FREE；参数错误：limit须1–500；未取得日志；未报告为服务故障 |
| 2026-10-14 | CLI preview logs --limit 500 | 首轮统一回归 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload24，241 PASS/1失败；测试错误地以autoExit判断ESC |
| 2026-10-14 | CLI preview status | 退出开关定位前会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload24 |
| 2026-10-14 | CLI preview refresh | 分拆重启输入检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload25 |
| 2026-10-14 | CLI preview logs --limit 500 | 退出开关定位日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload25，242 PASS/1失败；GetAutoExit返回true |
| 2026-10-14 | lua_lsp diagnostic severity2 | 警告详情读取 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error，72 Warning；取第一页50项，尚余22项；不声称全部警告消除 |
| 2026-10-14 | lua_lsp diagnostic | 实际ESC路由整合 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error/71 Warning/45 Hint |
| 2026-10-14 | CLI preview status | ESC路由回归前会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload25 |
| 2026-10-14 | CLI preview refresh | 实际ESC优先级测试版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload26；本轮未单独获取日志，不记录通过数 |
| 2026-10-14 | lua_lsp diagnostic | 恢复首帧与同帧归零修复 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error/72 Warning/46 Hint |
| 2026-10-14 | CLI preview status | 跨日进度检查前会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload26 |
| 2026-10-14 | CLI preview refresh | 跨日进度与真实Update入口测试 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload27 |
| 2026-10-14 | CLI preview logs --limit 500 | 跨日与移动回归结果 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload27，247 PASS/2失败；跨日夹具提前清地面，移动检查未用物理步时间 |
| 2026-10-14 | lua_lsp diagnostic | 夹具与PhysicsPostStep校准 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error/72 Warning/47 Hint |
| 2026-10-14 | CLI preview status | 最终统一回归前会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload27 |
| 2026-10-14 | CLI preview refresh | 最终阶段1–8统一验证版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload28 |
| 2026-10-14 | CLI preview logs --limit 500 | 最终统一验证结果 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload28，249 PASS/0失败；阶段8为52项 |
| 2026-10-14 | lua_lsp diagnostic | 关闭七项自检后的最终代码 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error/78 Warning/47 Hint，9个诊断文件 |
| 2026-10-14 | CLI preview status | 最终普通版本刷新前会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload28 |
| 2026-10-14 | CLI preview refresh | 完整Demo普通游戏版本 | 否 | 平台未返回 | 未取得 | MAKER-FREE；2026-10-14 15:32，reload29；自检关闭；刷新清内存状态 |
| 2026-10-14 | CLI preview logs --limit 110 | 最终普通版本日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload29，Phase8 READY、Game started successfully；所取尾部无QA执行日志 |
| 2026-10-14 | CLI preview check | 最终普通版本就绪检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload29，FAIL；已有Cube/Day/DaySpecularHDR.dds及themis_x64.dll错误 |
| 2026-10-14 | maker_status_lite | 验收后修改前项目状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；绑定项目，本地开发；不远端构建 |
| 2026-10-14 | lua_lsp diagnostic | 九项修改与新检查首次诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；3 Error：可空文本及诊断i18n全局；已修正 |
| 2026-10-14 | CLI preview status | 代码批次后的真实会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；已停止，未自动复活；发起重新打开授权 |
| 2026-10-14 | lua_lsp diagnostic | 类型修正后诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error/80 Warning/51 Hint |
| 2026-10-14 | CLI preview start | 用户明确重新打开并自检 | 否 | 平台未返回 | 未取得 | MAKER-FREE；新会话8e1add4e-98f5-4d72-8bfd-92cab01455ce，reload0 |
| 2026-10-14 | CLI preview logs --tail --limit 500 | 首轮回归及HUD诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；尾部仅含255 PASS，无失败；完整数量须分页补齐 |
| 2026-10-14 | CLI preview logs --cursor 0 --limit 500 | 首轮早期日志补齐 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload0，获取早期烟雾检查及initial采样 |
| 2026-10-14 | CLI preview logs --cursor 500 --limit 500 | 首轮中间日志补齐 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload0，合并完整275 PASS/0失败 |
| 2026-10-14 | lua_lsp diagnostic | 增加只读宽度/高度诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error/72 Warning/51 Hint |
| 2026-10-14 | CLI preview status | 增强HUD诊断前状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，新会话reload0 |
| 2026-10-14 | CLI preview refresh | HUD增强诊断与完整回归 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload1；未修复行高或gap |
| 2026-10-14 | CLI preview logs --cursor 0 --limit 500 | 最终回归第一页 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload1 |
| 2026-10-14 | CLI preview logs --cursor 500 --limit 500 | 最终回归第二页 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload1 |
| 2026-10-14 | CLI preview logs --cursor 1000 --limit 500 | 最终回归与重开诊断尾页 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload1；合并275 PASS/0失败；gap4、标题高度34→70→34 |
| 2026-10-14 | lua_lsp diagnostic | 关闭八项开发开关后的最终代码 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error/81 Warning/51 Hint |
| 2026-10-14 | CLI preview status | 普通版本刷新前会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；存活，reload1 |
| 2026-10-14 | CLI preview refresh | 第一轮修改普通游戏版本 | 否 | 平台未返回 | 未取得 | MAKER-FREE；2026-10-14 18:35，reload2，自检/诊断关闭 |
| 2026-10-14 | CLI preview logs --tail --limit 110 | 普通版本加载证据 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload2，Game started successfully，所取尾部无QA/诊断执行记录 |
| 2026-10-14 | CLI preview check | 第一轮修改普通版就绪 | 否 | 平台未返回 | 未取得 | MAKER-FREE；FAIL；原Cube/Day/DaySpecularHDR.dds和themis_x64.dll错误保留 |

尚无生成式 Maker 调用记录。Phase 1～8、世界昵称及互换修复采用本地 Lua 实现，仅调用免费状态、预览和诊断能力；未查询积分余额，未生成付费素材。日期级条目根据工具记录补录，不编造各次精确时刻；未取得真实金额时不推定零消耗或余额。此前审批未执行的条目不推定扣费。

记录约定：每次 Maker 操作及余额查询新增一行；失败也记录；异步任务完成后更新同一行。备注保留实际积分来源、到期信息、请求/任务 ID 和证据（如平台提供）。没有真实数字时不填估算或假定的零值。

## 积分模式记录

| 时间 | 模式 | 依据 | 待核实事项 |
| --- | --- | --- | --- |
| 2026-10-12 | 平衡模式（暂行） | 尚未取得真实余额与有效期；暂限制为明确进入正式版本的素材生成 | 余额、额度、到期时间及平台实际扣费顺序 |

取得真实数据后，按照规则选择积分充足、平衡或节流模式并新增模式记录。接近周期/活动积分耗尽时主动提醒；当前数据不足，无法判定是否接近耗尽。

## 2026-10-14 宣传准备补录

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | -- | -- | -- | -- |
| 2026-10-14 | preview status | 探索前检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；旧会话停止 |
| 2026-10-14 | Lua LSP | 临时截图探针 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error |
| 2026-10-14 | preview start | 用户授权重开 | 否 | 平台未返回 | 未取得 | MAKER-FREE；会话b864eb51-74c1-4930-bb45-10816136f48d |
| 2026-10-14 | preview logs limit110 | 加载过程 | 否 | 平台未返回 | 未取得 | MAKER-FREE |
| 2026-10-14 | preview logs limit150 | 截图探针证据 | 否 | 平台未返回 | 未取得 | MAKER-FREE；采集成功，写出失败 |
| 2026-10-14 | preview status | 探索会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload0存活 |
| 2026-10-14 | preview refresh | 导出路径探针 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload1 |
| 2026-10-14 | preview logs limit70 | reload1加载过程 | 否 | 平台未返回 | 未取得 | MAKER-FREE |
| 2026-10-14 | preview logs limit70 | reload1截图证据 | 否 | 平台未返回 | 未取得 | MAKER-FREE；采集成功，写出失败 |
| 2026-10-14 | preview status | 用户转为自行录制 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload1存活 |
| 2026-10-14 | Lua LSP | 恢复普通main入口 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error/81 Warning/51 Hint |
| 2026-10-14 | preview status | 恢复入口后状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload1存活 |
| 2026-10-14 | preview refresh | 恢复入口刷新尝试 | 否 | 未执行 | 未取得 | 自动审批拒绝：重启丢失状态，超出自行录制后的请求范围；未绕过 |

## 2026-10-15 建筑页面UI设计

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | -- | -- | -- | -- |
| 2026-10-15 | maker_status_lite | 当前绑定项目就绪核对 | 否 | 平台未返回 | 未取得 | MAKER-FREE；绑定与认证存在，未触发远端构建 |
| 2026-10-15 | generate_image | 建筑工坊UI设计V1 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；用户明确要求；成功1920×1080；远端图片ID 8c58b0d3-f4e5-4107-93ff-925c7d0d0491；自动下载失败后浏览器保存原图成功，未重复生成；积分来源/到期信息未返回 |

## 2026-10-15 厂商绑定只读诊断

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | -- | -- | -- | -- |
| 2026-10-15 | maker_status_lite detail | 核对绑定与发布配置就绪 | 否 | 平台未返回 | 未取得 | MAKER-FREE；开发项目绑定有效，发布主配置缺失，代理工具正常 |
| 2026-10-15 | CLI --help | 查找官方身份/绑定操作入口 | 否 | 平台未返回 | 未取得 | MAKER-FREE；只读帮助，未创建绑定 |
| 2026-10-15 | CLI console status | 核对本地控制台 | 否 | 平台未返回 | 未取得 | MAKER-FREE；running=false；用户后确认错误来自网页 |
| 2026-10-15 | CLI apps --all --json | 核对远端项目记录 | 否 | 平台未返回 | 未取得 | MAKER-FREE；首次受限调用fetch failed |
| 2026-10-15 | CLI apps --all --json | 同一只读查询获网络权限后复核 | 否 | 平台未返回 | 未取得 | MAKER-FREE；项目owner且canPublish=true；不能推断厂商权限或发布身份 |

## 2026-10-15 登录后GameJam绑定复测

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | -- | -- | -- | -- |
| 2026-10-15 22:41 | 网页官方绑定GameJam | 复测2026聚光灯21天游戏创作挑战绑定 | 否 | 平台未返回 | 未取得 | MAKER-FREE；仅点击一次；回到相同错误；PublishState报项目配置暂不可读；未显示绑定成功 |
| 2026-10-15 | 网页积分显示读取 | 当前账户余额快照 | 否 | 平台未返回 | 40152 | 页面可用积分；历史回复标明通用积分；有效期及分池余额未返回，不能归为活动奖励积分 |
| 2026-10-15 | Lua LSP | 首次提交构建前的只读源码核对 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error/81 Warning/51 Hint；未执行构建 |

网页可验证的历史外部任务：10-15 22:37的Maker网页Agent回复显示“消耗794积分，剩余40152通用积分”。这是用户此前网页会话的消耗，非本轮Codex排查扣费，不与本轮操作重复计数。本轮未调用生成式能力。余额未提供积分到期信息，暂沿用平衡模式，不推断即将耗尽。
| 2026-10-15 | maker_status_lite | 用户咨询本地Demo上传方式 | 否 | 平台未返回 | 未取得 | MAKER-FREE；绑定有效，发布主配置仍缺失；仅说明上传流程，未提交构建 |

## 2026-10-15 首次提交与远端构建

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | -- | -- | -- | -- |
| 2026-10-15 | maker_status_lite detail | 原项目提交前状态与远端同步 | 否 | 平台未返回 | 未取得 | MAKER-FREE；behind1，本地改动存在 |
| 2026-10-15 | Lua LSP | 上传前源码诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error/81 Warning/51 Hint |
| 2026-10-15 | maker_build_current_directory | 原目录首次提交构建尝试 | 否 | 平台未返回 | 未取得 | MAKER-FREE；commit/push前被.gitignore覆盖检查阻止；remote_build not_started |
| 2026-10-15 | CLI init --app-id | 同一项目临时提交检出 | 否 | 平台未返回 | 未取得 | MAKER-FREE；首轮fetch失败，未新建游戏项目 |
| 2026-10-15 | CLI init --app-id | HTTP/1.1兼容设置后重试检出 | 否 | 平台未返回 | 未取得 | MAKER-FREE；clone完成；技能安装非阻塞警告保留 |
| 2026-10-15 | maker_status_lite | 临时检出绑定核对 | 否 | 平台未返回 | 未取得 | MAKER-FREE；绑定同一985f14a8项目 |
| 2026-10-15 | maker_build_current_directory | 上传已验收Demo并远端构建 | 否 | 平台未返回 | 未取得 | MAKER-FREE；main提交5982c19并push成功；远端构建成功；preview_refresh200；未调用生成能力 |
| 2026-10-15 | maker_status_lite | 成功构建后配置核对 | 否 | 平台未返回 | 未取得 | MAKER-FREE；本地project.json仍缺失，未重复构建 |

## 2026-10-16 汉堡店员工立绘

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | -- | -- | -- | -- |
| 2026-10-16 | maker_status_lite | 当前项目生成前核对 | 否 | 平台未返回 | 未取得 | MAKER-FREE；绑定和凭证存在；版本策略查询暂不可用，按返回建议继续正常工作 |
| 2026-10-16 | generate_image | 2D手绘Q版汉堡店员工全身立绘V1 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；用户指定Tap制造及详细风格；图片ID c2325b22-93b8-44b8-aba8-e746fb4055ec；自动下载成功；真实透明RGBA，实际1536×2304；积分来源/有效期未返回，未推断使用活动积分 |

## 2026-10-16 员工形象V2参考图修改

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | -- | -- | -- | -- |
| 2026-10-16 | maker_status_lite | V2图片编辑前绑定检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；绑定与凭证存在；版本策略检查暂不可用，按返回建议正常工作 |
| 2026-10-16 | edit_image | 4张参考图指导修改汉堡店员工V2 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；已检查V1及4图；ID 63df608d-db4d-44f1-904a-d5b833ad592f；自动下载成功，1536×2304真实透明PNG；未重复生成或推算扣费来源 |

## 2026-10-16 员工形象V3制服与颜色修改

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | -- | -- | -- | -- |
| 2026-10-16 | maker_status_lite | V3编辑前绑定核对 | 否 | 平台未返回 | 未取得 | MAKER-FREE；绑定与凭证存在，版本策略暂不可用，按返回建议继续正常工作 |
| 2026-10-16 | edit_image | 员工黑发黑瞳深灰帽及黑黄制服V3 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；V2及用户制服照片已查看；ID 87b7464a-abb6-44cb-b134-b757675d9167；1536×2304透明PNG已自动保存；未推算扣费或余额 |

## 2026-10-16 无道具员工三视图

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | -- | -- | -- | -- |
| 2026-10-16 | maker_status_lite | 三视图编辑前项目核对 | 否 | 平台未返回 | 未取得 | MAKER-FREE；绑定和凭证存在，按返回建议继续正常工作 |
| 2026-10-16 | edit_image | 去除手持道具并生成正侧背三视图 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；图片ID 2c870d29-2a49-45ea-bf2e-3309ea99e171；自动下载成功；3072×2048，真实透明；完整提示词与来源保留 |

## 2026-10-16 员工四种正面面部特写

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | -- | -- | -- | -- |
| 2026-10-16 | maker_status_lite | 表情编辑前项目检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；项目绑定和凭证存在，按返回建议继续正常工作 |
| 2026-10-16 | edit_image | 平静/沮丧/开心/生气正面四格特写 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；ID 952f3c8a-7ce5-4a3e-ba11-e6d8a26d6ea4；2048×2048真实透明PNG，自动保存成功，已视觉核验 |

## 2026-10-16～17 任务004：Windows本地Demo启动

官方0.0.36 CLI，原源码目录target-dir；非生成式，不推算积分或余额。

| 时间 | 功能 | 任务 | 是否生成式 | 消耗积分 | 剩余积分 | 备注 |
| -- | -- | -- | -- | -- | -- | -- |
| 2026-10-16 | preview status | 核对旧本地会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；process_alive=false，旧会话安全退役；退出码1 |
| 2026-10-16 | preview start | 按用户本轮授权打开Demo | 否 | 平台未返回 | 未取得 | MAKER-FREE；session b403a67b-20e3-4b7c-833f-6e6cec77658b，reload0，running/process_alive=true；托管副本准备成功；CLI正常结束 |
| 2026-10-17 | preview logs limit100 | 当前会话第一段启动日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；session/reload已指定；窗口模式及引擎初始化；next_cursor100 |
| 2026-10-17 | preview check | 当前会话就绪与证据检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；process_alive=true、ready=false、FAIL；原DDS/themis DLL错误仍在，未修复 |
| 2026-10-17 | preview logs cursor100 limit200 | 继续读取加载证据 | 否 | 平台未返回 | 未取得 | MAKER-FREE；确认main.lua/Factory/Phase1.lua加载；next_cursor300；无新启动或刷新 |
| 2026-10-17 | preview logs cursor300 limit200 | 确认入口执行及初始化 | 否 | 平台未返回 | 未取得 | MAKER-FREE；Executed main.lua、Phase1/2/3/4/7/8 READY；next_cursor466、truncated=false；process_alive=true；保留窗口，不代替玩法验收 |
| 2026-10-18 | maker_status_lite | V0.2恢复开发前核对 | 否 | 平台未返回 | 未取得 | MAKER-FREE；已绑定；本地project.json缺失；可升级0.0.37但未升级；未构建 |
| 2026-10-18 | Lua LSP | 物流分批实现及收尾静态诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；多次诊断均0 Error，最终99 Warning/59 Hint；非生成式 |
| 2026-10-18 | preview status ×2 | 修改前/测试前核对停止会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；旧会话停止；用户明确授权重新打开并自检 |
| 2026-10-18 | preview start（失败） | 首次测试启动 | 否 | 平台未返回 | 未取得 | MAKER-FREE；沙箱EPERM无法写用户目录launch.lock.recovery，未改权限或配置 |
| 2026-10-18 | preview start | 授权后正常权限路径启动测试 | 否 | 平台未返回 | 未取得 | MAKER-FREE；eb938a95-d57d-4981-9cc7-980a1030c4ad/reload0；真实窗口运行；原DDS/DLL报错保留 |
| 2026-10-18 | preview logs cursor0 | 读取初次QA前500条 | 否 | 平台未返回 | 未取得 | MAKER-FREE；原始日志docs/v02-qa-logs-0.json |
| 2026-10-18 | preview logs cursor500（参数失败） | 增量日志身份校验 | 否 | 平台未返回 | 未取得 | MAKER-FREE；缺session-id/reload-id被拒绝；随后使用同一会话完整身份重试，未改项目 |
| 2026-10-18 | preview logs cursor500/1000 | 读取初次QA后续日志 | 否 | 平台未返回 | 未取得 | MAKER-FREE；日志可读，但受限上下文无法访问supervisor；不据此判进程停止；后续正常访问确认运行 |
| 2026-10-18 | preview status ×2 | 核对读取上下文与真实进程状态 | 否 | 平台未返回 | 未取得 | MAKER-FREE；受限访问显示ownership未验证；正常访问process_alive=true；未杀进程或修改配置 |
| 2026-10-18 | preview status / refresh | 修正浮点测试断言后刷新活跃会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload1，复跑349 PASS/0 FAIL；刷新清空测试内存 |
| 2026-10-18 | preview logs cursor0/500/1000 | 读取reload1完整QA证据 | 否 | 平台未返回 | 未取得 | MAKER-FREE；会话身份匹配，next_cursor1241，truncated=false；Lua双通道日志去重统计 |
| 2026-10-18 | preview status / refresh | 关闭开发开关并恢复普通试玩 | 否 | 平台未返回 | 未取得 | MAKER-FREE；只刷新已确认活跃会话；普通版不自动执行测试，不远端提交 |
| 2026-10-18 | preview logs / check（reload2） | 普通版本初始化与原报错核对 | 否 | 平台未返回 | 未取得 | MAKER-FREE；入口及V0.2 READY，进程存活；check FAIL仅保留原DDS/DLL问题，未伪报就绪 |
| 2026-10-18 | Lua LSP / preview status / refresh | 入口地面物品优先修正与边界回归 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error；只刷新活跃会话至reload3，未启动新会话 |
| 2026-10-18 | preview logs cursor0/500/1000（reload3） | 最终完整回归证据 | 否 | 平台未返回 | 未取得 | MAKER-FREE；353 PASS/0 FAIL，含78项物流/入口检查；next_cursor1246，原始日志保留 |
| 2026-10-18 | Lua LSP / preview status / refresh | 最终关闭全部开发开关并恢复普通版 | 否 | 平台未返回 | 未取得 | MAKER-FREE；静态0 Error/99 Warning/58 Hint；仅刷新存活会话，无远端操作或生成式任务 |
| 2026-10-18 | preview logs / check（reload4） | 最终普通物流版本只读确认 | 否 | 平台未返回 | 未取得 | MAKER-FREE；V0.2初始化及进程状态、原报错与普通开关状态见v02-release-logs/check.json；没有再次启动、远端构建或资源生成 |


| 2026-10-18 | Maker status / 本地预览status | 实体物流开发前确认绑定及存活会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；采用当前绑定目录，未改变服务环境或升级包 |
| 2026-10-18 | Lua LSP诊断 | 实体物流模块与场景接入检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；最终0 Error，警告/提示保留；无生成式调用 |
| 2026-10-18 | preview status/refresh/logs/check（reload5～8） | 实体物流场景、整合回归与实际画面检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；只刷新存活会话，最终222 PASS/0 FAIL；一次审批超时未执行，按提示重试成功 |
| 2026-10-18 | preview status/refresh/logs/check（reload9） | 关闭开发开关并恢复普通试玩 | 否 | 平台未返回 | 未取得 | MAKER-FREE；运行中，原DDS/DLL环境告警保留；无提交/远端构建 |

| 2026-10-18 | Maker status / preview status | R4验收问题修复前确认上下文 | 否 | 平台未返回 | 未取得 | MAKER-FREE；当前绑定项目、活跃reload9；0.0.37更新仅提示，未升级 |
| 2026-10-18 | Lua LSP | R4空间选点、编辑、投影交互诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；最终0 Error/232 Warning/69 Hint；未调用生成式能力 |
| 2026-10-18 | preview status/refresh/logs（reload10～11） | R4全套回归与快速拖动视觉复测 | 否 | 平台未返回 | 未取得 | MAKER-FREE；仅刷新确认存活会话，最终261 PASS/0 FAIL；无远端操作 |
| 2026-10-18 | preview status/refresh/logs/check（reload12） | 关闭测试开关、恢复普通试玩 | 否 | 平台未返回 | 未取得 | MAKER-FREE；默认样例恢复，原环境告警保留 |
| 2026-10-18 16:20 | preview status/start/logs/check | 按用户指令启动本地游戏 | 否 | 平台未返回 | 未取得 | MAKER-FREE；新会话108e080a-f88a-4428-aa70-1a0d7bbce4b9运行中；原DDS/DLL错误保留；无生成式调用 |
| 2026-10-18 16:25 | preview status/start/check | 一键桌面启动脚本验证 | 否 | 平台未返回 | 未取得 | MAKER-FREE；验证启动与复用当前会话；原DDS/DLL错误保留；未调用生成式能力 |
| 2026-10-18 | Lua LSP | V0.3静态诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；0 Error/248 Warning/62 Hint；未调用生成式能力 |
| 2026-10-18 | preview start/run/status/refresh/logs/check | V0.3原生回归与普通试玩恢复 | 否 | 平台未返回 | 未取得 | MAKER-FREE；379 PASS/0 FAIL；最终reload8普通版；原环境告警保留，无付费生成或远端构建 |
| 2026-10-18 | Lua LSP | V0.3验收反馈修复静态诊断 | 否 | 平台未返回 | 未取得 | MAKER-FREE；最终0 Error/263 Warning/61 Hint；无生成能力调用，未查询余额 |
| 2026-10-18 | preview status/refresh/logs/check | V0.3反馈修复回归及普通版恢复（reload9～14） | 否 | 平台未返回 | 未取得 | MAKER-FREE；403唯一断言通过；只刷新存活会话，原环境告警保留；无提交/远端构建/付费生成 |
| 2026-10-18 | maker_status_lite | V0.4资产制作前核对项目 | 否 | 平台未返回 | 未取得 | MAKER-FREE；显式target_dir确认绑定、认证存在；0.0.36提示0.0.37可更新，未升级；未触发构建 |
| 2026-10-18 | edit_image | 员工四向透明静态样板 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；仅调用一次，沿用无道具三视图；实际2304×1536 RGBA；资源与原始结果已保存，待外观审核；未返回真实用量或扣费来源 |
| 2026-10-18 | preview status | V0.4新资源保存后检查会话 | 否 | 平台未返回 | 未取得 | MAKER-FREE；既有reload14 stopped/process_alive=false；未重启预览，未运行游戏自检 |
| 2026-10-18 | maker_status_lite | 平静表情编辑前确认当前绑定 | 否 | 平台未返回 | 未取得 | MAKER-FREE；绑定与认证存在；沿用0.0.36，已知更新未执行 |
| 2026-10-18 | edit_image | 四向员工平静表情与脸部校正 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；一次编辑，2304×1536 RGBA，原四向图保留；来源/提示词/映射已保存；未取得真实扣费/余额 |
| 2026-10-18 | preview status | 平静版新资源保存后会话检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload14 stopped/process_alive=false；未重启或构建 |
| 2026-10-18 | maker_status_lite | 用户面部参考编辑前核对绑定 | 否 | 平台未返回 | 未取得 | MAKER-FREE；当前项目绑定与认证存在，沿用0.0.36，未升级 |
| 2026-10-18 | edit_image | 按用户面部特写制作四向角色表情 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；一次生成，2304×1536 RGBA，保留闭嘴浅笑/半睁黑眼/双颊红线；主体及参考原图保留，来源映射与提示词已保存，待审核 |
| 2026-10-18 | preview status | 面部参考版资源保存后状态检查 | 否 | 平台未返回 | 未取得 | MAKER-FREE；reload14仍停止，未重启或构建 |
| 2026-10-18 | edit_image | 角色front_carry_idle，4帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/front_carry_idle.json <!-- char-state-front_carry_idle-r1 --> |
| 2026-10-18 | edit_image | 角色front_operate，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/front_operate.json <!-- char-state-front_operate-r1 --> |
| 2026-10-18 | edit_image | 角色front_run，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/front_run.json <!-- char-state-front_run-r1 --> |
| 2026-10-18 | edit_image | 角色front_walk，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/front_walk.json <!-- char-state-front_walk-r1 --> |
| 2026-10-18 | batch_generate_images | 角色front_carry_run，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/front_carry_run.json <!-- char-state-front_carry_run-r1 --> |
| 2026-10-18 | batch_generate_images | 角色front_carry_walk，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/front_carry_walk.json <!-- char-state-front_carry_walk-r1 --> |
| 2026-10-18 | batch_generate_images | 角色front_think，12帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/front_think.json <!-- char-state-front_think-r1 --> |
| 2026-10-18 | batch_generate_images | 角色left_carry_idle，4帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/left_carry_idle.json <!-- char-state-left_carry_idle-r1 --> |
| 2026-10-18 | batch_generate_images | 角色left_carry_run，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/left_carry_run.json <!-- char-state-left_carry_run-r1 --> |
| 2026-10-18 | batch_generate_images | 角色left_carry_walk，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/left_carry_walk.json <!-- char-state-left_carry_walk-r1 --> |
| 2026-10-18 | batch_generate_images | 角色left_idle，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/left_idle.json <!-- char-state-left_idle-r1 --> |
| 2026-10-18 | batch_generate_images | 角色left_operate，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/left_operate.json <!-- char-state-left_operate-r1 --> |
| 2026-10-18 | batch_generate_images | 角色left_run，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/left_run.json <!-- char-state-left_run-r1 --> |
| 2026-10-18 | batch_generate_images | 角色left_walk，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/left_walk.json <!-- char-state-left_walk-r1 --> |
| 2026-10-18 | batch_generate_images | 角色back_idle，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/back_idle.json <!-- char-state-back_idle-r1 --> |
| 2026-10-18 | batch_generate_images | 角色left_think，12帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/left_think.json <!-- char-state-left_think-r1 --> |
| 2026-10-18 | batch_generate_images | 角色right_carry_idle，4帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/right_carry_idle.json <!-- char-state-right_carry_idle-r1 --> |
| 2026-10-18 | batch_generate_images | 角色right_carry_run，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/right_carry_run.json <!-- char-state-right_carry_run-r1 --> |
| 2026-10-18 | batch_generate_images | 角色right_carry_walk，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/right_carry_walk.json <!-- char-state-right_carry_walk-r1 --> |
| 2026-10-18 | batch_generate_images | 角色right_idle，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/right_idle.json <!-- char-state-right_idle-r1 --> |
| 2026-10-18 | batch_generate_images | 角色right_operate，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/right_operate.json <!-- char-state-right_operate-r1 --> |
| 2026-10-18 | batch_generate_images | 角色right_run，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/right_run.json <!-- char-state-right_run-r1 --> |
| 2026-10-18 | batch_generate_images | 角色right_think，12帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/right_think.json <!-- char-state-right_think-r1 --> |
| 2026-10-18 | batch_generate_images | 角色right_walk，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/right_walk.json <!-- char-state-right_walk-r1 --> |
| 2026-10-18 | batch_generate_images | 角色back_carry_idle，4帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/back_carry_idle.json <!-- char-state-back_carry_idle-r1 --> |
| 2026-10-18 | batch_generate_images | 角色back_carry_run，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/back_carry_run.json <!-- char-state-back_carry_run-r1 --> |
| 2026-10-18 | batch_generate_images | 角色back_carry_walk，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/back_carry_walk.json <!-- char-state-back_carry_walk-r1 --> |
| 2026-10-18 | batch_generate_images | 角色back_operate，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/back_operate.json <!-- char-state-back_operate-r1 --> |
| 2026-10-18 | batch_generate_images | 角色back_run，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/back_run.json <!-- char-state-back_run-r1 --> |
| 2026-10-18 | batch_generate_images | 角色back_think，12帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/back_think.json <!-- char-state-back_think-r1 --> |
| 2026-10-18 | batch_generate_images | 角色back_walk，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/receipts/back_walk.json <!-- char-state-back_walk-r1 --> |
| 2026-10-18 | edit_image | 角色back_think r2，12帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/back_think-r2.maker-result.json <!-- char-state-back_think-r2 --> |
| 2026-10-18 | edit_image | 角色front_carry_run r2，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/front_carry_run-r2.maker-result.json <!-- char-state-front_carry_run-r2 --> |
| 2026-10-18 | edit_image | 角色front_run r2，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；成功=True；原始结果见states_v1/front_run-r2.maker-result.json <!-- char-state-front_run-r2 --> |
| 2026-10-18 | edit_image | 角色front_run r3，8帧步相修订 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台生成成功，步态自检未通过，未启用；结果见states_v1/front_run-r3.maker-result.json <!-- char-state-front_run-r3 --> |
| 2026-10-18 | edit_image | 角色front_carry_run r3，8帧步相修订 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台生成成功，步态自检未通过，未启用；结果见states_v1/front_carry_run-r3.maker-result.json <!-- char-state-front_carry_run-r3 --> |
| 2026-10-18 | edit_image | back_carry_idle carry_v2修订，4帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见states_v1/back_carry_idle-carry_v2.maker-result.json <!-- char-state-back_carry_idle-carry_v2 --> |
| 2026-10-18 | edit_image | left_walk gait_v2修订，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见states_v1/left_walk-gait_v2.maker-result.json <!-- char-state-left_walk-gait_v2 --> |
| 2026-10-18 | edit_image | left_walk gait_v3修订，8帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见states_v1/left_walk-gait_v3.maker-result.json <!-- char-state-left_walk-gait_v3 --> |
| 2026-10-18 | edit_image | front_run_depth_f01 single_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v1/receipts/frame_01-r1.json <!-- char-state-front_run_depth_f01-single_r1 --> |
| 2026-10-18 | edit_image | front_run_depth_f02 single_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v1/receipts/frame_02-r1.json <!-- char-state-front_run_depth_f02-single_r1 --> |
| 2026-10-18 | edit_image | front_run_depth_f03 single_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v1/receipts/frame_03-r1.json <!-- char-state-front_run_depth_f03-single_r1 --> |
| 2026-10-18 | edit_image | front_run_depth_f04 single_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v1/receipts/frame_04-r1.json <!-- char-state-front_run_depth_f04-single_r1 --> |
| 2026-10-18 | edit_image | front_run_depth_f05 single_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v1/receipts/frame_05-r1.json <!-- char-state-front_run_depth_f05-single_r1 --> |
| 2026-10-18 | edit_image | front_run_depth_f06 single_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v1/receipts/frame_06-r1.json <!-- char-state-front_run_depth_f06-single_r1 --> |
| 2026-10-18 | edit_image | front_run_depth_f07 single_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v1/receipts/frame_07-r1.json <!-- char-state-front_run_depth_f07-single_r1 --> |
| 2026-10-18 | edit_image | front_run_depth_f08 single_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v1/receipts/frame_08-r1.json <!-- char-state-front_run_depth_f08-single_r1 --> |
| 2026-10-18 | edit_image | front_run_depth2_f01 single_depth2_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v2/receipts/frame_01-r1.json <!-- char-state-front_run_depth2_f01-single_depth2_r1 --> |
| 2026-10-18 | edit_image | front_run_depth2_f02 single_depth2_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v2/receipts/frame_02-r1.json <!-- char-state-front_run_depth2_f02-single_depth2_r1 --> |
| 2026-10-18 | edit_image | front_run_depth2_f03 single_depth2_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v2/receipts/frame_03-r1.json <!-- char-state-front_run_depth2_f03-single_depth2_r1 --> |
| 2026-10-18 | edit_image | front_run_depth2_f06 single_depth2_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v2/receipts/frame_06-r1.json <!-- char-state-front_run_depth2_f06-single_depth2_r1 --> |
| 2026-10-18 | edit_image | front_run_depth2_f04 single_depth2_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v2/receipts/frame_04-r1.json <!-- char-state-front_run_depth2_f04-single_depth2_r1 --> |
| 2026-10-18 | edit_image | front_run_depth2_f05 single_depth2_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v2/receipts/frame_05-r1.json <!-- char-state-front_run_depth2_f05-single_depth2_r1 --> |
| 2026-10-18 | edit_image | front_run_depth2_f07 single_depth2_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v2/receipts/frame_07-r1.json <!-- char-state-front_run_depth2_f07-single_depth2_r1 --> |
| 2026-10-18 | edit_image | front_run_depth2_f08 single_depth2_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v2/receipts/frame_08-r1.json <!-- char-state-front_run_depth2_f08-single_depth2_r1 --> |
| 2026-10-18 | edit_image | front_run_depth2_f04 single_depth2_r2修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v2/receipts/frame_04-r2.json <!-- char-state-front_run_depth2_f04-single_depth2_r2 --> |
| 2026-10-18 | edit_image | front_run_depth2_f07 single_depth2_r2修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/front_run_depth_demo_v2/receipts/frame_07-r2.json <!-- char-state-front_run_depth2_f07-single_depth2_r2 --> |
| 2026-10-19 | edit_image | left_run_depth_f01 single_left_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=unconfirmed；美术质量另行审核；结果见assets/image/employee_v04/left_run_depth_demo_v1/receipts/frame_01-r1.json <!-- char-state-left_run_depth_f01-single_left_depth_r1 --> |
| 2026-10-19 | edit_image | left_run_depth_f02 single_left_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/left_run_depth_demo_v1/receipts/frame_02-r1.json <!-- char-state-left_run_depth_f02-single_left_depth_r1 --> |
| 2026-10-19 | edit_image | left_run_depth_f03 single_left_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/left_run_depth_demo_v1/receipts/frame_03-r1.json <!-- char-state-left_run_depth_f03-single_left_depth_r1 --> |
| 2026-10-19 | edit_image | left_run_depth_f04 single_left_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/left_run_depth_demo_v1/receipts/frame_04-r1.json <!-- char-state-left_run_depth_f04-single_left_depth_r1 --> |
| 2026-10-19 | edit_image | right_run_depth_f01 single_right_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/right_run_depth_demo_v1/receipts/frame_01-r1.json <!-- char-state-right_run_depth_f01-single_right_depth_r1 --> |
| 2026-10-19 | edit_image | right_run_depth_f02 single_right_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/right_run_depth_demo_v1/receipts/frame_02-r1.json <!-- char-state-right_run_depth_f02-single_right_depth_r1 --> |
| 2026-10-19 | edit_image | right_run_depth_f03 single_right_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/right_run_depth_demo_v1/receipts/frame_03-r1.json <!-- char-state-right_run_depth_f03-single_right_depth_r1 --> |
| 2026-10-19 | edit_image | back_run_depth_f01 single_back_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/back_run_depth_demo_v1/receipts/frame_01-r1.json <!-- char-state-back_run_depth_f01-single_back_depth_r1 --> |
| 2026-10-19 | edit_image | back_run_depth_f02 single_back_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/back_run_depth_demo_v1/receipts/frame_02-r1.json <!-- char-state-back_run_depth_f02-single_back_depth_r1 --> |
| 2026-10-19 | edit_image | back_run_depth_f03 single_back_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/back_run_depth_demo_v1/receipts/frame_03-r1.json <!-- char-state-back_run_depth_f03-single_back_depth_r1 --> |
| 2026-10-19 | edit_image | left_run_depth_f01 single_left_depth_r2修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/left_run_depth_demo_v1/receipts/frame_01-r2.json <!-- char-state-left_run_depth_f01-single_left_depth_r2 --> |
| 2026-10-19 | edit_image | left_run_depth_f05 single_left_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/left_run_depth_demo_v1/receipts/frame_05-r1.json <!-- char-state-left_run_depth_f05-single_left_depth_r1 --> |
| 2026-10-19 | edit_image | left_run_depth_f06 single_left_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/left_run_depth_demo_v1/receipts/frame_06-r1.json <!-- char-state-left_run_depth_f06-single_left_depth_r1 --> |
| 2026-10-19 | edit_image | left_run_depth_f07 single_left_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/left_run_depth_demo_v1/receipts/frame_07-r1.json <!-- char-state-left_run_depth_f07-single_left_depth_r1 --> |
| 2026-10-19 | edit_image | right_run_depth_f04 single_right_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/right_run_depth_demo_v1/receipts/frame_04-r1.json <!-- char-state-right_run_depth_f04-single_right_depth_r1 --> |
| 2026-10-19 | edit_image | right_run_depth_f05 single_right_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/right_run_depth_demo_v1/receipts/frame_05-r1.json <!-- char-state-right_run_depth_f05-single_right_depth_r1 --> |
| 2026-10-19 | edit_image | right_run_depth_f06 single_right_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/right_run_depth_demo_v1/receipts/frame_06-r1.json <!-- char-state-right_run_depth_f06-single_right_depth_r1 --> |
| 2026-10-19 | edit_image | back_run_depth_f04 single_back_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/back_run_depth_demo_v1/receipts/frame_04-r1.json <!-- char-state-back_run_depth_f04-single_back_depth_r1 --> |
| 2026-10-19 | edit_image | back_run_depth_f05 single_back_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/back_run_depth_demo_v1/receipts/frame_05-r1.json <!-- char-state-back_run_depth_f05-single_back_depth_r1 --> |
| 2026-10-19 | edit_image | left_run_depth_f08 single_left_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/left_run_depth_demo_v1/receipts/frame_08-r1.json <!-- char-state-left_run_depth_f08-single_left_depth_r1 --> |
| 2026-10-19 | edit_image | right_run_depth_f07 single_right_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/right_run_depth_demo_v1/receipts/frame_07-r1.json <!-- char-state-right_run_depth_f07-single_right_depth_r1 --> |
| 2026-10-19 | edit_image | right_run_depth_f08 single_right_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/right_run_depth_demo_v1/receipts/frame_08-r1.json <!-- char-state-right_run_depth_f08-single_right_depth_r1 --> |
| 2026-10-19 | edit_image | back_run_depth_f06 single_back_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/back_run_depth_demo_v1/receipts/frame_06-r1.json <!-- char-state-back_run_depth_f06-single_back_depth_r1 --> |
| 2026-10-19 | edit_image | back_run_depth_f07 single_back_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=True；美术质量另行审核；结果见assets/image/employee_v04/back_run_depth_demo_v1/receipts/frame_07-r1.json <!-- char-state-back_run_depth_f07-single_back_depth_r1 --> |
| 2026-10-19 | edit_image | back_run_depth_f08 single_back_depth_r1修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=unconfirmed；美术质量另行审核；结果见assets/image/employee_v04/back_run_depth_demo_v1/receipts/frame_08-r1.json <!-- char-state-back_run_depth_f08-single_back_depth_r1 --> |
| 2026-10-19 | edit_image | back_run_depth_f08 single_back_depth_r2修订，1帧 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；平台成功=unconfirmed；美术质量另行审核；结果见assets/image/employee_v04/back_run_depth_demo_v1/receipts/frame_08-r2.json <!-- char-state-back_run_depth_f08-single_back_depth_r2 --> |
| 2026-10-19 | Codex独立image_gen | 补齐背面跑动第8帧 | 是 | 不涉及Tap计费 | 未查询 | 用户要求停止Maker后使用独立图片工具；未把图片模型记为GPT6.1；详见builtin-frame08-request.json <!-- depth-back08-nontap-20261019 --> |
| 2026-10-19 | 本地开发与官方preview CLI | V0.6十天经营、金币、存档及Windows运行验证 | 否 | 不涉及生成计费 | 未查询 | LOCAL / MAKER-FREE；未调用Tap生成能力，未查询余额，不填写估算积分 |
| 2026-10-19 | batch_generate_images | V0.4静态五食材图集与三槽烹饪顶面样板 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；2/2返回，食材光晕待修、烹饪顶面初审通过；原始结果assets/image/v04_static/receipts/sample-batch-r1.json |
| 2026-10-19 | edit_image | V0.4食材透明边缘修订 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；返回成功，真实透明合成后轮廓通过，隐藏RGB导出时清零；food-clean-r2.json |
| 2026-10-19 | batch_generate_images | V0.4其余八类设备顶面 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；8/8返回，九设备联系表初审通过；devices-batch-r1.json |
| 2026-10-19 | batch_generate_images | V0.4两区地面、传送带、功能标识与标题背景 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；5/5返回，功能图集实际1024×1536与请求不同，按实图核对后适配；environment-batch-r1.json |
| 2026-10-19 | batch_generate_images | V0.4 UI八类底框与二十操作图标图集 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；2/2返回；actualSize底框1024×1536、图标1536×1024；保留ui-batch-r1.json，按实图裁切审核 |
| 2026-10-19 | edit_image | 左侧走路4帧样板 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；腿相位重复，拒收；assets/image/employee_v04/four_frame_v1/receipts/left_walk-r1.json <!-- four-frame-left_walk-r1 --> |
| 2026-10-19 | edit_image | 左侧走路第一次修订 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；仍有重复相位，拒收；assets/image/employee_v04/four_frame_v1/receipts/left_walk-r2.json <!-- four-frame-left_walk-r2 --> |
| 2026-10-19 | edit_image | 左侧走路第二次修订 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；完整四姿势，简化腿部交替样板通过；assets/image/employee_v04/four_frame_v1/receipts/left_walk-r3.json <!-- four-frame-left_walk-r3 --> |

| 2026-10-19 | edit_image | 四帧员工 back_walk-r1 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；响应中断，执行/收费未知；用户已明确授权背面走路补生成；assets/image/employee_v04/four_frame_v1/receipts/back_walk-r1.json <!-- four-frame-back_walk-r1 --> |

| 2026-10-19 | edit_image | 四帧员工 back_walk-r2 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；本地已返回；素材质量另审；assets/image/employee_v04/four_frame_v1/receipts/back_walk-r2.json <!-- four-frame-back_walk-r2 --> |

| 2026-10-19 | edit_image | 四帧员工 front_walk-r1 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；本地已返回；素材质量另审；assets/image/employee_v04/four_frame_v1/receipts/front_walk-r1.json <!-- four-frame-front_walk-r1 --> |

| 2026-10-19 | edit_image | 四帧员工 front_walk-r2 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；本地已返回；素材质量另审；assets/image/employee_v04/four_frame_v1/receipts/front_walk-r2.json <!-- four-frame-front_walk-r2 --> |

| 2026-10-19 | edit_image | 四帧员工 left_run-r1 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；本地已返回；素材质量另审；assets/image/employee_v04/four_frame_v1/receipts/left_run-r1.json <!-- four-frame-left_run-r1 --> |

| 2026-10-19 | edit_image | 四帧员工 right_run-r1 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；本地已返回；素材质量另审；assets/image/employee_v04/four_frame_v1/receipts/right_run-r1.json <!-- four-frame-right_run-r1 --> |

| 2026-10-19 | edit_image | 四帧员工 right_walk-r1 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；本地已返回；素材质量另审；assets/image/employee_v04/four_frame_v1/receipts/right_walk-r1.json <!-- four-frame-right_walk-r1 --> |

| 2026-10-19 | edit_image | 四帧员工 right_walk-r2 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；本地已返回；素材质量另审；assets/image/employee_v04/four_frame_v1/receipts/right_walk-r2.json <!-- four-frame-right_walk-r2 --> |

| 2026-10-19 | edit_image | 四帧员工 right_walk-single3 | 是 | 平台未返回 | 未取得 | MAKER-POINTS；本地已返回；素材质量另审；assets/image/employee_v04/four_frame_v1/receipts/right_walk-single3.json <!-- four-frame-right_walk-single3 --> |
| 2026-10-19 | Codex内置image_gen | 四帧员工完整姿势补充与候选修订，共10次调用 | 是 | 不涉及Tap调用 | 未查询 | 已返回文件保留，部分未采用；非Tap平台消费不填Tap扣费；提供方模型未暴露 <!-- four-frame-builtin-20261019 --> |
| 2026-10-19 | text_to_music | V0.7正式经营BGM，1首156.8秒 | 是 | 平台未返回 | 未取得 | 已本地返回；任务temp_8ebed0bd-d2d3-4f47-b15c-9bb6a133af19，回执assets/audio/v07/receipts/music.json；未声称控制扣费来源 |
| 2026-10-19 | batch_sound_effects | V0.7脚步/取放/建造/煎肉/机器/订单/交付，共8类 | 是 | 平台未返回 | 未取得 | 8项成功，失败0；回执assets/audio/v07/receipts/sfx.json，单次批量调用不重复计数 |
