local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")
local core = ns:GetModule("core")

local GAP = 8
local EDGEGAP = 16

local function makeFontString(frame, label, indented)
    local text = frame:CreateFontString(nil, "OVERLAY", indented and "GameFontNormalSmall" or "GameFontNormal")
    text:SetJustifyH("LEFT")
    text:SetText(label)
    if indented then
        text:SetPoint("LEFT", frame, (15 + 37), 0) -- indent variant
    else
        text:SetPoint("LEFT", frame, 37, 0)
    end
    text:SetPoint("RIGHT", frame, "CENTER", -85, 0)

    return text
end

local function makeTitle(parent, text)
    local title = CreateFrame("Frame", nil, parent)
    title.Text = makeFontString(title, text)
    title:SetSize(280, 26)
    title:SetPoint("RIGHT", parent)
    return title
end

local makeCheckbox
do
    local function checkboxGetValue(self) return core.db[self.key] end
    local function checkboxSetChecked(self) self:SetChecked(self:GetValue()) end
    local function checkboxSetValue(self, checked)
        core.db[self.key] = checked
        if self.callback then self.callback(self.key, checked) end
    end
    local function checkboxOnClick(self)
        local checked = self:GetChecked()
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        self:SetValue(checked)
    end
    local function checkboxOnEnter(self)
        if self.tooltipText then
            GameTooltip:SetOwner(self, self.tooltipOwnerPoint or "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText, nil, nil, nil, nil, true)
        end
        if self.tooltipRequirement then
            GameTooltip:AddLine(self.tooltipRequirement, 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end
    function makeCheckbox(parent, key, label, description, callback)
        local frame = CreateFrame("Frame", nil, parent)
        local check = CreateFrame("CheckButton", nil, frame, "InterfaceOptionsCheckButtonTemplate")
        check.key = key
        check.callback = callback
        check.GetValue = checkboxGetValue
        check.SetValue = checkboxSetValue
        check:SetScript('OnShow', checkboxSetChecked)
        check:SetScript("OnClick", checkboxOnClick)
        check:SetScript("OnEnter", checkboxOnEnter)
        check:SetScript("OnLeave", GameTooltip_Hide)
        check.tooltipText = label
        check.tooltipRequirement = description
        check:SetPoint("LEFT", frame, "CENTER", -90, 0)
        frame.Check = check

        frame.Text = makeFontString(frame, label, true)

        frame:SetPoint("RIGHT", parent)

        frame:SetSize(280, 26)

        checkboxSetChecked(check)

        return frame
    end
end

local simple_config = function(frame, prev, key, label, tooltip, spacing)
    local setting = makeCheckbox(frame, key, label, tooltip)
    setting:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, spacing or -GAP)
    return setting
end
local simple_section = function(frame, prev, label)
    local section = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    section:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2 * GAP)
    section:SetText(label)
    return section
end

local frame = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
frame.name = myfullname
frame:Hide()
frame:SetScript("OnShow", function(frame)
    local title = makeTitle(frame, myfullname)
    title:SetPoint("TOPLEFT")

    local ach_heading = simple_section(frame, title, ACHIEVEMENTS)

    local achievements = simple_config(frame, ach_heading, "achievements", "Show achievements", "Show whether a mob or item is needed for an achievement")
    local done_achievements = simple_config(frame, achievements, "done_achievements", "Show criteria for completed achievements")
    local done_criteria = simple_config(frame, done_achievements, "done_criteria", "Show completed criteria for incomplete achievements")
    local show_id = simple_config(frame, done_criteria, "id", "Show achievement IDs", "Show achievement IDs around the place; mostly useful for debugging problems")

    local items_heading = simple_section(frame, show_id, ITEMS)

    local commendations = simple_config(frame, items_heading, "commendations", "Show commendations", "Show whether or not you've already bought and applied a commendation")
    local quests = simple_config(frame, commendations, "quests", "Show quests", "Show whether or not you've already completed a quest associated with an item")

    frame:SetScript("OnShow", nil)
end)

local category, layout = Settings.RegisterCanvasLayoutCategory(frame, frame.name, frame.name)
category.ID = frame.name
Settings.RegisterAddOnCategory(category)

_G["SLASH_".. myname:upper().."1"] = C_AddOns.GetAddOnMetadata(myname, "X-LoadOn-Slash")
_G["SLASH_".. myname:upper().."2"] = "/hidt"
SlashCmdList[myname:upper()] = function(msg)
    if msg:match("suggest") then
        local suggest = ns:GetModule("suggest")
        if suggest then
            suggest:ShowSuggestions()
        end
    else
        Settings.OpenToCategory(myfullname)
    end
end

LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(myname, {
    type = "launcher",
    icon = [[Interface\HELPFRAME\HelpIcon-KnowledgeBase]],
    OnClick = function(self, button)
        local suggest = ns:GetModule("suggest")
        if (not suggest) or button == "RightButton" then
            Settings.OpenToCategory(myfullname)
        else
            suggest:ShowSuggestions()
        end
    end,
})
