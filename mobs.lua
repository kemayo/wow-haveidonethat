local myname, ns = ...
local mod = ns:NewModule("mobs")
local core = ns:GetModule("core")

function mod:OnLoad()
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
end

local achievements = {
    -- [achievementid] = {[mobid] = criteria}
    -- rares
    [1312] = false, -- Bloody Rare (BC mobs)
    [2257] = false, -- Frostbitten (Wrath mobs)
    [7439] = false, -- Glorious! (Pandaria mobs)
    [8103] = false, -- Champions of Lei Shen (Thunder Isle)
    [8714] = false, -- Timeless Champion (Timeless Isle)
    -- splatto
    [2556] = false, -- Pest Control
    -- looooove
    [1206] = false, -- To All The Squirrels I've Loved Before
    [2557] = false, -- To All The Squirrels Who Shared My Life
    [5548] = false, -- To All the Squirrels Who Cared for Me
    [6350] = false, -- To All the Squirrels I Once Caressed?
    -- general tag-em quests
    [7316] = false, -- Over Their Heads
    -- pets
    [7934] = { -- raiding with leashes
        [15263] = 22468, -- mindslayer
        [15276] = 22469, -- idol
        [15952] = 22470, -- spider
        [16011] = 22471, -- fungal
        [15932] = 22473, -- pup
        [12098] = 22474, -- harbinger
        [11982] = 22475, -- imp
        [11988] = 22476, -- core
        [12435] = 22477, -- hatchling
        [14020] = 22478, -- chrominius
        [12017] = 22479, -- whelpguard
        [15299] = 22480, -- viscidus
    },
    [8293] = {
        [17521] = 23321, -- lil bad wolf
        [15691] = 23322, -- custodian
        [15690] = 23323, -- abyssal
        [15688] = 23324, -- imp
        [21213] = 23325, -- tideskipper
        [21216] = 23326, -- waveling
        [21212] = 23327, -- coilfang
        [19516] = 23328, -- reaver
        [18805] = 23329, -- voidcaller
        [19514] = 23330, -- phoenix
    },
}
local achievement_settings = {
    default = { need = NEED, done = ACTION_PARTY_KILL, },
    [2556] = { name = true, }, -- pest control
    [1206] = { need = EMOTE152_CMD1, done = DONE, name = true, }, -- squirrels 1
    [2557] = { need = EMOTE152_CMD1, done = DONE, name = true, }, -- squirrels 2
    [5548] = { need = EMOTE152_CMD1, done = DONE, name = true, }, -- squirrels 3
    [6350] = { need = EMOTE152_CMD1, done = DONE, name = true, }, -- squirrels 4
    [7934] = { criteria_label = true, },
    [8293] = { criteria_label = true, },
}
do
    local achievements_meta = { __index = achievement_settings.default, }
    for k,v in pairs(achievement_settings) do
        if k ~= 'default' then
            setmetatable(v, achievements_meta)
        end
    end
end

function mod:UPDATE_MOUSEOVER_UNIT()
    self:UpdateMobTooltip(self:UnitID('mouseover'), UnitName('mouseover'))
end

-- This is split out entirely so I can test this without having to actually hunt down a relevant mob
function mod:UpdateMobTooltip(id, unit_name)
    if not id then
        return
    end

    if core.db.achievements then
        for achievementid,mobs in pairs(achievements) do
            local settings = achievement_settings[achievementid] or achievement_settings.default
            if mobs == false then
                mobs = {}
                for i=1,GetAchievementNumCriteria(achievementid) do
                    local desc, _, _, _, _, _, _, id, _, criteriaid = GetAchievementCriteriaInfo(achievementid, i)
                    mobs[id] = criteriaid
                    mobs[desc] = criteriaid
                    achievements[achievementid] = mobs
                end
            end
            if mobs[id] or mobs[unit_name] then
                local _, name, _, complete = GetAchievementInfo(achievementid)
                if core.db.done_achievements or not complete then
                    local desc, _, done = GetAchievementCriteriaInfoByID(achievementid, mobs[id] or mobs[unit_name])
                    if core.db.done_criteria or not done then
                        self:AddTooltipLine(GameTooltip, done, settings.criteria_label and desc or name, settings.need, settings.done)
                    end
                end
            end
        end
    end

    GameTooltip:Show()
end

do
    local valid_unit_types = {
        [0x003] = true, -- npcs
        [0x005] = true, -- vehicles
    }
    local function npc_id_from_guid(guid)
        if not guid then return end
        local unit_type = bit.band(tonumber("0x"..strsub(guid, 3, 5)), 0x00f)
        if not valid_unit_types[unit_type] then
            return
        end
        return tonumber("0x"..strsub(guid, 6, 10))
    end
    function mod:UnitID(unit)
        return npc_id_from_guid(UnitGUID(unit))
    end
end