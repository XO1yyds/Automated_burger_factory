# 首次提交与远端构建完成

2026-10-15（Asia/Shanghai）。用户明确授权将当前已验收Demo提交到Tap制造并远端构建。

- 项目：自动化汉堡店，ID `985f14a8-5c6a-40fe-8303-32adaed37f1d`。
- 提交：`5982c19`，Maker确认已提交并推送main，远端构建成功，预览刷新HTTP 200。
- 提交范围：`.gitignore`、16个Lua脚本、建筑UI设计图和其Maker来源记录，共19个文件。未提交开发文档、日志、临时工具或备份。
- 源码诊断：0 Error/81 Warning/51 Hint；八项开发自检/诊断开关均关闭。18个源代码/资源文件复制前后哈希一致，未修改已验收玩法。
- [Maker项目入口](https://maker.taptap.cn/app/985f14a8-5c6a-40fe-8303-32adaed37f1d?localDev=1)。

## 提交目录与原开发目录

原目录 `D:\MyWork\聚光灯game\CodexDocu` 的首次提交被官方工具在commit/push前拦截：远端新增.gitignore会覆盖本地未跟踪的同名文件。为了保留原开发目录中的物理技能目录和全部本地改动，使用官方init检出同一项目至 `.tmp/maker-submit-20261015`，复制并逐文件校验scripts/assets，再通过Maker官方构建工具提交。没有新建游戏项目，没有手动commit/push，也没有覆盖原开发目录的工具配置。

临时检出初次fetch报Failed writing received data to disk/application；仅该检出设置Git HTTP/1.1后官方init成功。技能安装器出现非阻塞失败，CLI明确允许clone完成，后续远端构建成功；未修复或改动原技能目录。

本地源文件继续以原开发目录为准。原目录Git HEAD尚未前移，后续提交不要直接覆盖其工具目录；可以复用上述同项目提交检出，重新复制并核对最新源文件后由官方Maker工具提交。

## 验证范围与限制

官方工具已确认代码提交、推送及远端构建成功；提交检出工作区干净。运行日志watcher已启动，状态为连续失败0、lastError=null，但核对时尚无runtime.log文件且未收到运行日志，未声称网页实际玩法或视觉已验证。

构建后提交检出依旧缺少本地`.project/project.json`；按项目规则保留该限制，不自动重复构建、补造身份、生成测试二维码或发布。开发者身份、GameJam绑定和正式上架另行核对。本次未调用生成式能力。

原始工具结果见同名evidence.json。阶段1–8用户验收结论继续有效，本次只做上传构建。
