AddCSLuaFile()

local hook = hook
local math = math
local net = net
local player = player
local timer = timer

local AddHook = hook.Add
local PlayerIterator = player.Iterator
local MathRandom = math.random

------------------
-- ROLE CONVARS --
------------------

CreateConVar("ttt_wheelboy_heal_on_massacre", "1")
local wheelboy_massacre_damage_bonus = CreateConVar("ttt_wheelboy_massacre_damage_bonus", "0.5", FCVAR_NONE, "Damage bonus that Wheel Boy has after triggering a massacre (e.g. 0.5 = 50% more damage)", 0, 1)
local wheelboy_activation_timer = CreateConVar("ttt_wheelboy_activation_timer", "30", FCVAR_NONE, "Minimum time in seconds before the wheel boy is revealed", 0, 120)
local wheelboy_activation_timer_max = CreateConVar("ttt_wheelboy_activation_timer_max", "30", FCVAR_NONE, "Maximum time in seconds before the wheel boy is revealed", 0, 120)
local wheelboy_size = CreateConVar("ttt_wheelboy_size", "0.5", FCVAR_NONE, "The size multiplier for the wheel boy to use when they are revealed (e.g. 0.5 = 50% size)", 0, 1)

local wheelboy_announce_text = GetConVar("ttt_wheelboy_announce_text")
local wheelboy_announce_sound = GetConVar("ttt_wheelboy_announce_sound")

----------------
-- ACTIVATION --
----------------

local defaultJumpPower = 160
local wheelboyActive = false
local announceText = false
local announceSound = false

local function ActivateWheelBoy(ply)
    ply:SetNWBool("WheelBoyActive", true)
    ply:PrintMessage(HUD_PRINTTALK, "You have transformed into Wheel Boy!")

    local scale = wheelboy_size:GetFloat()
    ply:SetPlayerScale(scale)
    local jumpPower = defaultJumpPower
    if scale < 1 then
        jumpPower = jumpPower + (-(120 * scale) + 125)
    end
    ply:SetJumpPower(jumpPower)
end

local function StartWheelBoyTimer()
    local wheelboyTimeMin = wheelboy_activation_timer:GetInt()
    local wheelboyTimeMax = wheelboy_activation_timer_max:GetInt()
    if wheelboyTimeMax < wheelboyTimeMin then
        wheelboyTimeMax = wheelboyTimeMin
    end
    local wheelboyTime = MathRandom(wheelboyTimeMin, wheelboyTimeMax)
    SetGlobalFloat("ttt_wheelboy_activate", CurTime() + wheelboyTime)
    for _, v in PlayerIterator() do
        if v:IsWheelBoy() and v:Alive() and not v:IsSpec() then
            timer.Simple(0.1, function()
                v:SetNWInt("WheelBoyNextSpinTime", CurTime() + wheelboyTime)
                v:PrintMessage(HUD_PRINTTALK, "You will transform into Wheel Boy in " .. tostring(wheelboyTime) .. " seconds!")
            end)
        end
    end
    timer.Create("WheelBoyActivate", wheelboyTime, 1, function()
        wheelboyActive = true
        for _, v in PlayerIterator() do
            if v:IsActiveWheelBoy() then
                ActivateWheelBoy(v)
            elseif announceText then
                v:QueueMessage(MSG_PRINTBOTH, "There is " .. ROLE_STRINGS_EXT[ROLE_WHEELBOY] .. ".")
            end
        end

        if announceSound then
            net.Start("TTT_WheelBoyAnnounceSound")
            net.Broadcast()
        end
    end)
end

local function PauseWheelBoyTimer()
    if not timer.Exists("WheelBoyActivate") then return end
    if GetRoundState() ~= ROUND_ACTIVE then return end

    if not player.IsRoleLiving(ROLE_WHEELBOY) then
        timer.Pause("WheelBoyActivate")
    end
end

local function UnPauseWheelBoyTimer()
    timer.UnPause("WheelBoyActivate")

    local remaining = timer.TimeLeft("WheelBoyActivate")
    SetGlobalFloat("ttt_wheelboy_activate", CurTime() + remaining)

    for _, v in PlayerIterator() do
        if v:IsWheelBoy() and v:Alive() and not v:IsSpec() then
            v:SetNWInt("WheelBoyNextSpinTime", CurTime() + remaining)
        end
    end
end

AddHook("TTTPlayerSpawnForRound", "EnhancedWheelBoy_TTTPlayerSpawnForRound", function(ply, deadOnly)
    if ply:IsWheelBoy() then
        if wheelboyActive then
            if not ply:IsRoleActive() then
                ActivateWheelBoy(ply)
            end
        elseif timer.Exists("WheelBoyActivate") then
            UnPauseWheelBoyTimer()
        end
    end
end)

AddHook("TTTPlayerRoleChanged", "EnhancedWheelBoy_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
    if oldRole == ROLE_WHEELBOY then
        ply:SetNWBool("WheelBoyActive", false)
        ply:ResetPlayerScale()
        ply:SetJumpPower(defaultJumpPower)
        PauseWheelBoyTimer()
    elseif newRole == ROLE_WHEELBOY then
        if wheelboyActive then
            ActivateWheelBoy(ply)
        elseif not timer.Exists("WheelBoyActivate") then
            StartWheelBoyTimer()
        else
            UnPauseWheelBoyTimer()
        end
    end
end)

AddHook("PlayerDeath", "EnhancedWheelBoy_PlayerDeath", function(victim, infl, attacker)
    if victim:IsWheelBoy() then
        PauseWheelBoyTimer()
    end
end)

---------------------------
-- MASSACRE DAMAGE BOOST --
---------------------------

AddHook("ScalePlayerDamage", "EnhancedWheelBoy_ScalePlayerDamage", function(ply, hitgroup, dmginfo)
    -- Only apply damage scaling after the round starts
    if GetRoundState() < ROUND_ACTIVE then return end

    local att = dmginfo:GetAttacker()
    -- Wheel Boys deal extra damage when they trigger a massacre
    if not IsPlayer(att) or not att:IsWheelBoy() or not INDEPENDENT_ROLES[ROLE_WHEELBOY] then return end

    local bonus = wheelboy_massacre_damage_bonus:GetFloat()
    dmginfo:ScaleDamage(1 + bonus)
end)

----------------
-- WIN CHECKS --
----------------

AddHook("TTTCheckForWin", "EnhancedWheelBoy_TTTCheckForWin", function(win_blocks)
    if not INDEPENDENT_ROLES[ROLE_WHEELBOY] then return end

    local wheelboy_alive = false
    local other_alive = false
    for _, v in PlayerIterator() do
        if v:IsActive() then
            if v:IsWheelBoy() then
                wheelboy_alive = true
            elseif not v:ShouldActLikeJester() and not ROLE_HAS_PASSIVE_WIN[v:GetRole()] then
                other_alive = true
            end
        end
    end

    if wheelboy_alive and not other_alive then
        return WIN_WHEELBOY
    elseif wheelboy_alive then
        return WIN_NONE
    end
end)

AddHook("TTTPrintResultMessage", "EnhancedWheelBoy_TTTPrintResultMessage", function(type)
    if type == WIN_WHEELBOY then
        LANG.Msg("win_wheelboy", { role = ROLE_STRINGS_PLURAL[WIN_WHEELBOY] })
        ServerLog("Result: " .. ROLE_STRINGS[WIN_WHEELBOY] .. " wins.\n")
        return true
    end
end)

-------------
-- CLEANUP --
-------------

AddHook("TTTEndRound", "EnhancedWheelBoy_TTTEndRound", function()
    timer.Remove("WheelBoyActivate")
    wheelboyActive = false
    wheelboy_announce_text:SetBool(announceText)
    wheelboy_announce_sound:SetBool(announceSound)
end)

AddHook("TTTPrepareRound", "EnhancedWheelBoy_PrepareRound", function()
    INDEPENDENT_ROLES[ROLE_WHEELBOY] = false
    JESTER_ROLES[ROLE_WHEELBOY] = true
    UpdateRoleColours()
    for _, v in PlayerIterator() do
        v:SetNWBool("WheelBoyActive", false)
        v:ResetPlayerScale()
        v:SetJumpPower(defaultJumpPower)
    end
    announceText = wheelboy_announce_text:GetBool()
    wheelboy_announce_text:SetBool(false)
    announceSound = wheelboy_announce_sound:GetBool()
    wheelboy_announce_sound:SetBool(false)
end)