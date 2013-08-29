local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")

HIDT = ns

ns.defaults = {
    show_done = true,
}
ns.defaultsPC = {
    worn = nil,
    consumed = nil,
    fished = nil,
}

ns:RegisterEvent("ADDON_LOADED")
function ns:ADDON_LOADED(event, addon)
    if addon ~= myname then return end
    self:InitDB()

    if not self.dbpc.worn then
        self.dbpc.worn = {}
    end
    if not self.dbpc.consumed then
        self.dbpc.consumed = {}
    end
    if not self.dbpc.fished then
        self.dbpc.fished = {}
    end

    -- Do anything you need to do after addon has loaded

    LibStub("tekKonfig-AboutPanel").new(nil, myname) -- Make first arg nil if no parent config panel

    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self:RegisterEvent("UNIT_INVENTORY_CHANGED")

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
    self:UNIT_INVENTORY_CHANGED()

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
    if complete and not self.db.show_done then
        return
    end
    tooltip:AddDoubleLine(left or " ", complete and right_done or right_need,
        1, 1, 0,
        complete and 0 or 1, complete and 1 or 0, 0
    )
end
