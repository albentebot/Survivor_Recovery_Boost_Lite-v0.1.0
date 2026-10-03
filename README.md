# Survivor Recovery Boost 0.1.0 — 第三个独立Mod

每秒自动回血，并加快打包、除颤和扶人。默认真人和Bot幸存者同时生效，使用游戏原本的物品、救援判定和消耗规则。

| 功能 | 默认值 |
| --- | --- |
| 自动回血 | 每秒回复1点实血，上限100 |
| 急救包 | 使用读条2秒，自用和治疗队友都适用 |
| 除颤器 | 使用读条1秒，读条完成后的复活延迟0.5秒 |
| 扶起倒地队友 | 读条1秒 |

这是测试版：已通过语法检查、模拟逻辑和VPK内容校验，尚未运行L4D2实测。动画、打断判定、肾上腺素和其他Mod可能影响实际耗时；表中的秒数是设置的基础时长。

## 安装

退出游戏，把 `survivor_recovery_boost.vpk` 放到：

```text
Steam/steamapps/common/Left 4 Dead 2/left4dead2/addons/
```

在“附加内容”启用 **Survivor Recovery Boost (Regen and Fast Actions)**。开启单机战役/写实，或自己作为房主的本地服务器。

聊天按Y输入 `!rb` 查看状态；在控制台使用 `say !rb`，不要直接输入 `!rb`。状态显示实际读回的打包、除颤、扶人时长。

只安装一份本Mod的VPK，源码文件夹无需放入游戏。不需要SourceMod、Metamod或其他脚本库。可以单独使用，也可以与之前的Bot TeamPlus 0.1.2、Survivor Hazard Shield 0.1.0一起启用，之前两个VPK保留即可。

## 回血规则

- 回复实血。上限取配置上限和玩家最大生命值中的较小值，不会降低其他Mod已给出的超额血量。
- 临时血和实血相加将超过上限时，只把本次新增实血重叠的临时血扣掉。例如50实血+50临时血会变为51实血+49临时血，临时血仍按游戏规则衰减。
- 死亡、濒死、倒地、挂边时暂停回血；不会自动站起、复活或清除黑白状态。被特感控制但仍站立时继续回血。
- 每秒检查所有幸存者，真人/Bot均生效；感染者不回血。游戏卡顿后不一次补发漏掉的所有回血。
- 急救包和除颤器仍须正常操作并消耗，不赠送额外物品。加速是服务端基础时长，已经进行中的动作建议结束后再改设置。

## 聊天命令

所有玩家可查看：

```text
!rb
```

以下命令限本地房主：

```text
!rboff                         关闭回血及加速，保存关闭状态
!rbon                          开启
!rbreload                      重读配置
!rbset regen_amount 2          每秒回复2点实血
!rbset regen_amount 0          只关闭回血，保留动作加速
!rbset medkit_seconds 1.5      打包1.5秒
!rbset defib_seconds 1         除颤读条1秒
!rbset defib_return_seconds 0.5 除颤读条后的复活延迟
!rbset revive_seconds 1        扶人1秒
!rbset regen_cap 100           回血上限100
```

控制台输入上述命令时都在前面加 `say `。设置立即保存并重载，换图后继续保留。

## 配置文件

首次启动生成 `left4dead2/ems/recovery_boost/settings.txt`，每行 `键=数值`。手工修改后输入 `!rbreload` 或重开地图。

| 键 | 默认 | 允许范围 |
| --- | --- | --- |
| enabled | 1 | 0或1 |
| regen_amount | 1 | 0–100整数，每秒实血量 |
| regen_cap | 100 | 1–100整数 |
| medkit_seconds | 2.0 | 0.2–30秒 |
| defib_seconds | 1.0 | 0.2–30秒 |
| defib_return_seconds | 0.5 | 0–10秒 |
| revive_seconds | 1.0 | 0.2–30秒 |

缺失或非法设置使用默认值。专用服务器需在服务器端安装VPK；本版管理聊天命令只授权本地房主，专服可直接修改配置并重开地图。加入官方或他人服务器时，仅本机安装无效。

## 兼容与关闭

只在普通战役 `coop` 和写实 `realism` 启用。启用时记录原有动作时长，关闭、回合结束和换图时尝试恢复；若地图或其他Mod后来改了同一变量，本包不会在关闭时覆盖那次修改。

与Bot TeamPlus默认配置合用时，游戏的1秒扶人通常会先于Bot插件的2秒快捷扶人完成。如果你要让Bot严格使用本包配置的扶人时间，可在聊天输入 `!btpset revive_seconds 0`，让Bot增强使用游戏原版完成判定。无需此命令也能使用本包默认加速。

`!rboff` 只关闭这个Mod；`!btpoff` 只关闭Bot增强；两者都不关闭独立酸火免伤包。完整卸载本包请退出游戏后移除其VPK并重启。回血已得到的生命值不会倒扣。

其他回血Mod会叠加效果；其他动作加速Mod或自定义地图可能改写相同时长。请用 `!rb` 查看实际变量值。首次测试建议只开启这三个Mod。

## 验证与游戏检查

开发侧已完成：

- 两个脚本的Squirrel 3.2语法检查；游戏版本和引擎扩展不同，不能替代游戏加载。
- 模拟每秒一次回血、卡顿不补发、真人/Bot、生命上限、临时血重叠、倒地/挂边/死亡/感染者排除。
- 模拟四个速度变量应用、重复启动单一计时器、关闭恢复、外部修改保留、缺失变量提示、配置校验和房主权限。
- 使用已公布的游戏事件分发代码验证聊天状态、空白处理、重复注册去重、事件表重建后恢复；模拟三个Mod的聊天及独立开关共存。
- 独立VPK读取器对每个打包文件做CRC和源码逐字节校验。

尚未游戏实测。建议先在本地战役受伤，观察每秒回血；分别测试用包、除颤和扶人，检查物品正常消耗、中断后不会凭空完成。再测试药物临时血、倒地暂停、换图、`!rboff`恢复速度，最后加入第三方地图和其他Mod。

出现问题请保留控制台 `[RecoveryBoost ERROR]`、地图名和其他Mod列表。连续脚本异常会停用本Mod并尝试恢复时长。

## 源码

源码在 `source`；运行 `python build_vpk.py` 重新打包，需要Python3，无第三方打包依赖。源码为GPL-3.0-or-later，许可证随附。

接口参考：[Valve VScript API](https://developer.valvesoftware.com/wiki/Left_4_Dead_2/Scripting/Script_Functions)、[游戏变量列表](https://github.com/Stabbath/L4D2-Decompiled/blob/master/Misc%20Stuff/commoncvars.txt)。没有内置其他作者的游戏Mod或外部运行库。
