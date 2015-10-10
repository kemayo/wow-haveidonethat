local myname, ns = ...
local mod = ns:NewModule("search")
local core = ns:GetModule("core")

function mod:OnLoad()
    if IsAddOnLoaded("Blizzard_AchievementUI") then
        self:HookAchievementFrame()
    else
        self:RegisterEvent("ADDON_LOADED")
    end
end

function mod:ADDON_LOADED(event, addon)
    if addon ~= "Blizzard_AchievementUI" then
        return
    end
    self:HookAchievementFrame()
    self:UnregisterEvent("ADDON_LOADED")
end

function mod:HookAchievementFrame()
    local achievements_shown = {}
    local search_name

    local orig_AchievementFrameAchievements_Update = AchievementFrameAchievements_Update
    AchievementFrameAchievements_Update = function(...)
        wipe(achievements_shown)
        orig_AchievementFrameAchievements_Update(...)
    end
    AchievementFrameAchievementsContainer.update = AchievementFrameAchievements_Update
    ACHIEVEMENT_FUNCTIONS.updateFunc = AchievementFrameAchievements_Update

    local orig_AchievementButton_DisplayAchievement = AchievementButton_DisplayAchievement
    AchievementButton_DisplayAchievement = function(button, category, achievement, selectionID, ...)
        if search_name then
            local id, name, points, completed, month, day, year, description, flags, icon, rewardText = GetAchievementInfo(category, achievement)
            if achievements_shown[id] or not name or not string.match(string.lower(name), search_name) then
                button:Hide()
                -- Keep going until we run out of achievements
                if name then
                    return AchievementButton_DisplayAchievement(button, category, achievement + 1, selectionID, ...)
                end
                return
            end
            achievements_shown[id] = true
        end
        return orig_AchievementButton_DisplayAchievement(button, category, achievement, selectionID, ...)
    end

    local search = CreateFrame("EditBox", nil, AchievementFrameCategories, "InputBoxTemplate")
    search:SetHeight(16)
    search:SetWidth(100)
    search:SetAutoFocus(false)
    search:ClearAllPoints()
    search:SetPoint("TOPLEFT", AchievementFrame, "TOPLEFT", 148, 10)
    search:SetFrameStrata("HIGH")
    search:Hide()

    -- Could stick it into the category listing with...
    -- search:SetWidth(184)
    -- search:SetPoint("BOTTOMLEFT", AchievementFrameCategories, "BOTTOMLEFT", 9, 4)

    search.placeholder = true
    search:SetText("Filter")
    search:SetTextColor(0.90, 0.90, 0.90, 0.80)
    search:SetScript("OnTextChanged", function(self)
        if self.placeholder or self:GetText() == "" then
            search_name = nil
        else
            search_name = string.lower(self:GetText())
        end

        AchievementFrameAchievements_Update()
    end)
    search:SetScript("OnEditFocusGained", function(self)
        if self.placeholder then
            self.placeholder = nil
            self:SetText("")
            self:SetTextColor(1, 1, 1, 1)
        end
    end)
    search:SetScript("OnEditFocusLost", function(self)
        if not self.placeholder and string.trim(self:GetText()) == "" then
            self.placeholder = true
            self:SetText("Filter")
            self:SetTextColor(0.90, 0.90, 0.90, 0.80)
        end
    end)
    search:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(search, "ANCHOR_RIGHT", -18, 0)
        GameTooltip:AddLine("Filter the current achievements category by title")
        GameTooltip:Show()
    end)
    search:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- We can't monitor the OnShow/OnHide events because they aren't consistant (It's stupid, I know)
    local orig_AchievementFrameBaseTab_OnClick = AchievementFrameBaseTab_OnClick
    AchievementFrameBaseTab_OnClick = function(id, ...)
        orig_AchievementFrameBaseTab_OnClick(id, ...)
        core.Debug("click", id, ACHIEVEMENT_FUNCTIONS.selectedCategory)
        if id == 1 and not (ACHIEVEMENT_FUNCTIONS.selectedCategory == "summary") then
            search:Show()
        else
            search.placeholder = true
            search_name = nil
            search:SetText("Filter")
            search:ClearFocus()
            search:Hide()
        end
    end

    hooksecurefunc("AchievementFrameCategories_SelectButton", function(button)
        local id = button.element.id
        if id == "summary" then
            search:Hide()
        else
            search:Show()
        end
    end)
end
