local myname, ns = ...
local mod = ns:NewModule("objects")
local core = ns:GetModule("core")

local achievements

function mod:OnLoad()
    self:HookScript(GameTooltip, "OnShow")
end

function mod:OnShow(tooltip)
    if not tooltip then return end
    if tooltip:NumLines() ~= 1 then return end
    if _G[tooltip:GetName().."TextRight1"]:GetText() then return end
    -- we have a tooltip, and it's a single-line with only some text on the left
    -- this means there's decent odds that we're dealing with a world object
    local text = _G[tooltip:GetName().."TextLeft1"]:GetText()
    if not text then return end
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
