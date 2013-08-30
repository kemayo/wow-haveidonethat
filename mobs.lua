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
local arbitrary_mobs = {
    [15263] = {7934, 1}, -- raiding with leashes, mindslayer
    [15276] = {7934, 2}, -- raiding with leashes, idol
    [15952] = {7934, 3}, -- raiding with leashes, spider
    [16011] = {7934, 4}, -- raiding with leashes, fungal
    [15932] = {7934, 5}, -- raiding with leashes, pup
    [12098] = {7934, 6}, -- raiding with leashes, harbinger
    [11982] = {7934, 7}, -- raiding with leashes, imp
    [11988] = {7934, 8}, -- raiding with leashes, core
    [12435] = {7934, 9}, -- raiding with leashes, hatchling
    [14020] = {7934, 10}, -- raiding with leashes, chrominius
    [12017] = {7934, 11}, -- raiding with leashes, whelpguard
    [15299] = {7934, 12}, -- raiding with leashes, viscidus
    [17521] = {8293, 1}, -- raiding with leashes 2, lil bad wolf
    [15691] = {8293, 2}, -- raiding with leashes 2, custodian
    [15690] = {8293, 3}, -- raiding with leashes 2, abyssal
    [15688] = {8293, 4}, -- raiding with leashes 2, imp
    [21213] = {8293, 5}, -- raiding with leashes 2, tideskipper
    [21216] = {8293, 6}, -- raiding with leashes 2, waveling
    [21212] = {8293, 7}, -- raiding with leashes 2, coilfang
    [19516] = {8293, 8}, -- raiding with leashes 2, reaver
    [18805] = {8293, 9}, -- raiding with leashes 2, voidcaller
    [19514] = {8293, 10}, -- raiding with leashes 2, phoenix
}
local achievements_loaded = false

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

    if arbitrary_mobs[id] then
        local description, _, completed = GetAchievementCriteriaInfo(arbitrary_mobs[id][1], arbitrary_mobs[id][2])
        self:AddTooltipLine(GameTooltip, completed, description, NEED, DONE)
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
