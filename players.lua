local myname, ns = ...
local mod = ns:NewModule("mobs")
local core = ns:GetModule("core")

local achievements = {
    [1687] = { -- Let It Snow
        item = 34191,
        unit = function(unit)
            return UnitRace(unit).." "..UnitClass(unit)
        end,
    },
    [1699] = { -- Fistful of Love
        item = 22218,
        unit = function(unit)
            return UnitRace(unit).." "..UnitClass(unit)
        end,
    },
    [2422] = { -- Shake Your Bunny-Maker
        item = 45073,
        unit = function(unit)
            if UnitSex(unit) == 3 then
                return UnitRace(unit)
            end
        end,
    },
    [291] = { -- Check Your Head
        item = 34068,
        unit = function(unit)
            return UnitRace(unit)
        end,
    },
    [3559] = { -- Turkey Lurkey
        item = 44812,
        unit = function(unit)
            if select(2, UnitClass(unit)) == "ROGUE" then
                return UnitRace(unit).." "..UnitClass(unit)
            end
        end,
    },
}

function mod:OnLoad()
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
end

function mod:UPDATE_MOUSEOVER_UNIT()
    if not UnitIsPlayer("mouseover") then
        return
    end
    for achievementid,data in pairs(achievements) do
        if (not data.item) or GetItemCount(data.item) > 0 then
            local possible_match = data.unit("mouseover")
            if possible_match then
                if not data.criteria then
                    local criteria = {}
                    for i=1,GetAchievementNumCriteria(achievementid) do
                        local desc, _, _, _, _, _, _, _, _, criteriaid = GetAchievementCriteriaInfo(achievementid, i)
                        criteria[desc] = criteriaid
                        data.criteria = criteria
                    end
                end
                if data.criteria[possible_match] then
                    local _, a_name, _, complete = GetAchievementInfo(achievementid)
                    if core.db.done_achievements or not complete then
                        local desc, _, done = GetAchievementCriteriaInfoByID(achievementid, data.criteria[possible_match])
                        if core.db.done_criteria or not done then
                            self:AddTooltipLine(GameTooltip, done, a_name, NEED, DONE)
                        end
                    end
                end
            end
        end
    end
    GameTooltip:Show()
end
