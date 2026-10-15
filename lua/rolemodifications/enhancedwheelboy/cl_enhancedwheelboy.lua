local hook = hook
local player = player

local AddHook = hook.Add
local RemoveHook = hook.Remove
local PlayerIterator = player.Iterator

local client

------------------
-- TRANSLATIONS --
------------------

hook.Add("Initialize", "EnhancedWheelBoy_Translations_Initialize", function()
    LANG.AddToLanguage("english", "win_wheelboy", "The {role} has massacred you all!")
    LANG.AddToLanguage("english", "hilite_win_role_singular_no_the", "{role} WINS")
end)

----------------------
-- MASSACRE OVERLAY --
----------------------

local massacreSound

net.Receive("TTT_WheelBoyMassacre", function()
    INDEPENDENT_ROLES[ROLE_WHEELBOY] = true
    JESTER_ROLES[ROLE_WHEELBOY] = false
    UpdateRoleColours()

    sound.PlayFile("sound/whl/massacre.wav", "noplay", function(station, errCode, errStr)
        if IsValid(station) then
            massacreSound = station
            massacreSound:Play()
        else
            print("Error playing Wheel Boy massacre sound!", errCode, errStr)
        end
    end)
end)

hook.Add("TTTEndRound", "EnhancedWheelBoy_TTTEndRound", function()
    if IsValid(massacreSound) then
        massacreSound:Stop()
        massacreSound = nil
    end
end)

local oldOverlay = Material("wheelboy/wheel_overlay_old")
local newOverlay = Material("wheelboy/wheel_overlay_new")

AddHook("HUDPaint", "EnhancedWheelBoy_HUDPaint", function()
    if not IsValid(client) then client = LocalPlayer() end

    if not INDEPENDENT_ROLES[ROLE_WHEELBOY] then
        if IsValid(massacreSound) then
            massacreSound:Stop()
            massacreSound = nil
        end
        return
    end

    local wheelBoyActive = false
    for _, v in PlayerIterator() do
        if v:IsActiveWheelBoy() then
            wheelBoyActive = true
            break
        end
    end
    if not wheelBoyActive then
        if IsValid(massacreSound) then
            massacreSound:Stop()
            massacreSound = nil
        end
        return
    end

    surface.SetDrawColor(255, 255, 255, 255)
    if GetConVar("ttt_wheelboy_old_wheel_design"):GetBool() then
        surface.SetMaterial(oldOverlay)
    else
        surface.SetMaterial(newOverlay)
    end
    surface.DrawTexturedRect(0, (ScrW() - ScrH()) / -2, ScrW(), ScrW())
end)

------------------
-- HIGHLIGHTING --
------------------

local wheelboy_can_see_jesters = GetConVar("ttt_wheelboy_can_see_jesters")

local vision_enabled = false
local can_see_jesters = false

local function EnableWheelBoyHighlights()
    AddHook("PreDrawHalos", "EnhancedWheelBoy_Highlight_PreDrawHalos", function()
        OnPlayerHighlightEnabled(client, {ROLE_WHEELBOY}, can_see_jesters, false, false, true)
    end)
end

AddHook("TTTUpdateRoleState", "EnhancedWheelBoy_Highlight_TTTUpdateRoleState", function()
    if not IsPlayer(client) then client = LocalPlayer() end

    can_see_jesters = wheelboy_can_see_jesters:GetBool()

    if vision_enabled then
        RemoveHook("PreDrawHalos", "EnhancedWheelBoy_Highlight_PreDrawHalos")
        vision_enabled = false
    end
end)

AddHook("Think", "EnhancedWheelBoy_Highlight_Think", function()
    if not IsPlayer(client) or not client:Alive() or client:IsSpec() then return end

    if INDEPENDENT_ROLES[ROLE_WHEELBOY] and client:IsWheelBoy() and not client:IsRoleAbilityDisabled() then
        if not vision_enabled then
            EnableWheelBoyHighlights()
            vision_enabled = true
        end
    else
        vision_enabled = false
    end

    if INDEPENDENT_ROLES[ROLE_WHEELBOY] and not vision_enabled then
        RemoveHook("PreDrawHalos", "EnhancedWheelBoy_Highlight_PreDrawHalos")
    end
end)

ROLE_IS_TARGET_HIGHLIGHTED[ROLE_WHEELBOY] = function(ply, target)
    if not ply:IsWheelBoy() then return end
    return INDEPENDENT_ROLES[ROLE_WHEELBOY]
end

----------------
-- WIN EVENTS --
----------------

AddHook("TTTScoringWinTitle", "EnhancedWheelBoy_TTTScoringWinTitle", function(wintype, wintitles, title, secondaryWinRole)
    if wintype == WIN_WHEELBOY then
        return { txt = "hilite_win_role_singular_no_the", params = { role = string.upper(ROLE_STRINGS[ROLE_WHEELBOY]) }, c = ROLE_COLORS[ROLE_WHEELBOY] }
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