local myname, ns = ...

local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")
function ns.Print(...) print("|cFF33FF99".. myfullname.. "|r:", ...) end

local debugf = tekDebug and tekDebug:GetFrame(myname)
function ns.Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end

function ns:AddTooltipLine(tooltip, complete, left, right_need, right_done)
    tooltip:AddDoubleLine(left or " ", complete and right_done or right_need,
        1, 1, 0,
        complete and 0 or 1, complete and 1 or 0, 0
    )
end
