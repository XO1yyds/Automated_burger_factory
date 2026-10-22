# 四帧动画素材复用清单

2026-10-19。按用户最新要求优先使用文件夹中已有完整姿势，不追加生成。本清单是当前实际选帧与运行配置，旧8帧清单保留为历史。

- 32组/128帧位；**113帧位复用本轮前素材，15帧位使用本轮已返回图片**。
- 同一动作优先同批次整帧，舍弃头身比例不一致的新候选；不切头、不处理眼部。
- 4帧是简化动作，不等同于旧8帧连续步态；旧候选的历史未通过记录仍保留。

|方向/动作|帧数|fps|原始帧索引（从1计）|本轮前帧位|取舍|
|---|---:|---:|---|---:|---|
|front_idle|4|2|1 / 3 / 5 / 7|4/4|Reuse complete authored poses; no head/eye replacement|
|front_walk|4|6|1 / 3 / 5 / 横条1|3/4|Neutral/step/neutral/opposite lifting foot; simple4, not smooth8|
|front_run|4|8|frame_01.png / frame_03.png / frame_05.png / frame_07.png|4/4|Reuse depth-guided complete run poses across both half-cycles|
|front_carry_idle|4|2|1 / 2 / 3 / 4|4/4|Reuse complete authored poses; no head/eye replacement|
|front_carry_walk|4|6|1 / 3 / 5 / front_carry_walk_b.png|3/4|Existing neutral and step poses with already-delivered opposite-leg whole pose; no props baked in|
|front_carry_run|4|8|1 / 3 / 5 / 7|4/4|Reuse same-batch full-body poses; prefer odd-index passing phase over newly generated proportion changes|
|front_operate|4|6|1 / 3 / 5 / 7|4/4|Reuse complete authored poses; no head/eye replacement|
|front_think|4|2|1 / 4 / 7 / 10|4/4|Reuse complete authored poses; no head/eye replacement|
|left_idle|4|2|1 / 3 / 5 / 7|4/4|Reuse complete authored poses; no head/eye replacement|
|left_walk|4|6|横条1 / 横条2 / 横条3 / 横条4|0/4|Reviewed4-pose strip, near/far overlap changes after half-cycle|
|left_run|4|8|横条1 / 横条2 / 横条3 / 横条4|0/4|Simple run poses, complete head/body and different knee bends|
|left_carry_idle|4|2|1 / 2 / 3 / 4|4/4|Reuse complete authored poses; no head/eye replacement|
|left_carry_walk|4|6|1 / 3 / 5 / left_carry_walk_b_r2.png|3/4|Existing neutral and step poses with already-delivered opposite-leg whole pose; no props baked in|
|left_carry_run|4|8|1 / 3 / 5 / 6|4/4|Reuse same-batch full-body poses; prefer odd-index passing phase over newly generated proportion changes|
|left_operate|4|6|1 / 3 / 5 / 7|4/4|Reuse complete authored poses; no head/eye replacement|
|left_think|4|2|1 / 4 / 7 / 10|4/4|Reuse complete authored poses; no head/eye replacement|
|right_idle|4|2|1 / 3 / 5 / 7|4/4|Reuse complete authored poses; no head/eye replacement|
|right_walk|4|6|1 / 2 / 4 / 7|4/4|Reuse same-batch complete poses including odd-index transitions; simple4 gait|
|right_run|4|8|1 / 3 / 5 / 6|4/4|Reuse same-batch high-knee poses and odd-index transition; not only accelerated walk|
|right_carry_idle|4|2|1 / 2 / 3 / 4|4/4|Reuse complete authored poses; no head/eye replacement|
|right_carry_walk|4|6|1 / 3 / 5 / 6|4/4|Reuse one existing carrying run passing pose; all complete characters, simple4|
|right_carry_run|4|8|1 / 3 / 5 / 6|4/4|Reuse same-batch full-body poses; prefer odd-index passing phase over newly generated proportion changes|
|right_operate|4|6|1 / 3 / 5 / 7|4/4|Reuse complete authored poses; no head/eye replacement|
|right_think|4|2|1 / 4 / 7 / 10|4/4|Reuse complete authored poses; no head/eye replacement|
|back_idle|4|2|1 / 3 / 5 / 7|4/4|Reuse complete authored poses; no head/eye replacement|
|back_walk|4|6|横条1 / 横条2 / 横条3 / 横条4|0/4|Rear4-pose strip; alternate lifting foot|
|back_run|4|8|frame_01.png / frame_03.png / frame_05.png / frame_07.png|4/4|Reuse depth-guided complete run poses across both half-cycles|
|back_carry_idle|4|2|1 / 2 / 3 / 4|4/4|Reuse complete authored poses; no head/eye replacement|
|back_carry_walk|4|6|1 / 3 / 6 / 4|4/4|Reuse rear carry_run frame4 for opposite heel; no new rear request|
|back_carry_run|4|8|1 / 3 / 4 / 8|4/4|Includes original frame4 opposite outsole, missed by even-index extraction|
|back_operate|4|6|1 / 3 / 5 / 7|4/4|Reuse complete authored poses; no head/eye replacement|
|back_think|4|2|1 / 4 / 7 / 10|4/4|Reuse complete authored poses; no head/eye replacement|

精确原始路径和裁切区域：[selected.json](../assets/image/employee_v04/four_frame_v1/selected.json)；运行配置：[CharacterFrames.lua](../scripts/Factory/CharacterFrames.lua)。

## 需注意的简化与验收边界

- 右侧移动与持物跑动选择同批次旧帧；包含非等间隔的过渡帧，仍需人工观察4帧循环的自然程度。
- 背面、右侧持物走路各借用一帧旧持物跑动的过渡姿势；不是仅调fps将整个跑动冒充走路。
- 新B姿势出现比例差异的组已经改回旧图；未采用候选和生成回执保留，不当作正式素材通过。
- 待机/操作/思考全部复用旧完整姿势；游戏触发、暂停、挂点与Android真机应分别验收。
- 当前不追加生成；后续确有无法复用的缺口先列入待办。
