// SPDX-License-Identifier: GPL-3.0-or-later
::RecoveryBoost <- {
    Version="0.1.0", Active=false, Thinker=null, NextRegen=0.0,
    NextEvents=0.0, AnnounceAt=0.0, Announced=false, Errors=0,
    SavedCvars={}, Missing=[], Healed=0,
    Defaults={enabled=1,regen_amount=1,regen_cap=100,medkit_seconds=2.0,
        defib_seconds=1.0,defib_return_seconds=0.5,revive_seconds=1.0},
    Settings={},
    Limits={enabled=[0,1],regen_amount=[0,100],regen_cap=[1,100],
        medkit_seconds=[0.2,30],defib_seconds=[0.2,30],
        defib_return_seconds=[0,10],revive_seconds=[0.2,30]},
    SpeedCvars={first_aid_kit_use_duration="medkit_seconds",
        defibrillator_use_duration="defib_seconds",
        defibrillator_return_to_life_time="defib_return_seconds",
        survivor_revive_duration="revive_seconds"}
};
::RecoveryBoost.Valid <- function(e) {return e!=null && e.IsValid();};
::RecoveryBoost.Survivor <- function(p) {
    return Valid(p) && p.GetClassname()=="player" && p.IsSurvivor();
};
::RecoveryBoost.Note <- function(p,s) {ClientPrint(p,3,"\x04[RecoveryBoost]\x01 "+s);};
::RecoveryBoost.EnsureEvents <- function() {
    __CollectEventCallbacks(::RecoveryBoost,"OnGameEvent_","GameEventCallbacks",RegisterScriptGameEventListener);
};
::RecoveryBoost.IntegerSetting <- function(k) {
    return k=="enabled" || k=="regen_amount" || k=="regen_cap";
};
::RecoveryBoost.ParseSetting <- function(k,text) {
    if(!(k in Limits)) throw "unknown setting";
    local v=text.tofloat(),r=Limits[k];
    if(!(v>=r[0] && v<=r[1])) throw "out of range";
    if(IntegerSetting(k)) {
        if(v!=v.tointeger()) throw "integer required";
        return v.tointeger();
    }
    return v;
};
::RecoveryBoost.SaveSettings <- function() {
    local text="# Recovery Boost: key=value. Chat !rbreload after editing.\n";
    foreach(k,v in Settings) text+=k+"="+v+"\n";
    StringToFile("recovery_boost/settings.txt",text);
};
::RecoveryBoost.LoadSettings <- function() {
    Settings=clone Defaults;
    local text=FileToString("recovery_boost/settings.txt");
    if(text==null) {SaveSettings();return;}
    foreach(line in split(text,"\n")) {
        line=strip(line);if(!line.len() || line.slice(0,1)=="#") continue;
        local parts=split(line,"=");if(parts.len()!=2) continue;
        local k=strip(parts[0]);if(!(k in Settings)) continue;
        try {Settings[k]=ParseSetting(k,strip(parts[1]));}
        catch(err) {printl("[RecoveryBoost] Invalid setting: "+line);}
    }
};
::RecoveryBoost.SameValue <- function(a,b) {
    if(a==null || b==null) return a==b;
    try {return fabs(a.tofloat()-b.tofloat())<0.0001;} catch(err) {return a==b;}
};
::RecoveryBoost.ApplySpeeds <- function() {
    Missing.clear();
    foreach(name,k in SpeedCvars) {
        local old=Convars.GetStr(name);
        if(old==null) {Missing.append(name);continue;}
        // Record the actual normalized value returned by the engine.
        local record={old=old,applied=null};SavedCvars[name] <- record;
        Convars.SetValue(name,Settings[k]);record.applied=Convars.GetStr(name);
        if(!SameValue(record.applied,Settings[k].tostring())) {
            Missing.append(name);printl("[RecoveryBoost WARNING] Unable to apply "+name);
        }
    }
};
::RecoveryBoost.Heal <- function(p) {
    if(!Survivor(p) || p.IsDead() || p.IsDying() || p.IsIncapacitated() || p.IsHangingFromLedge()) return 0;
    local hp=p.GetHealth(),cap=Settings.regen_cap;
    local engineMax=p.GetMaxHealth();if(engineMax>0 && engineMax<cap) cap=engineMax;
    if(hp<=0 || hp>=cap || Settings.regen_amount<=0) return 0;
    local amount=Settings.regen_amount;if(hp+amount>cap) amount=cap-hp;
    local buffer=p.GetHealthBuffer();if(buffer<0.0) buffer=0.0;
    // Exchange only newly-overlapping temp HP: don't refresh pills/adrenaline
    // every tick and don't add effective HP past the normal cap.
    local overlap=hp+buffer+amount-cap;
    if(overlap>amount) overlap=amount;
    if(overlap>0.0) p.SetHealthBuffer(buffer-overlap);
    p.SetHealth(hp+amount);return amount;
};
::RecoveryBoost.Think <- function() {
    if(!Active) return 0.1;
    try {
        local now=Time();
        if(now>=NextEvents) {EnsureEvents();NextEvents=now+2.0;}
        if(now>=NextRegen) {
            // No catch-up burst after a server hitch or a round transition.
            NextRegen=now+1.0;
            local p=null;
            while((p=Entities.FindByClassname(p,"player"))!=null) Healed+=Heal(p);
        }
        if(!Announced && now>=AnnounceAt) {
            local p=null;
            while((p=Entities.FindByClassname(p,"player"))!=null)
                if(Survivor(p) && !IsPlayerABot(p)) {
                    Note(null,"0.1.0 已加载：每秒回血、快速打包/除颤/扶人。聊天 !rb 查看。");
                    Announced=true;break;
                }
        }
    } catch(err) {
        Errors++;printl("[RecoveryBoost ERROR] "+err);
        if(Errors>=3) {Stop();Note(null,"脚本累计异常，已停止。请保留控制台报错。");}
    }
    return 0.1;
};
::RecoveryBoost.Stop <- function() {
    Active=false;
    if(Valid(Thinker)) {AddThinkToEnt(Thinker,null);Thinker.Kill();}
    Thinker=null;
    foreach(name,record in SavedCvars) {
        // Don't overwrite a value subsequently changed by the map/another mod.
        if(record.applied!=null && SameValue(Convars.GetStr(name),record.applied))
            Convars.SetValue(name,record.old);
    }
    SavedCvars.clear();
};
::RecoveryBoost.Start <- function() {
    Stop();EnsureEvents();LoadSettings();Errors=0;Healed=0;Missing.clear();
    local mode=Director.GetGameMode();
    if(!Settings.enabled || (mode!="coop" && mode!="realism")) return;
    // Create a single thinker before touching server variables.
    Thinker=SpawnEntityFromTable("info_target",{targetname=DoUniqueString("recovery_boost_thinker")});
    if(!Valid(Thinker)) {printl("[RecoveryBoost ERROR] Unable to create thinker");return;}
    try {
        Thinker.ValidateScriptScope();
        Thinker.GetScriptScope().RecoveryBoostThink <- function() {return ::RecoveryBoost.Think();};
        ApplySpeeds();NextRegen=Time()+1.0;NextEvents=0.0;
        Announced=false;AnnounceAt=Time()+1.0;
        Active=true;AddThinkToEnt(Thinker,"RecoveryBoostThink");
        printl("[RecoveryBoost 0.1.0] loaded; chat !rb; console say !rb");
    } catch(err) {Stop();printl("[RecoveryBoost ERROR] Startup: "+err);}
};
::RecoveryBoost.Status <- function(p=null) {
    Note(p,"MOD "+Version+" / "+(Active?"运行中":"已停用")+" / 每秒 "+Settings.regen_amount+" 点实血 / 上限 "+Settings.regen_cap);
    Note(p,"当前打包 "+Convars.GetStr("first_aid_kit_use_duration")+" 秒 / 除颤读条 "+Convars.GetStr("defibrillator_use_duration")+" 秒 / 复活延迟 "+Convars.GetStr("defibrillator_return_to_life_time")+" 秒 / 扶人 "+Convars.GetStr("survivor_revive_duration")+" 秒");
    if(Missing.len()) Note(p,"部分速度变量不可用，请查看控制台。");
};
::RecoveryBoost.FindSpeaker <- function(id) {
    try {id=id.tointeger();} catch(err) {return null;}
    local p=null;
    while((p=Entities.FindByClassname(p,"player"))!=null)
        if(Valid(p) && p.GetPlayerUserId()==id) return p;
    return null;
};
::RecoveryBoost.Command <- function(p,text) {
    local words=[];
    foreach(word in split(strip(text).tolower()," \t\r\n")) if(word.len()) words.append(word);
    if(!words.len()) return;
    local cmd=words[0];
    if(cmd=="!rb") {Status(p);return;}
    if(cmd!="!rbon" && cmd!="!rboff" && cmd!="!rbreload" && cmd!="!rbset") return;
    if(p!=GetListenServerHost()) {Note(p,"这个命令仅本地房主可用。");return;}
    if(cmd=="!rbon" || cmd=="!rboff") {
        Settings.enabled=cmd=="!rbon"?1:0;SaveSettings();Start();Status(p);return;
    }
    if(cmd=="!rbreload") {Start();Status(p);return;}
    if(words.len()!=3) {Note(p,"用法：!rbset regen_amount 2，或 medkit_seconds / defib_seconds / defib_return_seconds / revive_seconds / regen_cap / enabled");return;}
    local value=null;
    try {value=ParseSetting(words[1],words[2]);}
    catch(err) {Note(p,"无效设置或数值超出范围。回血量和上限使用整数。");return;}
    Settings[words[1]]=value;SaveSettings();Start();Status(p);
};
::RecoveryBoost.OnGameEvent_player_say <- function(p) {
    if(!("userid" in p) || !("text" in p)) return;
    local speaker=FindSpeaker(p.userid);if(speaker==null) return;
    try {Command(speaker,p.text);}
    catch(err) {printl("[RecoveryBoost ERROR] Chat: "+err);Note(speaker,"命令执行异常，请查看控制台。");}
};
::RecoveryBoost.OnGameEvent_round_start <- function(p) {Start();};
::RecoveryBoost.OnGameEvent_round_end <- function(p) {Stop();};
::RecoveryBoost.OnGameEvent_map_transition <- function(p) {Stop();};
::RecoveryBoost.EnsureEvents();
