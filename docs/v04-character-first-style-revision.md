# V0.4 正面待机v5：第一版动作方案、无眼部动作

日期：2026-10-18；待用户审核候选，未接入游戏。

最新指令：“该帧动画无法用肉眼捕捉到移动痕迹，请按照第一版动画制作方案，去除眼部动作后，为我呈现”。本次覆盖v4仅肩部1.5px微动限制，恢复第一版可见的肩臂吸气抬起、呼气落下方案；沿用此前8帧，4fps、2秒循环。

![正面待机v5](../assets/image/employee_v04/front_idle_first_style_v5/final/export512/preview.webp)

- [256运行档动态预览](../assets/image/employee_v04/front_idle_first_style_v5/final/export256/preview.webp)
- [8帧联系表](../assets/image/employee_v04/front_idle_first_style_v5/final/contact-sheet-256.png)
- [512图集配置](../assets/image/employee_v04/front_idle_first_style_v5/final/export512/spritesheet.json)
- [256图集配置](../assets/image/employee_v04/front_idle_first_style_v5/final/export256/spritesheet.json)
- [眼部固定/图集/WebP核查证据](../assets/image/employee_v04/front_idle_first_style_v5/final/evidence.json)

## 实际制作

以第一版原始`employee_v04_front_idle_sample_v1_20261018135246.png`为动作与身份参考，以只有第一槽带人物的八槽布局图约束布局，通过Maker edit_image一次重新制作8个肩臂姿势。原图`assets/image/employee_v04_idle_first_style_no_blink_v5_20261018141853.png`、同名Maker请求与完整返回保留。实际4097×2731、透明RGBA；原图为一行8个独立完整人物，没有跨槽。

这是沿用第一版动作方案的新8帧候选，不是把原4帧逐像素复用，也不宣称动作幅度与原图完全相同。肩臂变化明显，不再采用v4局部1.5px采样方法。所有8帧均为Maker实际绘制的不同姿势，没有通过复制一张图或整体平移来填帧。

本地按真实宽度分槽，以alpha≥16主体边界加1px裁切，清除alpha≤15背景杂点，所有帧共用LANCZOS比例；统一512/256画布和脚底枢轴。原始图始终保留，不覆盖。

为满足“去除眼部动作”，最终导出统一使用第一帧的头脸区域（512坐标y<245）覆盖同区域；不会重新描画眼睛。固定头部也避免逐帧眼睑、瞳孔、视线及发帽细节变化，肩臂姿势保持生成结果。此步骤为现有图块整理，未用本地变形伪造动作。归一化中间结果保留在`normalized`，**最终候选以`final`为准**。

脚底枢轴512为(256,496)、256为(128,248)；图集1548×1548和780×780；各8帧/4fps/无限循环。身体部分为生成式序列，不宣称肩部以外全身像素相同；v4的冻结身体规则已被此次第一版动作方案替代。

## 已检查

已读原始Maker图、归一化联系表及最终联系表。所有帧睁眼，肩臂有不同姿势。
最终512/256两档均逐帧比对眼部与头脸区域，RGBA像素一致；图集回读与源帧相同，WebP8帧循环。左前臂/手部皮肤区域最低边缘变化范围约28px（512档），仅为颜色分割测量，不等于精确关节位移，也不等于人工观感已通过。

最终输出不再每帧重新缩放；头脸固定，脚底共用枢轴。生成衣服/下身细节和动作循环观感仍需用户审核，不能以文件核查冒充动态验收。

制作后CLI preview status：原会话reload14停止、process_alive=false，未重启；证据`docs/v04-character-first-style-preview-status.json`。本轮未改Lua、接入游戏、构建或推送。Maker一次生成未返回真实积分/余额，已按未知值入账。
