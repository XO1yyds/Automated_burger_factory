# V0.4 四向员工：平静表情修订（待审）

> 后续用户提供了明确面部特写，最新表情以[用户面部参考版](v04-character-face-reference-sample.md)为准，本页保留历史版本。

日期：2026-10-18。用户要求：“将角色面部表情调整为平静状态，不要让脸歪”。使用TapTap Maker `edit_image`在现有四向静态样板上编辑一次，原图保留。

![平静表情四向图](../assets/image/burger_employee_v04_four_direction_calm_20261018133023.png)

布局仍为左上正面、右上左侧、左下右侧、右下背面。已查看完整图片：正面改为闭合嘴、放松眉毛、平视黑瞳，去掉兴奋腮红与张嘴笑容；正面脸部居中，左右侧面改中性表情，背面不增加五官。保留原发型、深灰帽、黑黄制服、短裤及空手站姿。图片是否满足最终观感由用户审核。

- 输入：`assets/image/burger_employee_v04_four_direction_static_20261018132625.png`。
- 输出：`assets/image/burger_employee_v04_four_direction_calm_20261018133023.png`。
- 完整请求、平台原始结果及远端映射保存在同名`.maker-result.json`。
- 实读尺寸2304×1536，RGBA，alpha范围0～255。
- SHA256：`236172276384cb69e76d4d0fd99b5f21b709cf4433b45ec66483e850147c19de`。
- 实际扣费与余额平台未返回，不猜测；本次仅编辑一次。

这仍是静态外观样板，未生成动画或接入游戏，四格枢轴与留白尚待后续适配。资源保存后预览状态为stopped/process_alive=false、reload14，未重启；没有Maker构建或GitHub推送。
