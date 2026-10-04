// SPDX-License-Identifier: GPL-3.0-or-later
// RecoveryBoost Lite —— 精简版生存者恢复增益

::RecoveryBoost <- {
    Active = false,
    Thinker = null,
    NextRegen = 0.0,

    // 核心配置（想改数值？直接改这里，重新打包即可）
    RegenInterval = 3.0,    // 回血间隔
    RegenAmount = 1,        // 每次回复实血量
    RegenCap = 80,          // 回复上限

    MedkitSeconds = 3.0,
    DefibSeconds = 1.0,
    DefibReturnSeconds = 0.5,
    ReviveSeconds = 3.0
};

// 应用动作速度参数
::RecoveryBoost.ApplySpeeds <- function() {
    Convars.SetValue("first_aid_kit_use_duration", MedkitSeconds);
    Convars.SetValue("defibrillator_use_duration", DefibSeconds);
    Convars.SetValue("defibrillator_return_to_life_time", DefibReturnSeconds);
    Convars.SetValue("survivor_revive_duration", ReviveSeconds);
};

// 给玩家回血（优先把虚血转为实血）
::RecoveryBoost.Heal <- function(p) {
    if (!p.IsSurvivor() || p.IsDead() || p.IsDying() || p.IsIncapacitated() || p.IsHangingFromLedge()) return;

    local hp = p.GetHealth();
    local buffer = p.GetHealthBuffer(); // 虚血
    local cap = RegenCap;
    local engineMax = p.GetMaxHealth();
    if (engineMax > 0 && engineMax < cap) cap = engineMax;

    if (hp <= 0 || hp >= cap) return;

    local amount = RegenAmount;
    if (hp + amount > cap) amount = cap - hp;

    // 如果虚血大于0，优先扣除虚血（将虚血转化为实血）
    if (buffer > 0) {
        local overlap = buffer < amount ? buffer : amount;
        p.SetHealthBuffer(buffer - overlap);
    }
    p.SetHealth(hp + amount);
};

// Think 主循环（每3秒执行一次）
::RecoveryBoost.Think <- function() {
    if (!Active) return 0.1;

    local now = Time();
    if (now >= NextRegen) {
        NextRegen = now + RegenInterval;
        local p = null;
        while ((p = Entities.FindByClassname(p, "player")) != null) {
            Heal(p);
        }
    }
    return 0.1;
};

// 停止与启动
::RecoveryBoost.Stop <- function() {
    Active = false;
    if (Thinker != null && Thinker.IsValid()) {
        Thinker.Kill();
    }
    Thinker = null;
};

::RecoveryBoost.Start <- function() {
    Stop(); // 清理旧的 Thinker

    local mode = Director.GetGameMode();
    if (mode != "coop" && mode != "realism") return;

    ApplySpeeds(); // 应用速度

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

// 游戏事件监听
::RecoveryBoost.OnGameEvent_round_start <- function(p) {
    Start();
};

::RecoveryBoost.OnGameEvent_round_end <- function(p) {
    Stop();
};

::RecoveryBoost.OnGameEvent_map_transition <- function(p) {
    Stop();
};

// 注册事件
__CollectEventCallbacks(::RecoveryBoost, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);