local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")
local core = ns:GetModule("core")

local tekcheck = LibStub("tekKonfig-Checkbox")
local GAP = 8
local EDGEGAP = 16

local simple_config = function(frame, prev, key, label, tooltip, spacing)
    local setting = tekcheck.new(frame, nil, label, "TOPLEFT", prev, "BOTTOMLEFT", 0, spacing or -GAP)
    local checksound = setting:GetScript("OnClick")
    setting.tiptext = tooltip
    setting:SetScript("OnClick", function(self)
        checksound(self)
        core.db[key] = not core.db[key]
    end)
    setting:SetChecked(core.db[key])
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
    local title, subtitle = LibStub("tekKonfig-Heading").new(frame, myfullname, ("General settings for %s."):format(myfullname))

    local ach_heading = simple_section(frame, subtitle, ACHIEVEMENTS)

    local achievements = simple_config(frame, ach_heading, "achievements", "Show achievements", "Show whether a mob or item is needed for an achievement")
    local done_achievements = simple_config(frame, achievements, "done_achievements", "Show criteria for completed achievements")
    local done_criteria = simple_config(frame, done_achievements, "done_criteria", "Show completed criteria for incomplete achievements")
    local show_id = simple_config(frame, done_criteria, "id", "Show achievement IDs", "Show achievement IDs around the place; mostly useful for debugging problems")

    local items_heading = simple_section(frame, show_id, ITEMS)

    local commendations = simple_config(frame, items_heading, "commendations", "Show commendations", "Show whether or not you've already bought and applied a commendation")

    frame:SetScript("OnShow", nil)
end)

InterfaceOptions_AddCategory(frame)

LibStub("tekKonfig-AboutPanel").new(myfullname, myname) -- Make first arg nil if no parent config panel

_G["SLASH_".. myname:upper().."1"] = GetAddOnMetadata(myname, "X-LoadOn-Slash")
_G["SLASH_".. myname:upper().."2"] = "/hidt"
SlashCmdList[myname:upper()] = function(msg)
    if msg:match("suggest") then
        local suggest = ns:GetModule("suggest")
        if suggest then
            suggest:ShowSuggestions()
        end
    else
        InterfaceOptionsFrame_OpenToCategory(myfullname)
    end
end

LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(myname, {
    type = "launcher",
    icon = [[Interface\HELPFRAME\HelpIcon-KnowledgeBase]],
    OnClick = function(self, button)
        local suggest = ns:GetModule("suggest")
        if (not suggest) or button == "RightButton" then
            InterfaceOptionsFrame_OpenToCategory(myfullname)
        else
            suggest:ShowSuggestions()
        end
    end,
})
