local myname, ns = ...

local tabards, commendations

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
    if tabards[id] then
        local desc, _, done = GetAchievementCriteriaInfoByID(621, tabards[id])
        self:AddTooltipLine(tooltip, done, select(2, GetAchievementInfo(621)), NEED, DONE)
    end
    if commendations[id] then
        local hasBonusRepGain = select(15, GetFactionInfoByID(commendations[id]))
        self:AddTooltipLine(tooltip, hasBonusRepGain, BONUS_REPUTATION_TITLE, NEED, DONE)
    end

    -- refresh!
    tooltip:Show()
end

-- big ol' lists

commendations = {
    -- itemid = factionid
    [93220] = 1270, -- shado-pan
    [92522] = 1337, -- klaxxi
    [93230] = 1345, -- lorewalkers
    [93226] = 1272, -- tillers
    [93229] = 1271, -- cloud serpent
    [93215] = 1269, -- golden lotus
    [93224] = 1341, -- august celestials
    [93225] = 1302, -- anglers
    [95548] = 1388, -- sunreaver onslaught
    [93232] = 1375, -- dominance offensive
    [95545] = 1387, -- kirin tor offensive
    [93231] = 1376, -- operation shieldwall
}
tabards = {
    -- itemid = criteriaid
    [5976] = 2340,
    [11364] = 2922,
    [15196] = 2908,
    [15197] = 2909,
    [15198] = 2903,
    [15199] = 2915,
    [19031] = 2899,
    [19032] = 2916,
    [19160] = 2898,
    [19505] = 2933,
    [19506] = 2912,
    [20131] = 2894,
    [20132] = 2335,
    [22999] = 2925,
    [23192] = 2928,
    [23388] = 2932,
    [23705] = 2918,
    [23709] = 2919,
    [23999] = 2901,
    [24004] = 2931,
    [24344] = 2927,
    [25549] = 2895,
    [28788] = 2338,
    [31404] = 2900,
    [31405] = 2337,
    [31773] = 2906,
    [31774] = 2904,
    [31775] = 2914,
    [31776] = 2336,
    [31777] = 2902,
    [31778] = 2905,
    [31779] = 2893,
    [31780] = 2910,
    [31781] = 2911,
    [31804] = 2896,
    [32445] = 2913,
    [32828] = 2907,
    [35221] = 2929,
    [35279] = 2923,
    [35280] = 2339,
    [36941] = 2897,
    [38309] = 2921,
    [38310] = 2924,
    [38311] = 2930,
    [38312] = 2917,
    [38313] = 2920,
    [38314] = 2926,
    [40643] = 12600,
    [43154] = 6976,
    [43155] = 6977,
    [43156] = 6978,
    [43157] = 6979,
    [43300] = 6151,
    [43348] = 6171,
    [43349] = 6172,
    [45574] = 11306,
    [45577] = 11305,
    [45578] = 11304,
    [45579] = 11302,
    [45580] = 11303,
    [45581] = 11378,
    [45582] = 11299,
    [45583] = 11300,
    [45584] = 11301,
    [45585] = 11298,
    [45983] = 12598,
    [46817] = 11307,
    [46818] = 11308,
    [46874] = 11309,
    [49052] = 11760,
    [49054] = 11761,
    [49086] = 12599,
    [51534] = 13242,
    [52252] = 13241,
    [56246] = 16329,
    [63378] = 16328,
    [63379] = 16327,
    [64882] = 16326,
    [64884] = 16325,
    [65904] = 16324,
    [65905] = 16323,
    [65906] = 16322,
    [65907] = 16321,
    [65908] = 16320,
    [65909] = 16319,
    [69209] = 16885,
    [69210] = 16886,
    [83079] = 21693,
    [83080] = 21692,
    [89196] = 22626,
    [89401] = 22625,
    [89784] = 22624,
    [89795] = 22623,
    [89796] = 22622,
    [89797] = 22621,
    [89798] = 22620,
    [89799] = 22619,
    [89800] = 22618,
}
