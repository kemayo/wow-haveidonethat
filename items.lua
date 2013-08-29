local myname, ns = ...

local commendations = {
    [93220] = 1270, -- shado-pan
    [92522] = 1337, -- klaxxi
}

function ns:OnTooltipSetItem(tooltip)
    local name, link = tooltip:GetItem()
    if not name then
        return
    end
    local name, link, quality, ilvl, reqlvl, class, subclass, maxstack, equipslot, texture, vendorprice = GetItemInfo(link)
    if not name then
        -- Honestly, this is incredibly unlikely.
        return
    end
    local id = tonumber(link:match("item:(%d+):"))
    if not id then
        -- Similarly unlikely.
        return
    end
    -- and now the types
    if equipslot == "INVTYPE_TABARD" then
        self:AddTooltipLine(tooltip, self.dbpc.worn[id], select(2, GetAchievementInfo(621)), NEED, DONE)
    end
    if commendations[id] then
        local hasBonusRepGain = select(15, GetFactionInfoByID(commendations[id]))
        self:AddTooltipLine(tooltip, hasBonusRepGain, BONUS_REPUTATION_TITLE, NEED, DONE)
    end

    -- refresh!
    tooltip:Show()
end

function ns:UNIT_INVENTORY_CHANGED(event, unitid)
    if unitid ~= "player" then
        return
    end
    local tabard_id = GetInventoryItemID("player", 19)
    if tabard_id then
        self.dbpc.worn[tabard_id] = true
    end
end
