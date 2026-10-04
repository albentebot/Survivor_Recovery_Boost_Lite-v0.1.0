# Survivor Recovery Boost Lite

每 3 秒自动回复 1 点实血（上限 60），并加速急救包使用和扶起倒地队友。真人 / Bot 幸存者同时生效，使用游戏原本的物品和救援判定。仅在 `coop`（普通战役）和 `realism`（写实）模式下启用。

这是精简版（Lite）：**没有配置文件、聊天命令、Convar 恢复、除颤器加速和异常熔断**。想改数值请直接编辑 `core_new.nut` 中的常量，重新打包 VPK。

|Mod名| 功能 | 默认值 |
|---| --- | --- |
|automatic_health_regeneration| 自动回血 | 每 3 秒回复 1 点实血，上限 60（不超过玩家最大生命值） |
|medkit_and_revive_acceleration| 急救包加速 | 使用读条 3 秒，自用和治疗队友都适用 |
|medkit_and_revive_acceleration| 扶起倒地队友加速 | 读条 3 秒 |

本版本将原来的四个合并功能分开为独立三个Mod，本页面不包含除颤器加速，可查看独立版：[instant_defibrillator](https://github.com/albentebot/instant_defibrillator)。

## 安装

退出游戏，把 `automatic_health_regeneration.vpk`和 `medkit_and_revive_acceleration.vpk` 放到：

```text
/steamapps/common/Left 4 Dead 2/left4dead2/addons/
```

在“附加内容”启用 **Automatic Health Regeneration** 和 **Medkit and Revive Acceleration**。开启单机战役 / 写实，或自己作为房主的本地服务器。

只安装一份本 Mod 的 VPK，源码文件夹无需放入游戏。不需要 SourceMod、Metamod 或其他脚本库。

## 回血规则

- 回复实血。上限取配置上限（60）和玩家最大生命值中的较小值，不会降低其他 Mod 已给出的超额血量。
- 临时血和实血相加将超过上限时，只把本次新增实血重叠的临时血扣掉。例如 50 实血 + 50 临时血会变为 51 实血 + 49 临时血，临时血仍按游戏规则衰减。
- 死亡、濒死、倒地、挂边时暂停回血；不会自动站起、复活或清除黑白状态。被特感控制但仍站立时继续回血。
- 每 0.1 秒检查一次，每 3 秒触发一次回血。游戏卡顿后不会一次补发漏掉的所有回血。
- 真人 / Bot 均生效；感染者不回血。
- 急救包仍须正常操作并消耗，不赠送额外物品。加速是服务端基础时长。

## 动作加速

- 急救包使用时长：3 秒（`first_aid_kit_use_duration`）
- 扶起倒地队友时长：3 秒（`survivor_revive_duration`）

这些 Convar 在 Mod 启动时被硬编码设置。**停止、回合结束或换图时不会恢复为原值**，直到地图切换或服务器重启。完整版会恢复旧值，但 Lite 版没有此功能。

## 兼容与关闭

- 只在普通战役 `coop` 和写实 `realism` 启用，其他模式不生效。
- 启用时设置 `first_aid_kit_use_duration` 和 `survivor_revive_duration` 为 3.0。
- 回合结束或地图切换时停止回血逻辑，但 Convar 保持修改后的值。
- **没有聊天命令**，无法在游戏内开关或调整参数。要修改数值需直接编辑 `core_new.nut` 中的常量并重新打包 VPK。
- 其他回血 Mod 会叠加效果；其他动作加速 Mod 或自定义地图可能改写相同时长。首次测试建议只开启本 Mod。

接口参考：[Valve VScript API](https://developer.valvesoftware.com/wiki/Left_4_Dead_2/Scripting/Script_Functions)、[游戏变量列表](https://github.com/Stabbath/L4D2-Decompiled/blob/master/Misc%20Stuff/commoncvars.txt)。没有内置其他作者的游戏 Mod 或外部运行库。