local myname, ns = ...
local mod = ns:NewModule("skills")
local core = ns:GetModule("core")

local skills = {
    [PROFESSIONS_COOKING] = {
        [1800] = false, -- "The Outland Gourmet"
        [1779] = false, -- The Northrend Gourmet
        [5473] = false, -- The Cataclysmic Gourmet
        [7327] = false, -- The Pandaren Gourmet
        [1780] = false, -- Second That Emotion
    },
}

function mod:OnLoad()
    if IsAddOnLoaded("Blizzard_TradeSkillUI") then
        self:Hooks()
    else
        self:RegisterEvent("ADDON_LOADED")
    end
end

function mod:ADDON_LOADED(event, addon)
    if addon ~= "Blizzard_TradeSkillUI" then
        return
    end
    self:Hooks()
    self:UnregisterEvent("ADDON_LOADED")
end

function mod:Hooks()
    hooksecurefunc("TradeSkillFrame_Update", function() mod:TradeSkillFrame_Update() end)
end

local icon_cache = {}
local function button_onenter(self)
    local icon = icon_cache[self]
    if not (icon and icon.name and icon:IsVisible()) then
        return
    end
    local skill = GetTradeSkillLine()
    if not (skill and skills[skill]) then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT")
    GameTooltip:AddLine(SUMMARY_ACHIEVEMENT_INCOMPLETE)
    for achievementid, recipes in pairs(skills[skill]) do
        if recipes[icon.name] then
            local _, name = GetAchievementInfo(achievementid)
            GameTooltip:AddLine(name)
        end
    end
    GameTooltip:Show()
end
local function button_onleave(self)
    GameTooltip:Hide()
end
function mod:GetIconForTradeSkillLine(button, name)
    if not button then
        return
    end
    local icon = icon_cache[button]
    if not icon then
        icon = button:CreateTexture()
        icon:SetTexture([[Interface\ACHIEVEMENTFRAME\UI-Achievement-TinyShield]])
        icon:SetWidth(20)
        icon:SetHeight(20)
        icon:SetPoint("LEFT", button, 5, -4)
        icon_cache[button] = icon

        button:HookScript("OnEnter", button_onenter)
        button:HookScript("OnLeave", button_onleave)
    end
    icon.name = name
    icon:Show()
end

function mod:TradeSkillFrame_Update()
    for button, icon in pairs(icon_cache) do
        icon.name = nil
        icon:Hide()
    end

    local skill = GetTradeSkillLine()
    if not (skill and skills[skill]) then
        return
    end

    -- Yes, this bears some resemblance to what TradeSkillFrame_Update does
    local offset = FauxScrollFrame_GetOffset(TradeSkillListScrollFrame)
    local filter = TradeSkillFilterBar:IsShown()
    local num_skills = filter and (TRADE_SKILLS_DISPLAYED - 1) or TRADE_SKILLS_DISPLAYED
    for i=1, num_skills do
        local name, type = GetTradeSkillInfo(i + offset)
        if name and type ~= "header" then
            local achievementid, criteriaid, achievement_done, criteria_done = self:CheckRecipe(skill, name)
            if achievementid then
                if core.db.done_achievements or not achievement_done then
                    if --[[ core.db.done_criteria or --]] not criteria_done then
                        local button = _G["TradeSkillSkill" .. (filter and (i + 1) or i)]
                        self:GetIconForTradeSkillLine(button, name)
                    end
                end
            end
        end
    end
end

function mod:CheckRecipe(skill, name)
    local achievements = skills[skill]
    if not achievements then
        return
    end
    for achievementid, recipes in pairs(achievements) do
        if recipes == false then
            recipes = {}
            for i=1, GetAchievementNumCriteria(achievementid) do
                local desc, _, _, _, _, _, _, _, _, criteriaid = GetAchievementCriteriaInfo(achievementid, i)
                if desc and criteriaid then
                    recipes[desc] = criteriaid
                    achievements[achievementid] = recipes
                end
            end
        end
        if recipes[name] then
            local _, a_name, _, complete = GetAchievementInfo(achievementid)
            local desc, _, done = GetAchievementCriteriaInfoByID(achievementid, recipes[name])
            return achievementid, recipes[name], complete, done
        end
    end
end