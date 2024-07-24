local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")

HIDT = ns

local core = ns:NewModule("core")

core.defaults = {
    achievements = true,
    done_achievements = true,
    done_criteria = true,
    commendations = true,
    quests = true,
    -- id = false,
}
core.defaultsPC = {}

function core:OnLoad()
    self:InitDB()

    -- So, there's a lovely OnTooltipSetAchievement script which you'd think would be great for this... but there's no way to extract data about achievements from a tooltip. (No GetItem equivalent.)
    hooksecurefunc(GameTooltip, "SetHyperlink", self.OnSetHyperlink)
    hooksecurefunc(ItemRefTooltip, "SetHyperlink", self.OnSetHyperlink)

    if C_AddOns.IsAddOnLoaded("Blizzard_AchievementUI") then
        self:HookAchievementFrame()
    else
        self:RegisterEvent("ADDON_LOADED")
    end
end

function core:ADDON_LOADED(event, addon)
    if addon ~= "Blizzard_AchievementUI" then
        return
    end
    -- self:HookAchievementFrame()
    self:UnregisterEvent("ADDON_LOADED")
end

-- function core:HookAchievementFrame()
--     hooksecurefunc("AchievementButton_DisplayAchievement", function(button, category, achievement, selectionID)
--         if issecure() then return end
--         if not button:IsShown() then return end
--         if button.id_text then
--             button.id_text:Hide()
--         end
--         if not core.db.id then
--             return
--         end
--         -- local id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy = GetAchievementInfo(category, achievement)
--         if not button.id_text then
--             button.id_text = button.icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
--             button.id_text:SetPoint("BOTTOMLEFT", button.icon, "BOTTOMLEFT")
--             button.id_text:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT")
--         end
--         button.id_text:Show()
--         button.id_text:SetText(button.id)
--     end)
-- end

function core.OnSetHyperlink(tooltip, link)
    core.Debug("OnSetHyperlink", tooltip, link, tonumber(link:match("achievement:(%d+)")))
    if not link then
        return
    end
    if core.db.id then
        local id = tonumber(link:match("achievement:(%d+)"))
        if id then
            tooltip:AddDoubleLine("ID", id)
        end
    end
    tooltip:Show()
end
