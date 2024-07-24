local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")
local mod = ns:NewModule("compare")
local core = ns:GetModule("core")

mod.defaults = {
    tooltip = true,
}

local hook_tooltips = {
    [GameTooltip] = false,
    -- [ItemRefTooltip] = false,
}

function mod:OnLoad()
    self:InitDB()

    for tooltip in pairs(hook_tooltips) do
        hooksecurefunc(tooltip, "SetHyperlink", self.OnSetHyperlink)
        hooksecurefunc(tooltip, "Hide", self.OnTooltipHide)
    end
end

local player_guid
function mod.OnSetHyperlink(tooltip, link)
    if not link then
        return
    end
    local id, guid = link:match("achievement:(%d+):([^:]+):")
    if not id then
        return
    end
    id = tonumber(id)
    if mod.db.tooltip then
        if not player_guid then
            player_guid = strsub(UnitGUID("player"), 3)
        end
        if id and guid ~= player_guid then
            mod:AddProgressToTooltip(tooltip, id)
        end
    end
    tooltip:Show()
end

function mod:AddProgressToTooltip(tooltip, achievementid)
    local _, name, _, complete, month, day, year, _, _, _, _, _, _, earned_by = GetAchievementInfo(achievementid)
    if not name then
        return
    end
    if hook_tooltips[tooltip] == nil then
        self.Debug("Tried to show comparison for non-hooked tooltip")
        return
    end
    local comparison_tooltip = hook_tooltips[tooltip]
    if not comparison_tooltip then
        comparison_tooltip = CreateFrame("GameTooltip", "HIDTComparisonTooltip", nil, "GameTooltipTemplate")
        comparison_tooltip:AddFontStrings(
            comparison_tooltip:CreateFontString("$parentTextLeft1", nil, "GameTooltipText"),
            comparison_tooltip:CreateFontString("$parentTextRight1", nil, "GameTooltipText")
        )
        comparison_tooltip:SetScale(0.7)
        hook_tooltips[tooltip] = comparison_tooltip
    end
    comparison_tooltip:SetOwner(tooltip, "ANCHOR_NONE")
    comparison_tooltip:SetPoint("TOPLEFT", tooltip, "TOPRIGHT")
    comparison_tooltip:SetHyperlink(GetAchievementLink(achievementid))
    comparison_tooltip:Show()
end

function mod.OnTooltipHide(tooltip)
    if hook_tooltips[tooltip] then
        hook_tooltips[tooltip]:Hide()
    end
end
