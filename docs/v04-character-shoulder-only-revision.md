# V0.4 正面待机：肩部局部Y轴修订v4

日期：2026-10-18。当前为待用户审核候选，未接入游戏。

用户指出v3有体型放大收缩，要求“仅更改肩部耸肩位置，微微调整y轴位置，其余部分保持不变”“每帧动画的不发生位移变化”。此要求覆盖旧版整幅呼吸重绘方法；保持8帧、无眨眼。

![8帧肩部待机](../assets/image/employee_v04/front_idle_shoulder_v4/export512/preview.webp)

## 最终候选

- [512动态预览](../assets/image/employee_v04/front_idle_shoulder_v4/export512/preview.webp)
- [256运行档动态预览](../assets/image/employee_v04/front_idle_shoulder_v4/export256/preview.webp)
- [肩部允许变化区域示意](../assets/image/employee_v04/front_idle_shoulder_v4/edit_region.png)（粉色仅标注，不在成品中）
- [512图集配置](../assets/image/employee_v04/front_idle_shoulder_v4/export512/spritesheet.json)
- [256图集配置](../assets/image/employee_v04/front_idle_shoulder_v4/export256/spritesheet.json)
- [逐帧机器核查](../assets/image/employee_v04/front_idle_shoulder_v4/evidence.json)

## 制作方法及来源

固定底图来自v3第一张512帧，复制为`fixed_base.png`。不再用独立重绘的全身帧做循环，避免各帧头身宽度、衣服纹理、脸、名牌和站位变化。

本轮使用Maker edit_image一次生成肩部微抬关键姿势，原图为`assets/image/employee_v04_shoulder_up_key_v4_20261018140842.png`，请求与完整平台结果同名保存。实际512×512、透明RGBA。该原始编辑仍有非肩部像素变化，不符合本次冻结要求，**仅保留为姿势参考，不覆盖最终固定身体**。

最终采用用户本轮明确指定的局部Y轴位移方式：两侧肩线/袖山范围内只改变源图Y采样坐标，X坐标固定；512档最高上移1.5px，256档最高上移0.75px。肩部区域内逐渐衰减到零，避免与固定衣领/袖口接缝；衣领、名牌、躯干、裸露上臂和手均排除出变化范围。纹理来自同一底图，不重新画衣服。

这是同一底图的局部2D动画约束导出，不是8张独立AI生成帧，也不是把整幅静态图平移或缩放冒充动作。原技能禁止简单位移冒充完成动画；本次局部肩部Y动作是用户明确指定的修订方式。实现与证据保留在[导出脚本](asset_tools/render_shoulder_only_idle.py)。Maker原图与最终本地导出分别记录线路。

8个采样时刻采用平滑往返曲线，抬肩幅度依次为0、约0.220、0.750、1.280、1.500、1.280、0.750、0.220px（512档）。往返动作中的重复姿势是正常回程，不计算为8幅独立原画。4fps、2秒循环；脚底枢轴512为(256,496)，256为(128,248)，全局变换始终平移(0,0)、缩放(1,1)、旋转0。

## 已完成检查与限制

512和256两档均实际检查全部8张帧：肩部最终蒙版以外RGBA差异像素数均为0。头脸、躯干中心、名牌、手腿鞋分别独立比对一致；可见alpha包围盒恒定，第一帧与固定底图逐像素一致。图集回读像素与源帧一致；WebP均为8帧、无限循环。512图集1548×1548，256图集780×780。

已查看原始Maker关键姿势、允许变化区域示意和8帧联系表。动态观感是否符合用户期望仍待用户审核；机器像素检查不替代这一确认。

本轮本地首帧核查曾发现预乘alpha往返造成零位移时少量肩部像素舍入变化，已改成零位移直接使用底图，重新导出并通过检查；原单帧诊断保留于`diagnostic-first-frame-rounding`，不属于动画帧目录。

保存后CLI preview status确认原会话reload14停止、process_alive=false，未重启，证据`docs/v04-character-shoulder-preview-status.json`。未修改Lua、远端构建或推送。平台未返回本次真实积分消耗和余额，已按未知值记账。
