local myname, ns = ...
local mod = ns:NewModule("skills")
local core = ns:GetModule("core")

local skills = {
    [185] = { -- Cooking
        [1800] = false, -- "The Outland Gourmet"
        [1779] = false, -- The Northrend Gourmet
        [5473] = false, -- The Cataclysmic Gourmet
        [7327] = false, -- The Pandaren Gourmet
        [9501] = false, -- The Draenor Gourmet
        [1780] = false, -- Second That Emotion
    },
    [2787] = { -- Abominable Stitching
        [14748] = false, -- Wardrobe Makeover
    },
}
hskills = skills

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
    hooksecurefunc(TradeSkillFrame.RecipeList, "RefreshDisplay", function(self) mod:RefreshDisplay(self) end)
    hooksecurefunc(TradeSkillFrame.RecipeList, "update", function(self) mod:RefreshDisplay(self) end)
end

function mod:GetRecipesForOpenSkill()
    local skillLineID, skillLineDisplayName, skillLineRank, skillLineMaxRank, skillLineModifier, parentSkillLineID, parentSkillLineDisplayName = C_TradeSkillUI.GetTradeSkillLine()
    if parentSkillLineID and parentSkillLineID ~= 0 then
        skillLineID = parentSkillLineID
    end
    local recipes = skillLineID and skills[skillLineID] or {}
    return recipes, skillLineID
end

local icon_cache = {}
local function button_onenter(self)
    local icon = icon_cache[self]
    if not (icon and icon.name and icon:IsVisible()) then
        return
    end
    local recipes = mod:GetRecipesForOpenSkill()
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT")
    GameTooltip:AddLine(SUMMARY_ACHIEVEMENT_INCOMPLETE)

    for achievementid, achievementRecipes in pairs(recipes) do
        if achievementRecipes and achievementRecipes[icon.name] then
            local _, name, _, complete = GetAchievementInfo(achievementid)
            if not complete then
                GameTooltip:AddLine(name)
            end
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
        icon = button:CreateTexture(nil, "OVERLAY")
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

function mod:RefreshDisplay(frame)
    for button, icon in pairs(icon_cache) do
        icon.achievementid = nil
        icon:Hide()
    end

    local _, skillID = mod:GetRecipesForOpenSkill()

    -- This is mostly a copy of TradeSkillRecipeListMixin.RefreshDisplay
    local offset = HybridScrollFrame_GetOffset(frame)
    for i, tradeSkillButton in ipairs(frame.buttons) do
        local tradeSkillInfo = frame.dataList[offset + i]
        if tradeSkillInfo and tradeSkillInfo.type == "recipe" then
            local achievementid, criteriaid, achievement_done, criteria_done = self:CheckRecipe(skillID, tradeSkillInfo.name)
            if achievementid and (core.db.done_achievements or not achievement_done) then
                if --[[ core.db.done_criteria or --]] not criteria_done then
                    self:GetIconForTradeSkillLine(tradeSkillButton, tradeSkillInfo.name)
                end
            end
        end
    end
end

local achievements_loaded = false
function mod:LoadAchievements()
    if achievements_loaded then
        return
    end
    for skill, achievements in pairs(skills) do
        for achievementid, recipes in pairs(achievements) do
            recipes = {}
            for i=1, GetAchievementNumCriteria(achievementid) do
                local desc, _, _, _, _, _, _, _, _, criteriaid = GetAchievementCriteriaInfo(achievementid, i)
                if desc and criteriaid then
                    recipes[desc] = criteriaid
                    achievements[achievementid] = recipes
                end
            end
        end
    end
    achievements_loaded = true
end

function mod:CheckRecipe(skillID, name)
    local achievements = skills[skillID]
    if not achievements then
        return
    end
    self:LoadAchievements()
    for achievementid, recipes in pairs(achievements) do
        if recipes and recipes[name] then
            local _, a_name, _, complete = GetAchievementInfo(achievementid)
            local desc, _, done = GetAchievementCriteriaInfoByID(achievementid, recipes[name])
            return achievementid, recipes[name], complete, done
        end
    end
end
