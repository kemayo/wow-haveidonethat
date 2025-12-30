local myname, ns = ...
local mod = ns:NewModule("objects")
local core = ns:GetModule("core")

local achievements

function mod:OnLoad()
    if _G.C_TooltipInfo then
        -- Cata-classic has TooltipDataProcessor, but doesn't actually use the new tooltips
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, function(tooltip, tooltipData)
            if tooltip ~= GameTooltip then return end
            if not (tooltipData and tooltipData.lines) then
                return
            end
            mod:CheckText(tooltipData.lines[1].leftText, tooltip)
        end)
    else
        GameTooltip:HookScript("OnShow", function(tooltip)
            if tooltip:NumLines() ~= 1 then return end
            if tooltip:GetUnit() or tooltip:GetItem() or tooltip:GetSpell() then return end
            local title = _G[tooltip:GetName() .. "TextLeft1"]
            if not title then return end
            mod:CheckText(title:GetText(), tooltip)
        end)
    end
end

function mod:CheckText(text, tooltip)
    -- print("CheckText", text)
    if not text or text == "" then return end
    if issecretvalue and issecretvalue(text) then return end
    text = "^" .. text:gsub("%s*School%s*", "")
    for achievementid, nodes in pairs(achievements) do
        if nodes == false then
            nodes = {}
            for i=1, GetAchievementNumCriteria(achievementid) do
                local desc, _, _, _, _, _, flags, assetid, _, criteriaid = GetAchievementCriteriaInfo(achievementid, i)
                if desc == "" and assetid and bit.band(flags, 0x00000001) == 0x00000001 then
                    desc = C_Item.GetItemInfo(assetid)
                    desc = desc and desc:gsub("%s*Enormous%s*", "")
                end
                if desc and desc ~= "" and criteriaid then
                    nodes[desc] = criteriaid
                    achievements[achievementid] = nodes
                end
            end
        end
        if nodes then
            for criteria, criteriaid in pairs(nodes) do
                if criteria:match(text) then
                    local _, a_name, _, complete = GetAchievementInfo(achievementid)
                    if core.db.done_achievements or not complete then
                        local desc, _, done, _, _, _, flags, _, quantityString = GetAchievementCriteriaInfoByID(achievementid, criteriaid)
                        if core.db.done_criteria or not done then
                            local need_text = NEED
                            if bit.band(flags, 0x00000001) == 0x00000001 then
                                need_text = quantityString
                            end
                            self:AddTooltipLine(tooltip, done, a_name, need_text, DONE)
                        end
                    end
                end
            end
        end
    end
    tooltip:Show()
end

achievements = {
    [1244] = false, -- Well Read
    [1956] = false, -- Higher Learning
    -- fishing
    [1257] = false, -- The Scavenger
    [1225] = false, -- Outland Angler
    [1517] = false, -- Northrend Angler
    [5478] = false, -- The Limnologist
    [5479] = false, -- The Oceanographer
    [7611] = false, -- Pandarian Angler
    -- timeless
    [8722] = false, -- Timeless Nutriment
    [8725] = false, -- Eyes on the Ground
    -- draenor angler
    [9455] = false, -- Fire Ammonite
    [9456] = false, -- Abyssal Gulper
    [9457] = false, -- Blackwater Whiptail
    [9458] = false, -- Blind Lake Sturgeon
    [9459] = false, -- Fat Sleeper
    [9460] = false, -- Jawless Skulker
    [9461] = false, -- Sea Scorpion
}
