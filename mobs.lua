local myname, ns = ...

local achievements = {
    -- rares
    [1312] = {}, -- Bloody Rare (BC mobs)
    [2257] = {}, -- Frostbitten (Wrath mobs)
    [7439] = {}, -- Glorious! (Pandaria mobs)
    [8103] = {}, -- Champions of Lei Shen (Thunder Isle)
    [8714] = {}, -- Timeless Champion (Timeless Isle)
    -- splatto
    [2556] = { name = true, }, -- Pest Control
    -- looooove
    [1206] = { need = EMOTE152_CMD1, done = DONE, name = true, }, -- To All The Squirrels I've Loved Before
    [2557] = { need = EMOTE152_CMD1, done = DONE, name = true, }, -- To All The Squirrels Who Shared My Life
    [5548] = { need = EMOTE152_CMD1, done = DONE, name = true, }, -- To All the Squirrels Who Cared for Me
    [6350] = { need = EMOTE152_CMD1, done = DONE, name = true, }, -- To All the Squirrels I Once Caressed?
    -- general tag-em quests
    [7316] = { done = COMBAT_RATING_NAME6, name = true, }, -- Over Their Heads
}
local mobs_to_achievement = {
    -- [43819] = 2257,
}
local achievements_loaded = false
ns.achievements = achievements
ns.mobs_to_achievement = mobs_to_achievement

function ns:UPDATE_MOUSEOVER_UNIT()
    self:UpdateMobTooltip(self:UnitID('mouseover'), UnitName('mouseover'))
end

-- This is split out entirely so I can test this without having to actually hunt down a relevant mob
function ns:UpdateMobTooltip(id, unit_name)
    if not id then
        return
    end

    local achievement, name, completed = self:AchievementMobStatus(id)
    if not achievement then
        achievement, name, completed = self:AchievementMobStatus(unit_name)
    end
    if achievement then
        self:AddTooltipLine(GameTooltip, completed, name, achievements[achievement].need or NEED, achievements[achievement].done or ACTION_PARTY_KILL)
    end

    GameTooltip:Show()
end

function ns:AchievementMobStatus(id)
    if not achievements_loaded then
        self:LoadAllAchievementMobs()
    end
    local achievement = mobs_to_achievement[id]
    self.Debug("Achievement check", id, achievement)
    if not achievement then
        return
    end
    local criteria = achievements[achievement][id]
    local _, name = GetAchievementInfo(achievement)
    local _, _, completed = GetAchievementCriteriaInfo(achievement, criteria)
    return achievement, name, completed
end

function ns:LoadAllAchievementMobs()
    for achievement in pairs(achievements) do
        self:LoadAchievementMobs(achievement)
    end
end

function ns:LoadAchievementMobs(achievement)
    local num_criteria = GetAchievementNumCriteria(achievement)
    for i = 1, num_criteria do
        local description, ctype, completed, _, _, _, _, id = GetAchievementCriteriaInfo(achievement, i)
        if description then
            if achievements[achievement].name then
                achievements[achievement][description] = i
                mobs_to_achievement[description] = achievement
            else
                achievements[achievement][id] = i
                mobs_to_achievement[id] = achievement
            end

            achievements_loaded = true
        end
    end
end
