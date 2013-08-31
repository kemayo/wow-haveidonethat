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
    for achievementid, nodes in pairs(achievements) do
        if nodes == false then
            nodes = {}
            for i=1, GetAchievementNumCriteria(achievementid) do
                local desc, _, _, _, _, _, _, _, _, criteriaid = GetAchievementCriteriaInfo(achievementid, i)
                if desc and criteriaid then
                    nodes[desc] = criteriaid
                    achievements[achievementid] = nodes
                end
            end
        end
        if nodes then
            for criteria, criteriaid in pairs(nodes) do
                self.Debug("considering", text, criteria, text:match(criteria))
                if text:match(criteria) then
                    local _, a_name, _, complete = GetAchievementInfo(achievementid)
                    if core.db.done_achievements or not complete then
                        local desc, _, done = GetAchievementCriteriaInfoByID(achievementid, criteriaid)
                        self:AddTooltipLine(tooltip, done, a_name, NEED, DONE)
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
}
