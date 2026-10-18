# 当前版本 GitHub 备份

日期：2026-10-18  
目标仓库：https://github.com/XO1yyds/Automated_burger_factory

## 目的与范围

在下一阶段 UI 更新前，将当前项目内容备份到用户指定 GitHub 仓库。

- 包含：`scripts/`、`assets/`、开发文档与验证证据、UI原始参考、待填写需求、Windows启动脚本、README。
- 排除：认证及绑定目录、`.git`、引擎工具与参考库、`.tmp`、运行日志目录、构建/发布产物、旧CLI委派文档、历史ZIP快照。
- 排除项仍保留在原目录，未删除本地文件。
- 当前工作区仍关联原 Maker 仓库，不修改其远端、分支、提交或凭证。
- 使用 `.tmp/github-upload-20261018` 独立检出 GitHub `main`，沿用远端初始化提交，正常追加提交，不强推。
- 这次是 GitHub 源码备份，不调用 Maker 远端构建。

## 检查与状态

- 初始远端提交：`1e6558f14a4e85af2f4326a9a66d5b22566c57c4`，仅有 README。
- 本次会核对文件清单、与原目录的 SHA256、Lua语法，以及凭证模式扫描；不把这些检查当成重新完成全部玩法验收。
- GitHub快照包含 `docs/github-snapshot-manifest.json`，记录上传文件的大小和 SHA256；清单本身不列入其自身哈希。
- 推送结果以远端分支提交及文件树回读为准；上传完成记录另行补充。
