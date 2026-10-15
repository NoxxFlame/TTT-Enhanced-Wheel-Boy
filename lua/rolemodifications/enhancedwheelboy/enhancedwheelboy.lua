AddCSLuaFile()

local hook = hook
local player = player

local AddHook = hook.Add
local PlayerIterator = player.Iterator

------------------
-- ROLE CONVARS --
------------------

CreateConVar("ttt_wheelboy_heal_on_massacre", "1")
local wheelboy_massacre_damage_bonus = CreateConVar("ttt_wheelboy_massacre_damage_bonus", "0.5", FCVAR_NONE, "Damage bonus that Wheel Boy has after triggering a massacre (e.g. 0.5 = 50% more damage)", 0, 1)

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

AddHook("TTTPrepareRound", "EnhancedWheelBoy_PrepareRound", function()
    INDEPENDENT_ROLES[ROLE_WHEELBOY] = false
    JESTER_ROLES[ROLE_WHEELBOY] = true
    UpdateRoleColours()
end)