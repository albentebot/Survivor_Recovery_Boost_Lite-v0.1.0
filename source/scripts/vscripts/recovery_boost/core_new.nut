// SPDX-License-Identifier: GPL-3.0-or-later
// ============================================================================
// RecoveryBoost Lite —— 简化版《求生之路2》恢复增益 Mod
//
// 这是完整 core.nut 的精简重构：砍掉了配置文件、聊天命令、Convar 恢复、
// 异常熔断、事件定期重注册等功能，保留"能跑起来的最小子集"。
// 想改数值直接改下面 ::RecoveryBoost 里的常量，重新打包 VPK 即可。
//
// 功能一览：
//   1) 每 RegenInterval 秒给所有幸存者回复 RegenAmount 点实血（上限 RegenCap）
//   2) 硬编码加速四个引擎 Convar：急救包 / 除颤读条 / 除颤复活延迟 / 扶人
//
// 仅在 coop（普通战役）和 realism（写实）模式下生效。
// ============================================================================

// 全局命名空间 ::RecoveryBoost，所有成员和方法都挂载在此表上
::RecoveryBoost <- {
    // ---- 运行时状态 ----
    Active = false,      // 是否处于运行状态（Start 后为 true，Stop 后为 false）
    Thinker = null,      // 驱动回血逻辑的脚本实体（info_target），挂载 Think 函数
    NextRegen = 0.0,     // 下次执行回血的时间戳（游戏时间，秒）

    // ---- 核心配置 ----
    // 想改数值？直接改这里，重新打包即可。这里是 Lite 版砍掉配置系统的代价。
    RegenInterval = 3.0,       // 回血间隔（秒）——每 3 秒触发一次 Heal
    RegenAmount = 1,           // 每次回复的实血量（整数）
    RegenCap = 80,             // 回血上限（不会超过玩家引擎原生最大生命值）

    // ---- 四个动作耗时硬编码（秒）----
    MedkitSeconds = 3.0,       // 急救包使用读条（自用 & 治疗队友）
    ReviveSeconds = 3.0        // 扶起倒地队友的读条
};

// ----------------------------------------------------------------------------
// Convar 应用
// ----------------------------------------------------------------------------

// 将四个速度相关的引擎控制台变量硬设为上面常量的值
// Lite 版砍掉了 SavedCvars / 恢复逻辑，Stop 时这些变量**不会被还原**
::RecoveryBoost.ApplySpeeds <- function() {
    Convars.SetValue("first_aid_kit_use_duration", MedkitSeconds);
    Convars.SetValue("survivor_revive_duration", ReviveSeconds);
};

// ----------------------------------------------------------------------------
// 核心回血
// ----------------------------------------------------------------------------

// 给玩家 p 回一次血，无返回值。
// 跳过条件：非幸存者 / 已死 / 濒死 / 倒地 / 挂在边缘
//
// 临时血重叠算法说明：
//   当 buffer > 0 时，先把 min(buffer, amount) 的临时血扣掉，
//   再把 hp 加上 amount。这样可以让"新增的实血"优先挤占临时血的位置，
//   而不是把总血量推到 cap 之上。
//   注意：这里用的是简化版 min(buffer, amount)，
//   完整版算法是 overlap = hp + buffer + amount - cap（再 clamp），
//   两者在 buffer > cap - hp 时结果会有差异，见 README 对照报告。
::RecoveryBoost.Heal <- function(p) {
    if (!p.IsSurvivor() || p.IsDead() || p.IsDying() || p.IsIncapacitated() || p.IsHangingFromLedge()) return;

    local hp = p.GetHealth();
    local buffer = p.GetHealthBuffer(); // 临时血（虚血）：止痛药 / 肾上腺素给予、会随时间衰减
    local cap = RegenCap;
    // 引擎自身的最大生命值若小于配置上限，以下限为准（防止引擎拒绝 SetHealth）
    local engineMax = p.GetMaxHealth();
    if (engineMax > 0 && engineMax < cap) cap = engineMax;

    if (hp <= 0 || hp >= cap) return;

    local amount = RegenAmount;
    if (hp + amount > cap) amount = cap - hp;

    // 如果临时血 > 0，优先扣掉 min(buffer, amount) —— 让实血"替换"临时血
    if (buffer > 0) {
        local overlap = buffer < amount ? buffer : amount; // = min(buffer, amount)
        p.SetHealthBuffer(buffer - overlap);
    }
    p.SetHealth(hp + amount);
};

// ----------------------------------------------------------------------------
// Think 主循环（由 Thinker 实体每 0.1 秒回调一次）
// ----------------------------------------------------------------------------

::RecoveryBoost.Think <- function() {
    if (!Active) return 0.1; // 已停止则每 0.1 秒轮询一次 Active 状态

    local now = Time();
    // 到达回血时机：严格定长 RegenInterval，服务器卡顿不会"补发欠账"
    if (now >= NextRegen) {
        NextRegen = now + RegenInterval;
        local p = null;
        // 遍历所有 player 实体，幸存者和感染者都会进来，但 Heal 内部会筛掉感染者
        while ((p = Entities.FindByClassname(p, "player")) != null) {
            Heal(p);
        }
    }
    return 0.1; // 告诉引擎 0.1 秒后再调我
};

// ----------------------------------------------------------------------------
// 生命周期：Stop / Start
// ----------------------------------------------------------------------------

// 停止 Lite Mod：注销 Thinker 实体。
// 注意：Lite 版**不恢复**四个 Convar —— 应用后就留在那，直到地图切换或服务器重启。
// 完整版会在 Stop 时把值还原为旧值并避免覆盖地图/其他 Mod 的后续修改。
::RecoveryBoost.Stop <- function() {
    Active = false;
    if (Thinker != null && Thinker.IsValid()) {
        Thinker.Kill();
    }
    Thinker = null;
};

// 启动 Lite Mod：清理旧 Thinker → 检查游戏模式 → 应用 Convar → 创建新 Thinker → 开启回血计时
// 仅在 coop / realism 模式下生效，其他模式直接 return 不做任何事
::RecoveryBoost.Start <- function() {
    Stop(); // 清理旧的 Thinker，防止重复启动时残留

    local mode = Director.GetGameMode();
    if (mode != "coop" && mode != "realism") return;

    ApplySpeeds(); // 应用四个速度相关 Convar

    // 创建一个 info_target 脚本实体作为 Think 驱动
    // Lite 版用固定 targetname "recovery_boost_thinker"，完整版用 DoUniqueString 避免命名冲突
    Thinker = SpawnEntityFromTable("info_target", { targetname = "recovery_boost_thinker" });
    if (Thinker != null) {
        Thinker.ValidateScriptScope();
        Thinker.GetScriptScope().Think <- function() { return ::RecoveryBoost.Think(); };
        NextRegen = Time() + RegenInterval;
        Active = true;
        AddThinkToEnt(Thinker, "Think");
        printl("[RecoveryBoost] Loaded.");
    }
};

// ----------------------------------------------------------------------------
// 游戏事件回调（由末尾的 __CollectEventCallbacks 自动注册）
// ----------------------------------------------------------------------------

// 新回合开始 → 启动 Lite Mod（coop/realism 下生效）
::RecoveryBoost.OnGameEvent_round_start <- function(p) {
    Start();
};

// 回合结束 → 停止 Lite Mod
::RecoveryBoost.OnGameEvent_round_end <- function(p) {
    Stop();
};

// 地图切换 → 停止 Lite Mod
::RecoveryBoost.OnGameEvent_map_transition <- function(p) {
    Stop();
};

// 脚本加载完成后，扫描 ::RecoveryBoost 表上所有以 OnGameEvent_ 开头的方法，
// 自动注册为对应游戏事件的监听器。Lite 版只注册这一次，完整版在 Think 里每 2 秒补注册一次防止事件丢失。
__CollectEventCallbacks(::RecoveryBoost, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);