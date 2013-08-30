local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")

HIDT = ns

ns.defaults = {
    achievements = true,
    done_achievements = true,
    done_criteria = true,
    commendations = true,
}
ns.defaultsPC = {}

ns:RegisterEvent("ADDON_LOADED")
function ns:ADDON_LOADED(event, addon)
    if addon ~= myname then return end
    self:InitDB()

    -- Do anything you need to do after addon has loaded

    LibStub("tekKonfig-AboutPanel").new(myfullname, myname) -- Make first arg nil if no parent config panel

    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")

    self:HookScript(GameTooltip, "OnTooltipSetItem")
    self:HookScript(ItemRefTooltip, "OnTooltipSetItem")
    self:HookScript(ShoppingTooltip1, "OnTooltipSetItem")
    self:HookScript(ShoppingTooltip2, "OnTooltipSetItem")
    self:HookScript(ShoppingTooltip3, "OnTooltipSetItem")

    self:UnregisterEvent("ADDON_LOADED")
    self.ADDON_LOADED = nil

    if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterEvent("PLAYER_LOGIN") end
end

function ns:PLAYER_LOGIN()
    self:RegisterEvent("PLAYER_LOGOUT")

    -- Do anything you need to do after the player has entered the world

    self:UnregisterEvent("PLAYER_LOGIN")
    self.PLAYER_LOGIN = nil
end

function ns:PLAYER_LOGOUT()
    self:FlushDB()
    -- Do anything you need to do as the player logs out
end

-- Utility

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
    function ns:UnitID(unit)
        return npc_id_from_guid(UnitGUID(unit))
    end
end

function ns:AddTooltipLine(tooltip, complete, left, right_need, right_done)
    tooltip:AddDoubleLine(left or " ", complete and right_done or right_need,
        1, 1, 0,
        complete and 0 or 1, complete and 1 or 0, 0
    )
end
