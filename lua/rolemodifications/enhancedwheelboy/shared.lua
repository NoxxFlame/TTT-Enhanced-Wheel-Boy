AddCSLuaFile()

local hook = hook
local math = math
local player = player
local table = table

local AddHook = hook.Add
local MathCeil = math.ceil
local MathRandom = math.random
local PlayerIterator = player.Iterator
local TableAdd = table.Add
local TableHasValue = table.HasValue
local TableInsert = table.insert
local TableRandom = table.Random
local TableShuffle = table.Shuffle

if SERVER then
    util.AddNetworkString("TTT_WheelBoyMassacre")
end

------------------
-- ROLE CONVARS --
------------------

local wheelboy_enhanced_wheel = CreateConVar("ttt_wheelboy_enhanced_wheel", "1", FCVAR_REPLICATED)
local wheelboy_speed_mult = CreateConVar("ttt_wheelboy_speed_mult", "1.2", FCVAR_REPLICATED, "The multiplier to use on the wheel boy's movement speed when they are activated (e.g. 1.2 = 120% normal speed)", 1, 2)
local wheelboy_sprint_recovery = CreateConVar("ttt_wheelboy_sprint_recovery", "0.12", FCVAR_REPLICATED, "The amount of stamina to recover per tick when the wheel boy is activated", 0, 1)


-- Independent ConVars
CreateConVar("ttt_wheelboy_can_see_jesters", "1", FCVAR_REPLICATED)
CreateConVar("ttt_wheelboy_update_scoreboard", "1", FCVAR_REPLICATED)

table.insert(ROLE_CONVARS[ROLE_WHEELBOY], {
    cvar = "ttt_wheelboy_enhanced_wheel",
    type = ROLE_CONVAR_TYPE_BOOL
})
table.insert(ROLE_CONVARS[ROLE_WHEELBOY], {
    cvar = "ttt_wheelboy_heal_on_massacre",
    type = ROLE_CONVAR_TYPE_BOOL
})
table.insert(ROLE_CONVARS[ROLE_WHEELBOY], {
    cvar = "ttt_wheelboy_massacre_damage_bonus",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 2
})
table.insert(ROLE_CONVARS[ROLE_WHEELBOY], {
    cvar = "ttt_wheelboy_activation_timer",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 2
})
table.insert(ROLE_CONVARS[ROLE_WHEELBOY], {
    cvar = "ttt_wheelboy_activation_timer_max",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 2
})
table.insert(ROLE_CONVARS[ROLE_WHEELBOY], {
    cvar = "ttt_wheelboy_size",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 2
})
table.insert(ROLE_CONVARS[ROLE_WHEELBOY], {
    cvar = "ttt_wheelboy_speed_mult",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 2
})
table.insert(ROLE_CONVARS[ROLE_WHEELBOY], {
    cvar = "ttt_wheelboy_sprint_recovery",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 2
})

--------------------
-- ENHANCED WHEEL --
--------------------

local oldEffects
AddHook("InitPostEntity", "EnhancedWheelBoy_InitPostEntity", function()
    oldEffects = WHEELBOY.Effects
end)

AddHook("TTTUpdateRoleState", "EnhancedWheelBoy_TTTUpdateRoleState", function()
    ROLE_IS_ACTIVE[ROLE_WHEELBOY] = function(ply)
        return ply:GetNWBool("WheelBoyActive", false)
    end

    ROLE_SHOULD_REVEAL_ROLE_WHEN_ACTIVE[ROLE_WHEELBOY] = function()
        return true
    end

    if wheelboy_enhanced_wheel:GetBool() then
        WHEELBOY.Effects = {
            {
                name = "Kill a detective",
                start = function(p, this)
                    local detectives = {}
                    for _, v in PlayerIterator() do
                        if not IsPlayer(v) then continue end

                        if v:IsActiveDetectiveLike() then
                            TableInsert(detectives, v)
                        end
                    end
                    if #detectives > 0 then
                        local chosen = detectives[MathRandom(1, #detectives)]
                        chosen:Kill()
                        for _, v in PlayerIterator() do
                            if not IsPlayer(v) then continue end

                            v:QueueMessage(MSG_PRINTTALK, chosen:Nick() .. " has died")
                        end
                    end
                end,
                finish = function() end
            },
            {
                name = "30% faster",
                start = function(p, this)
                    local slowTimes = 0
                    for _, effect in ipairs(WHEELBOY.Effects) do
                        if effect.name == "30% slower" then
                            if effect.times ~= nil then
                                slowTimes = effect.times
                            end
                            break
                        end
                    end
                    local timeMult = this.times - slowTimes
                    if timeMult < -3 then
                        timeMult = -3
                    end
                    game.SetTimeScale(1 + (0.30 * timeMult))
                end,
                finish = function()
                    game.SetTimeScale(1)
                end
            },
            {
                name = "Shuffle weapons",
                start = function(p, this)
                    local targets = {}
                    local weaponLists = {}
                    for _, v in PlayerIterator() do
                        if not IsPlayer(v) then continue end

                        if v:IsActive() then
                            TableInsert(targets, v)
                            TableInsert(weaponLists, v:GetWeapons())
                        end
                    end
                    TableShuffle(targets)

                    for k, v in ipairs(targets) do
                        local weaponList = weaponLists[k]
                        local roleWeapons = {}
                        for _, w in ipairs(v:GetWeapons()) do
                            if w.Category == WEAPON_CATEGORY_ROLE or WEPS.GetClass(w) == "weapon_ttt_wtester" then
                                TableInsert(roleWeapons, w)
                            end
                        end

                        v:StripWeapons()
                        v:SetFOV(0, 0.2)
                        for _, w in ipairs(roleWeapons) do
                            local roleWeapon = v:Give(WEPS.GetClass(w))
                            if TTTPAP and w.PAPUpgrade then
                                TTTPAP:ApplyUpgrade(roleWeapon, w.PAPUpgrade)
                            end
                        end

                        for _, w in ipairs(weaponList) do
                            local wepClass = WEPS.GetClass(w)
                            if w.Category ~= WEAPON_CATEGORY_ROLE and wepClass ~= "weapon_ttt_wtester" then
                                local weapon = v:Give(wepClass)
                                if TTTPAP and w.PAPUpgrade then
                                    TTTPAP:ApplyUpgrade(weapon, w.PAPUpgrade)
                                end
                            end
                        end

                        if not v:HasWeapon("weapon_ttt_unarmed") then
                            v:Give("weapon_ttt_unarmed")
                        end
                        if not v:HasWeapon("weapon_zm_carry") then
                            v:Give("weapon_zm_carry")
                        end
                        if not v:HasWeapon("weapon_zm_improvised") then
                            v:Give("weapon_zm_improvised")
                        end
                    end
                end,
                finish = function() end
            },
            {
                name = "Revive a player",
                start = function(p, this)
                    local dead = {}
                    for _, v in PlayerIterator() do
                        if not IsPlayer(v) then continue end

                        if not v:IsActive() and v:GetRole() ~= ROLE_NONE then
                            TableInsert(dead, v)
                        end
                    end
                    if #dead > 0 then
                        local chosen = dead[MathRandom(1, #dead)]
                        chosen:SpawnForRound(true)

                        local body
                        for _, ent in pairs(ents.FindByClass("prop_ragdoll")) do
                            if (ent.sid64 == chosen:SteamID64() or ent.sid == chosen:SteamID()) and IsValid(ent) then
                                body = ent
                            end
                        end

                        if body then
                            local credits = CORPSE.GetCredits(body, 0) or 0
                            chosen:SetCredits(credits)
                            SafeRemoveEntity(body)
                        end

                        for _, v in PlayerIterator() do
                            if not IsPlayer(v) then continue end

                            v:QueueMessage(MSG_PRINTTALK, chosen:Nick() .. " has been revived")
                        end
                    end
                end,
                finish = function() end
            },
            {
                name = "Kill an innocent",
                start = function(p, this)
                    local innocents = {}
                    for _, v in PlayerIterator() do
                        if not IsPlayer(v) then continue end

                        if v:IsActiveInnocentTeam() then
                            TableInsert(innocents, v)
                        end
                    end
                    if #innocents > 0 then
                        local chosen = innocents[MathRandom(1, #innocents)]
                        chosen:Kill()
                        for _, v in PlayerIterator() do
                            if not IsPlayer(v) then continue end

                            v:QueueMessage(MSG_PRINTTALK, chosen:Nick() .. " has died")
                        end
                    end
                end,
                finish = function() end
            },
            {
                name = "Add a Jester",
                start = function(p, this)
                    local detectives = {}
                    local innocents = {}
                    local traitors = {}
                    local others = {}
                    for _, v in PlayerIterator() do
                        if not IsPlayer(v) then continue end

                        if v:IsActive() then
                            if v:IsDetectiveLike() then
                                TableInsert(detectives, v)
                            elseif v:IsInnocentTeam() then
                                TableInsert(innocents, v)
                            elseif v:IsTraitorTeam() then
                                TableInsert(traitors, v)
                            elseif not v:IsWheelBoy() then
                                TableInsert(others, v)
                            end
                        end
                    end

                    local chosen
                    if #others > 0 then
                        chosen = others[MathRandom(1, #others)]
                    elseif #innocents > 0 then
                        chosen = innocents[MathRandom(1, #innocents)]
                    elseif #traitors > 1 then -- Check traitors twice to prevent the round from ending by removing all traitors
                        chosen = traitors[MathRandom(1, #traitors)]
                    elseif #detectives > 0 then
                        chosen = detectives[MathRandom(1, #detectives)]
                    elseif #traitors > 0 then
                        chosen = traitors[MathRandom(1, #traitors)]
                    end

                    if chosen then
                        chosen:SetRole(ROLE_JESTER)
                        chosen:QueueMessage(MSG_PRINTBOTH, "You have been turned into a Jester by Wheel Boy")
                        SendFullStateUpdate()
                    end
                end,
                finish = function() end
            },
            {
                name = "Random player explodes",
                start = function(p, this)
                    local innocents = {}
                    local traitors = {}
                    local choices = {}
                    for _, v in PlayerIterator() do
                        if not IsPlayer(v) then continue end

                        if v:IsActive() then
                            if v:IsInnocentTeam() then
                                TableInsert(innocents, v)
                            elseif v:IsTraitorTeam() then
                                TableInsert(traitors, v)
                            elseif not v:IsWheelBoy() then
                                TableInsert(choices, v)
                            end
                        end
                    end

                    if #innocents > 1 and #traitors > 1 then  -- Try to prevent the round from ending early by exploding all members of one team
                        TableAdd(choices, innocents)
                        TableAdd(choices, traitors)
                    elseif #traitors > 1 then
                        TableAdd(choices, traitors)
                    elseif #innocents > 1 then
                        TableAdd(choices, innocents)
                    else
                        TableAdd(choices, innocents)
                        TableAdd(choices, traitors)
                    end

                    if #choices > 0 then
                        local chosen = choices[MathRandom(1, #choices)]
                        chosen:EmitSound(Sound("ambient/explosions/explode_4.wav"))
                        util.BlastDamage(chosen, chosen, chosen:GetPos(), 300, 10000)

                        local effectdata = EffectData()
                        effectdata:SetStart(chosen:GetPos() + Vector(0,0,10))
                        effectdata:SetOrigin(chosen:GetPos() + Vector(0,0,10))
                        effectdata:SetScale(1)
                        util.Effect("HelicopterMegaBomb", effectdata)

                        for _, v in PlayerIterator() do
                            if not IsPlayer(v) then continue end

                            v:QueueMessage(MSG_PRINTTALK, chosen:Nick() .. " has exploded")
                        end
                    end
                end,
                finish = function() end
            },
            {
                name = "Random health",
                start = function(p, this)
                    for _, v in PlayerIterator() do
                        if not IsPlayer(v) then continue end

                        if v:IsActive() then
                            local maxHealth = v:GetMaxHealth()
                            if v:IsWheelBoy() then
                                v:SetHealth(MathRandom(MathCeil((maxHealth / 3) * 2), maxHealth)) -- Try to make things a bit more favourable for Wheel Boy
                            else
                                v:SetHealth(MathRandom(1, maxHealth))
                            end
                        end
                    end
                end,
                finish = function() end
            },
            {
                name = "30% slower",
                start = function(p, this)
                    local fastTimes = 0
                    for _, effect in ipairs(WHEELBOY.Effects) do
                        if effect.name == "30% faster" then
                            if effect.times ~= nil then
                                fastTimes = effect.times
                            end
                            break
                        end
                    end
                    local timeMult = fastTimes - this.times
                    if timeMult < -3 then
                        timeMult = -3
                    end
                    game.SetTimeScale(1 + (0.30 * timeMult))
                end,
                finish = function()
                    game.SetTimeScale(1)
                end
            },
            {
                name = "Kill a traitor",
                start = function(p, this)
                    local traitors = {}
                    for _, v in PlayerIterator() do
                        if not IsPlayer(v) then continue end

                        if v:IsActiveTraitorTeam() then
                            TableInsert(traitors, v)
                        end
                    end
                    if #traitors > 0 then
                        local chosen = traitors[MathRandom(1, #traitors)]
                        chosen:Kill()
                        for _, v in PlayerIterator() do
                            if not IsPlayer(v) then continue end

                            v:QueueMessage(MSG_PRINTTALK, chosen:Nick() .. " has died")
                        end
                    end
                end,
                finish = function() end
            },
            {
                name = "Shuffle positions",
                start = function(p, this)
                    local targets = {}
                    local positions = {}
                    for _, v in PlayerIterator() do
                        if not IsPlayer(v) then continue end

                        if v:IsActive() then
                            TableInsert(targets, v)
                            TableInsert(positions, {
                                ["pos"] = v:GetPos(),
                                ["angle"] = v:EyeAngles(),
                            })
                        end
                    end
                    TableShuffle(targets)

                    for k, v in ipairs(targets) do
                        local position = positions[k]
                        v:SetPos(position["pos"])
                        v:SetEyeAngles(position["angle"])
                    end
                end,
                finish = function() end
            },
            {
                name = "Free shop item",
                start = function(p, this)
                    local shopItems = {}
                    for role = ROLE_NONE, ROLE_MAX do
                        if SHOP_ROLES[role] and util.CanRoleSpawn(role) then
                            for _, w in ipairs(weapons.GetList()) do
                                if w and not w.AutoSpawnable and w.CanBuy and #w.CanBuy > 0 and TableHasValue(w.CanBuy, role) then
                                    shopItems[w.ClassName] = w
                                end
                            end
                        end
                    end

                    if #shopItems > 0 then
                        for _, v in PlayerIterator() do
                            if not IsPlayer(v) then continue end

                            if v:IsActive() then
                                local item = TableRandom(shopItems)
                                v:Give(item.ClassName)
                            end
                        end
                    end
                end,
                finish = function() end
            },
            {
                name = "Two free spins",
                start = function(p, this)
                    local wheelTime = GetConVar("ttt_wheelboy_wheel_time"):GetInt()
                    local waitTime = GetConVar("ttt_wheelboy_wheel_end_wait_time"):GetInt()

                    if p.WheelBoyFreeSpins == 0 then
                        p.WheelBoyFreeSpins = 2
                        timer.Create("TTTWheelBoyFreeSpin", 0.2, 0, function()
                            if p.WheelBoyFreeSpins == 0 then
                                timer.Stop("TTTWheelBoyFreeSpin")
                            end

                            timer.Adjust("TTTWheelBoyFreeSpin", wheelTime + waitTime + 0.2)
                            net.Start("TTT_WheelBoySpinWheel")
                            net.WriteFloat(MathRandom())
                            if GetConVar("ttt_wheelboy_reveal_spin"):GetBool() then
                                net.Broadcast()
                            else
                                net.Send(p)
                            end

                            if p.WheelBoySpinCount ~= nil then
                                p:SetProperty("WheelBoySpinCount", p.WheelBoySpinCount - 1)
                            end

                            p.WheelBoyFreeSpins = p.WheelBoyFreeSpins - 1
                            if p.WheelBoyFreeSpins == 0 then
                                timer.Stop("TTTWheelBoyFreeSpin")
                            end
                        end)
                    else
                        p.WheelBoyFreeSpins = p.WheelBoyFreeSpins + 2
                    end

                    local nextSpinTime = p:GetNWInt("WheelBoyNextSpinTime", nil)
                    p:SetNWInt("WheelBoyNextSpinTime", nextSpinTime + ((wheelTime + waitTime + 0.2) * 2))
                end,
                finish = function()
                    for _, v in PlayerIterator() do
                        v.WheelBoyFreeSpins = 0
                    end
                    timer.Stop("TTTWheelBoyFreeSpin")
                end
            },
            {
                name = "Wheel Boy massacre",
                start = function(p, this)
                    INDEPENDENT_ROLES[ROLE_WHEELBOY] = true
                    JESTER_ROLES[ROLE_WHEELBOY] = false
                    UpdateRoleColours()

                    net.Start("TTT_WheelBoyMassacre")
                    net.Broadcast()

                    p.WheelBoyFreeSpins = 0
                    p:SetProperty("WheelBoySpinCount", 0)
                    p:StripWeapon("weapon_whl_spinner")

                    net.Start("TTT_UpdateWheelBoyWins")
                    net.WriteBool(false)
                    net.Broadcast()

                    if GetConVar("ttt_wheelboy_heal_on_massacre"):GetBool() then
                        p:SetHealth(p:GetMaxHealth())
                    end

                    for _, v in PlayerIterator() do
                        if not v:IsActive() then continue end
                        if v:IsWheelBoy() then
                            v:QueueMessage(MSG_PRINTBOTH, "KILL THEM ALL!")
                        else
                            v:QueueMessage(MSG_PRINTBOTH, "Kill Wheel Boy before he kills you!")
                        end
                    end
                end,
                finish = function() end
            }
        }
        WHEELBOY.FreeSpins = 0
    else
        WHEELBOY.Effects = oldEffects
    end
end)

------------------------
-- SPRINT MULTIPLIERS --
------------------------

AddHook("TTTSprintStaminaRecovery", "EnhancedWheelBoy_TTTSprintStaminaRecovery", function(ply, recovery)
    if IsPlayer(ply) and ply:IsActiveWheelBoy() and ply:IsRoleActive() then
        return wheelboy_sprint_recovery:GetFloat()
    end
end)

AddHook("TTTSpeedMultiplier", "EnhancedWheelBoy_TTTSpeedMultiplier", function(ply, mults)
    if IsPlayer(ply) and ply:IsActiveWheelBoy() and ply:IsRoleActive() then
        TableInsert(mults, wheelboy_speed_mult:GetFloat())
    end
end)