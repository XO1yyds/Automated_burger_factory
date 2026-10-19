# Maker 帧动画技能：GitHub检索与本地部署

日期：2026-10-18。用户要求“在github中寻找 帧动画制作skill，为tap制造 mcp部署”。本轮只检索、安装、适配和本地测试，没有生成游戏资产或消耗Tap生成积分。

## 部署结果

已安装独立技能 **maker-frame-animation**，在当前项目内通过Codex/通用Agents/Claude/Cursor/Gemini技能目录发现。下次用户消息即可使用`$maker-frame-animation`；当前进程尚未刷新技能列表时也可通过该文件路径读取，不承诺动态出现新的MCP工具。

- 源目录：`.installer/skills/maker-frame-animation/`。
- Codex入口：`.codex/skills/maker-frame-animation/SKILL.md`。
- 通用入口：`.agents/skills/maker-frame-animation/SKILL.md`。
- 原Maker `sprite-gen`各处说明文件哈希未变。
- 没有更改MCP命令、凭证、服务环境、白名单或平台版本。
- 项目源码/素材共51文件哈希不变；没有启动预览、构建或推送。

这是**调用Maker MCP的Agent技能适配层**，不是向Tap制造远端安装一个服务端插件。Skill是流程说明，MCP工具由服务端提供；[OpenAI官方说明](https://developers.openai.com/plugins/concepts/skills)对此作了区分。

## GitHub候选与选择

| 候选 | 检查结果 | 决定 |
| --- | --- | --- |
| [openai/plugins：sprite-pipeline](https://github.com/openai/plugins/tree/0722921d5542fc593105c27bd52630babd8b8c2a/plugins/game-studio/skills/sprite-pipeline) | 以批准基准生成整组帧，三份Pillow脚本支持参考画布、统一缩放/足底和联系表；原文生成入口为imagegen，非Maker | 采用其流程及三份工具，本地适配生成入口，保留原文与来源 |
| [0x0funky/agent-sprite-forge](https://github.com/0x0funky/agent-sprite-forge) | README包含多供应商API/CLI路由、FFmpeg及视频转帧的更重流程，与本项目Maker积分/授权路线不直接一致 | 未安装，不引入其它账号或自动供应商回退 |
| [aldegad/sprite-gen](https://github.com/aldegad/sprite-gen) | 有Codex/Grok/OpenAI供应商和视频工具链；名称与原Maker技能相同，依赖和处理范围更大 | 未安装，避免同名覆盖与额外服务依赖 |

安装固定提交：`0722921d5542fc593105c27bd52630babd8b8c2a`。使用内置skill-installer，以Git稀疏检出安装源技能并重命名；支持脚本从同一提交获取。GitHub API本轮返回403限流，改用只读`git ls-remote`和固定提交raw文件完成核验，没有使用凭证绕过限流。

在仓库根和game-studio根常见LICENSE/License.txt/License.md位置未找到明示许可；未声称采用MIT/Apache，也未把第三方技能包上传公开仓库。上游原文/文件哈希和许可检查结果保存在`upstream/source.json`，本地使用不代表取得再分发许可。

## 适配内容

1. `SKILL.md`改为中文Maker工作流，原文存为`upstream/SKILL.original.md`。
2. 制作端调用已暴露的`edit_image/generate_image`，不指定未经用户选择的模型；保留完整平台映射与真实积分记录，不调用外部供应商。
3. 原始角色图和单方向基准先审核；单次仅一方向/一动作，整组帧生成后检查真实动作、数量、透明性和一致性，不复制静态帧冒充动画。
4. 保留三份上游Pillow工具，新增本地`pack_frames.py`，导出透明PNG图集、帧JSON与WebP预览。已有目录、空帧、尺寸错误等在写出前拒绝。
5. 明确上游贴底和NEAREST缩放的适用限制：跳跃/位移不能直接贴底；手绘风不强制像素化；不同方向/动作的共同身高须额外核对。
6. 不自动生成视频、不自动游戏接入、不自动构建/推送，也不启动停止的预览。

本地Maker 0.0.36及[官方Maker工作流](https://github.com/taptap/instant-games-open-mcp/blob/main/docs/MAKER.md)公开的代理工具名单没有`sprite_gen`。当前会话可用的是图片/视频等基础工具。因此仅安装说明文件无法补出原生工具；本次是**另建与现有图片工具兼容的路线**，没有修复或绕过原技能状态机。

## 检查与实际限制

运行脚本使用已存在的Python及Pillow10.4.0，无新增全局依赖、API Key、服务或后台进程。技能格式校验需要PyYAML，而系统与打包Python均未包含；已将PyYAML6.0.2仅装到`.tmp/frame-skill-research/validation-deps/`用于校验，不属于游戏依赖。26项合成本地检查通过，记录见[机器可读证据](maker-frame-animation-skill-evidence.json)。覆盖四脚本帮助/编译、画布、四帧统一尺寸/共同足底/共享比例、图集逐像素回读、JSON枢轴、动画WebP、非循环、拒绝覆盖/空帧/尺寸不一致/非法fps、输入不修改。

测试只使用合成图形，未处理员工原图，未调用真实Maker生成，也不代表人形步态、原画一致性、Maker端到端或手机运行效果通过。技能评估用例另存在`evals/evals.json`，付费生成评估未运行。

发现目录仅新增同名Junction，指向唯一安装源。未运行原`install-skills.ps1 all`的全量删除/重建逻辑，以免改写已有技能链接；用本轮仅新增方式注册现有五个发现目录。已有技能不覆盖。

## 使用

下一条消息可写：

> 使用 $maker-frame-animation，按V0.4策划制作正面待机帧动画，先核对最新角色图是否已确认，只做一组样板。

如果只想整理已有动画：

> 使用 $maker-frame-animation，把这张已有帧图统一尺寸并导出图集和预览，不调用生成。

仍须先确认当前员工面部参考版外观，再进行实际帧图制作。安装本身不视为素材已批准或授权额外付费量产。
