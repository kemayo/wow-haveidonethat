local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")
local mod = ns:NewModule("suggest")
local core = ns:GetModule("core")

local is_alliance = UnitFactionGroup("player") == "Alliance"
local is_horde = UnitFactionGroup("player") == "Horde"
local zones, quests, skills, pvp, dungeons, raids, scenarios, battlegrounds

local function extend(t1, t2)
    for i,v in ipairs(t2) do
        tinsert(t1, v)
    end
end
local function prepend(t1, t2)
    for i=#t2,1,-1 do
        tinsert(t1, 1, t2[i])
    end
end

function mod:OnLoad()
    if C_AddOns.IsAddOnLoaded("Blizzard_AchievementUI") then
        self:CreateFrame()
    else
        mod:RegisterEvent("ADDON_LOADED")
    end
end

function mod:ADDON_LOADED(event, addon)
    if addon ~= "Blizzard_AchievementUI" then
        return
    end
    self:CreateFrame()
    self:UnregisterEvent("ADDON_LOADED")
end

do
    local frame, sidebar, tab

    local update_achievements
    local categories
    local function build_categories()
        -- Actually build the category listing for the sidebar
        categories = {
            {id = "smart", label = "Smart", type = "smart", parent = true},
        }

        local function map_sort(a, b)
            local ainfo = C_Map.GetMapInfo(a.id)
            local binfo = C_Map.GetMapInfo(b.id)
            return ainfo.name < binfo.name
        end

        local function mapid_category_builder(name, type, ids)
            local mapid_categories = {}
            for mapid, aids in pairs(ids) do
                if #aids > 0 or aids.normal or aids.heroic or aids.size10 or aids.size25 or aids.lfr then
                    local info = C_Map.GetMapInfo(mapid)
                    if info then
                        tinsert(mapid_categories, {id = mapid, type = type, label = info.name})
                    end
                end
            end
            table.sort(mapid_categories, map_sort)
            tinsert(categories, {id = type, label = name, type = type, parent = true})
            extend(categories, mapid_categories)
        end

        mapid_category_builder(ZONE, "zone", zones)
        mapid_category_builder(SCENARIOS, "scenario", scenarios)
        mapid_category_builder(DUNGEONS, "dungeon", dungeons)
        mapid_category_builder(RAIDS, "raid", raids)
        -- would do this, but it's really redundant with the actual default UI
        -- mapid_category_builder(BATTLEGROUNDS, "battleground", battlegrounds)

        local skill_categories = {}
        for skill, ids in pairs(skills) do
            tinsert(skill_categories, {id = skill, type = "skill", label = skill})
        end
        table.sort(skill_categories, function(a,b)
            return a.id < b.id
        end)
        tinsert(categories, {id = "skill", label = TRADE_SKILLS, type = "skill", parent = true})
        extend(categories, skill_categories)
    end
    local display_categories = {}
    local expanded_category
    local function update_categories()
        build_categories()
        wipe(display_categories)
        local currently_expanded = false
        for i, cat in ipairs(categories) do
            if cat.parent then
                currently_expanded = expanded_category == cat.type
            end
            if currently_expanded or cat.parent then
                tinsert(display_categories, cat)
            end
        end

        local scroll_frame = sidebar.scroll_frame
        local num_items = #display_categories

        HybridScrollFrame_Update(scroll_frame, num_items * scroll_frame.buttonHeight, scroll_frame:GetHeight())
        local offset = HybridScrollFrame_GetOffset(scroll_frame)
        local buttons = scroll_frame.buttons

        local sidebar_width = sidebar:GetWidth()

        for i=1, #buttons do
            local button = buttons[i]
            local offset_i = offset + i
            button:SetWidth(scroll_frame:GetWidth())
            local cat = display_categories[offset_i]
            if cat then
                button.label:SetText(cat.label)
                button.cat = cat
                if cat.type == frame.suggest_type and cat.id == frame.suggest_id then
                    button:LockHighlight()
                else
                    button:UnlockHighlight()
                end
                if cat.parent then
                    button:SetWidth(sidebar_width - 10)
                    button.label:SetFontObject("GameFontNormal")
                    button.background:SetVertexColor(1, 1, 1)
                else
                    button:SetWidth(sidebar_width - 25)
                    button.label:SetFontObject("GameFontHighlight")
                    button.background:SetVertexColor(0.6, 0.6, 0.6)
                end
                button:Show()
            else
                button.cat = nil
                button:Hide()
            end
        end
    end
    local function category_click(self)
        local cat = self.cat
        if cat then
            frame.suggest_type = cat.type
            frame.suggest_id = cat.id
            if cat.parent then
                if expanded_category == cat.type then
                    expanded_category = nil
                else
                    expanded_category = cat.type
                end
            end
        end
        update_categories()
        update_achievements()
    end
    local function tab_click(tab, button)
        if (button) then
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        end

        -- Go through and unselect all the other tabs, and make ours look selected
        AchievementFrame_UpdateTabs(tab:GetID())
        -- ...but that won't adjust the text position because its loop maxes at 3
        tab.text:SetPoint("CENTER", 0, -5)

        -- display!
        AchievementFrame_ShowSubFrame(frame, sidebar)
    end
    local function button_click(self, button, down)
        if IsModifiedClick() then
            return AchievementButton_OnClick(self, button, down)
        end
        AchievementFrame_SelectAchievement(self.id)

        -- todo: Use HybridScroll_ExpandButton to do display of criteria onclick
        -- (can't mooch off the core functions, since they're deeply intertwined)
    end

    local function suggestion_handler(accumulate, suggestions, size, variant)
        if not suggestions then
            return accumulate
        end
        for i, aid in ipairs(suggestions) do
            tinsert(accumulate, aid)
        end
        if variant or size then
            if variant then
                if suggestions[variant] then
                    suggestion_handler(accumulate, suggestions[variant], size, variant)
                end
                -- normal achievements can always be earned on heroic as well, so include them if they're present
                if variant == "heroic" and suggestions.normal then
                    suggestion_handler(accumulate, suggestions.normal, size, variant)
                end
            end
            if size and suggestions['size' .. size] then
                suggestion_handler(accumulate, suggestions['size' .. size], size, variant)
            end
        else
            -- passing in nil,nil means just return everything
            for k,v in pairs(suggestions) do
                if type(v) == "table" then
                    suggestion_handler(accumulate, v, size, variant)
                end
            end
        end
        return accumulate
    end

    local function get_achievements_by_zoneid_any(zoneid)
        return zones[zoneid] or scenarios[zoneid] or dungeons[zoneid] or raids[zoneid] or battlegrounds[zoneid]
    end
    local function get_achievements_by_zoneid(zoneid)
        if type(zoneid) ~= "number" then return end
        if get_achievements_by_zoneid_any(zoneid) then
            return get_achievements_by_zoneid_any(zoneid)
        end
        local info = C_Map.GetMapInfo(zoneid)
        if info and info.parentMapID then
            -- could recurse, but I think our use-case is better served by one layer
            return get_achievements_by_zoneid_any(info.parentMapID)
        end
    end
    local to_suggest = {}
    function update_achievements()
        wipe(to_suggest)
        if frame.suggest_type == "smart" then
            local zoneid = C_Map.GetBestMapForUnit('player')
            if not zoneid then
                return
            end
            local suggestions = get_achievements_by_zoneid(zoneid)
            local instance_type, size, variant = mod:WorkOutInstanceType()

            suggestion_handler(to_suggest, suggestions, size, variant)

            local _, trade = C_TradeSkillUI.GetTradeSkillLine()
            if trade and skills[trade] then
                prepend(to_suggest, skills[trade])
            end
            for skillname, skillsuggestions in pairs(skills) do
                if skillsuggestions.zones and skillsuggestions.zones[zoneid] then
                    extend(to_suggest, skillsuggestions.zones[zoneid])
                end
            end
            if instance_type == "pvp" then
                extend(to_suggest, pvp)
            end
        elseif frame.suggest_type == "zone" or frame.suggest_type == "dungeon" or frame.suggest_type == "scenario" or frame.suggest_type == "raid" or frame.suggest_type == "battleground" then
            suggestion_handler(to_suggest, get_achievements_by_zoneid(frame.suggest_id))
        elseif frame.suggest_type == "skill" then
            suggestion_handler(to_suggest, skills[frame.suggest_id])
        end

        local scroll_frame = frame.scroll_frame
        local num_items = #to_suggest

        -- if num_items == 0 then
        --     scroll_frame:Hide()
        -- end

        HybridScrollFrame_Update(scroll_frame, num_items * scroll_frame.buttonHeight, scroll_frame:GetHeight())
        local offset = HybridScrollFrame_GetOffset(scroll_frame)
        local buttons = scroll_frame.buttons

        for i = 1, #buttons do
            local button = buttons[i]
            local offset_i = offset + i
            button.id = nil

            if offset_i <= num_items then
                AchievementButton_DisplayAchievement(button, to_suggest[offset_i])
                -- we passed this in without specifying the selection, because that's tied deep into other achievement stuff
                button.plusMinus:Hide()
            else
                button:Hide()
            end
        end
    end


    function mod:CreateFrame()
        if frame then
            return frame
        end

        -- First, our tab!

        local numtabs = 0
        repeat
            numtabs = numtabs + 1
        until not _G["AchievementFrameTab"..numtabs]

        tab = CreateFrame("Button", "AchievementFrameTab"..numtabs, AchievementFrame, "AchievementFrameTabButtonTemplate")
        tab:SetPoint("TOPRIGHT", "AchievementFrame", "BOTTOMRIGHT", 0, 2)
        tab:SetText("What now?")
        tab:SetID(numtabs)
        PanelTemplates_SetNumTabs(AchievementFrame, numtabs)

        tab:SetScript("OnClick", tab_click)
        hooksecurefunc("AchievementFrame_UpdateTabs", function()
            tab.text:SetPoint("CENTER", 0, -3)
        end)

        -- So. We want to copy a bunch of AchievementFrameAchievements.

        frame = CreateFrame("Frame", "HIDTAchievements", AchievementFrame)
        frame:SetHeight(440)
        frame:SetWidth(504)
        -- frame:SetPoint("CENTER")
        frame:SetPoint("TOPLEFT", AchievementFrameAchievements)
        frame:SetPoint("BOTTOM", AchievementFrameAchievements)
        frame:Hide()

        frame.suggest_type = "smart"
        frame.suggest_id = "smart"

        local backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        backdrop:SetAllPoints()
        backdrop:SetBackdrop({
            edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = {
                left = 5,
                right = 5,
                top = 5,
                bottom = 5,
            },
        })
        backdrop:SetBackdropBorderColor(ACHIEVEMENTUI_GOLDBORDER_R, ACHIEVEMENTUI_GOLDBORDER_G, ACHIEVEMENTUI_GOLDBORDER_B, ACHIEVEMENTUI_GOLDBORDER_A)
        backdrop:SetFrameLevel(backdrop:GetFrameLevel() + 1)

        frame.background = frame:CreateTexture("$parentBackground", "BACKGROUND")
        frame.background:SetTexture([[Interface\AchievementFrame\UI-Achievement-AchievementBackground]])
        frame.background:SetTexCoord(0, 1, 0, 0.5)
        frame.background:SetPoint("TOPLEFT", 3, -3)
        frame.background:SetPoint("BOTTOMRIGHT", -3, 3)

        local scroll_frame = CreateFrame("ScrollFrame", "$parentContainer", frame, "HybridScrollFrameTemplate")
        scroll_frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -3)
        scroll_frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 5)
        frame.scroll_frame = scroll_frame

        scroll_frame.update = update_achievements

        scroll_frame:SetScript("OnShow", scroll_frame.update)

        local scroll_bar = CreateFrame("Slider", "$parentScrollBar", scroll_frame, "HybridScrollBarTemplate")
        scroll_bar:SetPoint("TOPLEFT", scroll_frame, "TOPRIGHT", 1, -16)
        scroll_bar:SetPoint("BOTTOMLEFT", scroll_frame, "BOTTOMRIGHT", 1, 12)
        scroll_bar.trackBG:Show()
        scroll_bar.doNotHide = true
        scroll_frame.scrollBar = scroll_bar

        HybridScrollFrame_CreateButtons(scroll_frame, "AchievementTemplate", 0, 0);
        for i, button in ipairs(scroll_frame.buttons) do
            button:SetWidth(496)
            button:SetScript("OnClick", button_click)
            button.id_text = button.icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            button.id_text:SetPoint("BOTTOM", button.icon, "BOTTOM")
        end

        -- compact:
        -- HybridScrollFrame_CreateButtons(scroll_frame, "SummaryAchievementTemplate", 0, -4);
        -- for i, button in ipairs(scroll_frame.buttons) do
        --     button:SetWidth(496)
        --     button.isSummary = true
        --     AchievementFrameSummary_LocalizeButton(button)
        --     button:SetScript("OnClick", button_click)
        --     button.id_text = button.icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        --     button.id_text:SetPoint("BOTTOM", button.icon, "BOTTOM", 0, 10)
        --     -- the onload of this template adds us to a cache... let's take care of that...
        --     tremove(AchievementFrameSummaryAchievements.buttons)
        -- end

        -- Now we need that left sidebar

        sidebar = CreateFrame("Frame", frame:GetName().."Sidebar", AchievementFrame, "BackdropTemplate")
        sidebar:SetWidth(197)
        sidebar:SetPoint("TOPLEFT", 21, -19)
        sidebar:SetPoint("BOTTOMLEFT", 21, 20)
        sidebar:SetBackdrop({
            edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
            edgeSize = 16,
            tile = true,
            tileSize = 16,
            insets = {
                left = 5,
                right = 5,
                top = 5,
                bottom = 5,
            },
        })
        sidebar:SetBackdropBorderColor(ACHIEVEMENTUI_GOLDBORDER_R, ACHIEVEMENTUI_GOLDBORDER_G, ACHIEVEMENTUI_GOLDBORDER_B, ACHIEVEMENTUI_GOLDBORDER_A)
        sidebar:SetScript("OnShow", function()
            AchievementFrameCategories:Hide()
            AchievementFrameWaterMark:SetTexture("Interface\\AchievementFrame\\UI-Achievement-AchievementWatermark")
        end)
        sidebar:SetScript("OnHide", function()
            AchievementFrameCategories:Show()
        end)

        local sidebar_scroll_frame = CreateFrame("ScrollFrame", "$parentContainer", sidebar, "HybridScrollFrameTemplate")
        sidebar_scroll_frame:SetPoint("TOPLEFT", 0, -5)
        sidebar_scroll_frame:SetPoint("BOTTOMRIGHT", 0, 5)
        sidebar_scroll_frame.update = update_categories
        sidebar.scroll_frame = sidebar_scroll_frame

        local sidebar_scroll_bar = CreateFrame("Slider", "$parentScrollBar", sidebar_scroll_frame, "HybridScrollBarTemplate")
        sidebar_scroll_bar:SetPoint("TOPLEFT", sidebar_scroll_frame, "TOPRIGHT", 1, -14)
        sidebar_scroll_bar:SetPoint("BOTTOMLEFT", sidebar_scroll_frame, "BOTTOMRIGHT", 1, 12)
        sidebar_scroll_bar.trackBG:Show()
        sidebar_scroll_frame.scrollBar = sidebar_scroll_bar

        sidebar_scroll_bar.Show = function(self)
            sidebar:SetWidth(175)
            sidebar_scroll_frame:GetScrollChild():SetWidth(175)
            AchievementFrameWaterMark:SetWidth(145)
            AchievementFrameWaterMark:SetTexCoord(0, 145/256, 0, 1)
            getmetatable(self).__index.Show(self)
        end
        sidebar_scroll_bar.Hide = function(self)
            sidebar:SetWidth(197)
            sidebar_scroll_frame:GetScrollChild():SetWidth(197)
            AchievementFrameWaterMark:SetWidth(167)
            AchievementFrameWaterMark:SetTexCoord(0, 167/256, 0, 1)
            getmetatable(self).__index.Hide(self)
        end

        HybridScrollFrame_CreateButtons(sidebar_scroll_frame, "AchievementCategoryTemplate", 0, 0, "TOP", "TOP", 0, 0, "TOP", "BOTTOM");
        for i,button in ipairs(sidebar_scroll_frame.buttons) do
            button:SetScript("OnClick", category_click)
        end

        sidebar_scroll_frame:SetScript("OnShow", update_categories)

        -- Assorted letting other stuff know about our coolness
        -- tinsert(UISpecialFrames, frame:GetName())
        tinsert(ACHIEVEMENTFRAME_SUBFRAMES, frame:GetName())
        tinsert(ACHIEVEMENTFRAME_SUBFRAMES, sidebar:GetName())

        return frame
    end
    function mod:ShowSuggestions()
        if not AchievementFrame then
            AchievementFrame_LoadUI()
        end
        if not AchievementFrame:IsShown() then
            AchievementFrame_ToggleAchievementFrame()
        end
        tab_click(tab)
    end
end

do
    local difficulty_size_map = {
        [0] = 1,
        [1] = 5,
        [2] = 5, -- heroic
        [3] = 10,
        [4] = 25,
        [5] = 10, -- heroic
        [6] = 25, -- heroic
        [7] = 25, -- lfr
        [8] = 5, -- challenge mode
        [9] = 40,
        [11] = 3, -- heroic scenario
        [12] = 3, -- scenario
    }
    -- return: instance_type, raid_size, raid_variety
    -- e.g. "raid", 25, "lfr"
    function mod:WorkOutInstanceType()
        -- if we're in an instance...
        if IsInInstance() then
            local _, type, difficulty, _, _, _, isDynamicInstance = GetInstanceInfo()
            local _, _, isHeroic, isChallengeMode, toggleDifficultyID = GetDifficultyInfo(difficulty)
            local variety = "normal"
            if isHeroic then
                variety = "heroic"
            end
            if difficulty == 7 then
                variety = "lfr"
            end
            return type, difficulty_size_map[difficulty], variety
        end
        -- fall back on the dungeon settings
        local dungeon_diff = GetDungeonDifficultyID()
        local _, _, isHeroic, isChallengeMode, toggleDifficultyID = GetDifficultyInfo(dungeon_diff)
        return false, difficulty_size_map[dungeon_diff], isHeroic and "heroic" or "normal"
    end
end

-- DATA!!!

scenarios = {
    -- [uiMapID] = { achievementID, ... }
    [447] = { -- A Brewing Storm
        7252, 7258, 7257, 7261,
        heroic = {8310},
    },
    [487] = {7988, 7989, 7990, 7991, 7992, 7993}, -- A Little Patience
    [480] = {7271, 7273, 7272}, -- Arena of Annihilation
    [451] = {8016, 8017}, -- Assault on Zan'vess
    [524] = { -- Battle on the High Seas
        8314, 8347,
        heroic = {8364},
    },
    [523] = { -- Blood in the Snow
        8316, 8329, 8330,
        heroic = {8312},
    },
    [452] = {6923, 6931, 6930, }, -- Brewmoon Festival
    [571] = {8410, 8518}, -- Celestial Tournament
    [481] = { -- Crypt of Forgotten Kings
        7522, 7276, 7275, 8368,
        heroic = {8311},
        zones = {482},
    },
    [488] = {8009, 7987, 7986}, -- Dagger in the Dark
    [520] = { -- Dark Heart of Pandaria
        8317, 8319,
        heroic = {8318},
        zones = {521},
    },
    [462] = {7265, 7267, 7266}, -- Greenstone Village
    [522] = {8294, 8295}, -- The Secrets of Ragefire
    [450] = {7249, 7231, 7232, 7239, 7248}, -- Unga Ingoo
}
if is_alliance then
    scenarios[486] = {8010, 8011, 8012} -- Lion's Landing (A)
    scenarios[483] = { -- Theramore's Fall (A)
        7523, 7526, 7527,
        unavailable = {7467},
    }
end
if is_horde then
    scenarios[498] = {8013, 8014, 8015} -- Domination Point (H)
    scenarios[416] = { -- Theramore's Fall (H)
        7524, 7529, 7530,
        unavailable = {7468},
    }
end

raids = {
    [319] = {687, 7934, zones = {320, 321}}, -- Ahn'Qiraj (the raid)
    [340] = {697, 9824, zones = {341, 342, 343, 344, 345, 346}}, -- Black Temple
    [285] = { -- Blackwing Descent
        4842, 5306, 5307, 5308, 5309, 4849, 5310,
        heroic = {5094, 5107, 5108, 5109, 5115, 5116},
        zones = {286},
    },
    [287] = {685, 7934, zones = {288, 289, 290}}, -- Blackwing Lair
    [409] = { -- Dragon Soul
        6106, 6107,
        normal = {6177, 6174, 6128, 6129, 6175, 6084, 6105, 6133, 6180},
        heroic = {6109, 6110, 6111, 6112, 6113, 6114, 6115, 6116},
        zones = {410, 411, 412, 413, 415},
    },
    [367] = { -- Firelands
        5802, 5828, 5855, 5821, 5810, 5813, 5829, 5830, 5799, 5855,
        heroic = {5803, 5807, 5808, 5806, 5809, 5805, 5804},
        zones = {368, 369},
    },
    [330] = {692}, -- Gruul's Lair
    [474] = { -- Heart of Fear
        6718, 6845,
        normal = {6936, 6518, 6683, 6553, 6937, 6922},
        heroic = {6729, 6726, 6727, 6730, 6725, 6728},
        zones = {475},
    },
    [329] = {695, 9824}, -- Hyjal Summit
    [186] = { -- Icecrown Citadel
        size10 = {
            4532, 4580, 4601, 4534, 4538, 4577, 4535, 4536, 4537, 4578, 4581, 4539, 4579, 4582,
            heroic = {4636},
        },
        size25 = {
            4608, 4620, 4621, 4610, 4614, 4615, 4611, 4612, 4613, 4616, 4622, 4618, 4619, 4617,
            heroic = {4637},
        },
        zones = {187, 188, 189, 190, 191, 192, 193},
    },
    [350] = { -- Karazhan
        690, 8293,
        zones = {351, 352, 353, 354, 355, 356, 357, 358, 359, 360, 361, 362, 363, 364, 365, 366}
    },
    [331] = {693}, -- Magtheridon's Lair
    [471] = { -- Mogu'shan Vaults
        6458, 6844,
        normal = {6674, 6687, 6823, 6455, 7056, 6686},
        heroic = {6723, 6720, 6722, 6721, 6719, 6724},
        zones = {472, 473},
    },
    [232] = {686, 7934}, -- Molten Core
    [162] = { -- Naxxramas
        7934,
        size10 = {2146, 576, 578, 572, 1856, 2176, 2178, 2180, 568, 1996, 1997, 1858, 564, 2182, 2184, 566, 574, 562},
        size25 = {579, 565, 577, 575, 2177, 563, 567, 1857, 569, 573, 1859, 2139, 2181, 2183, 2185, 2147, 2140, 2179},
        unavailable = {2186, 2187},
        zones = {163, 164, 165, 166, 167},
    },
    [248] = { -- Onyxia's Lair
        size10 = {4396, 4402, 4403, 4404},
        unavailable = {684},
    },
    [247] = {689}, -- Ruins of Ahn'Qiraj
    [332] = {694, 8293}, -- Serpentshrine Cavern
    [556] = { -- Siege of Orgrimmar (also 557-570)
        8458, 8459, 8461, 8462,
        normal = {
            8679, -- completion
            9454, -- challenges meta
            8536, 8528, 8532, 8521, 8530, 8520, 8453, 8448, 8538, 8543, 8529, 8527, 8531, 8537,
        },
        heroic = {
            8463, 8465, 8466, 8467, 8468, 8469, 8470, 8471, 8472, 8478, 8479, 8480, 8481, 8482,
        },
        zones = {557, 558, 559, 560, 561, 562, 563, 564, 565, 566},
    },
    [335] = {698, 9824, zones = {336}}, -- Sunwell Plateau
    [334] = {696, 8293}, -- Tempest Keep
    [456] = { -- Terrace of Endless Spring
        6689,
        normal = {6824, 6717, 6825, 6933},
        heroic = {6733, 6731, 6734, 6732},
    },
    [294] = { -- The Bastion of Twilight
        4850, 5300, 4852, 5311, 5312,
        heroic = {5118, 5117, 5119, 5120, 5121},
        zones = {295, 296},
    },
    [141] = { -- The Eye of Eternity
        size10 = {622, 1874, 2148, 1869},
        size25 = {623, 1875, 2149, 1870},
    },
    [155] = { -- The Obsidian Sanctum
        size10 = {1876, 2047, 2049, 2050, 2051, 624},
        size25 = {625, 2048, 2052, 2053, 2054, 1877},
    },
    [200] = { -- The Ruby Sanctum
        size10 = {
            4817,
            heroic = {4818},
        },
        size25 = {
            4815,
            heroic = {4816},
        },
    },
    [328] = { -- Throne of the Four Winds
        4851, 5304, 5305,
        heroic = {5122, 5123, },
    },
    [508] = { -- Throne of Thunder
        8070, 8071, 8069, 8072,
        normal = {8089, 8037, 8087, 8090, 8094, 8073, 8082, 8098, 8081, 8086},
        heroic = {8124, 8067},
        zones = {509, 510, 511, 512, 513, 514, 515},
    },
    [172] = { -- Trial of the Crusader
        size10 = {
            3917, 3936, 3798, 3799, 3800, 3996, 3797,
            heroic = {3918},
        },
        size25 = {
            3916, 3937, 3815, 3816, 3997, 3813,
            heroic = {3812},
        },
        unavailable = {3808, 3817},
        zones = {173},
    },
    [147] = { -- Ulduar
        size10 = {
            -- overall
            2957, 2894,
            -- siege
            2886,
            --  formation grounds
            3097, 2905, 2907, 2909, 2911, 2913,
            --  razorscale
            2919, 2923,
            --  colossal forge
            2925, 2927, 2930,
            --  scrapyard
            2931, 2933, 2934, 2937, 3058,
            -- antechamber
            2888,
            --  assembly of iron
            2939, 2940, 2941, 2945, 2947,
            --  shattered walkway
            2951, 2953, 2955, 2959,
            --  observation ring
            3006, 3076,
            -- keepers
            2890,
            --  halls of winter
            2961, 2963, 2967, 3182, 2969,
            --  clash of thunder
            2971, 2973, 2975, 2977,
            --  conservatory
            2979, 2980, 2985, 2982, 3177,
            --  spark of imagination
            2989, 3138, 3180,
            -- descent
            2892,
            --  descent into madness
            2996, 3181,
            --  prison
            3009, 3157, 3008, 3012, 3014, 3015, 3157, 3141, 3158, 3159,
            -- alganon
            3036, 3003,
        },
        size25 = {
            -- overall
            2958, 2895,
            -- siege
            2887,
            --  formation grounds
            3098, 2906, 2908, 2910, 2912, 2918,
            --  razorscale
            2921, 2924,
            --  colossal forge
            2926, 2928, 2929,
            --  scrapyard
            2932, 2935, 2936, 2938, 3059,
            -- antechamber
            2889,
            --  assembly of iron
            2942, 2943, 2944, 2946, 2948,
            --  shattered walkway
            2952, 2954, 2956, 2960,
            --  observation ring
            3007, 3077,
            -- keepers
            2891,
            --  halls of winter
            2962, 2965, 2968, 3184, 2970,
            --  clash of thunder
            2972, 2974, 2976, 2978,
            --  conservatory
            3118, 2981, 2984, 2983, 3185,
            --  spark of imagination
            3237, 2995, 3189,
            -- descent
            2893,
            --  descent into madness
            2997, 3188,
            --  prison
            3011, 3161, 3010, 3013, 3017, 3016, 3161, 3162, 3163, 3164,
            -- alganon
            3037, 3002,
        },
        unavailable = {2903, 2904, 3004, 3005, 3316},
        zones = {148, 149, 150, 151, 152},
    },
    [156] = { -- Vault of Archavon
        size10 = {1722, 3136, 3836, 4016},
        size25 = {1721, 3137, 3837, 4017},
    },
}
dungeons = {
    [132] = { -- Ahn'kahet: The Old Kingdom
        481,
        heroic = {492, 2056, 1862, 2038}
    },
    [256] = { -- Auchenai Crypts
        666,
        heroic = {672},
        zones = {257},
    },
    [157] = { -- Azjol-Nerub
        480,
        heroic = {491, 1860, 1296, 1297},
        zones = {158, 159},
    },
    [221] = {632, zones = {222, 223}}, -- Blackfathom Deeps
    [283] = { -- Blackrock Caverns
        4833,
        heroic = {5282, 5284, 5281, 5060, 5283},
        zones = {284},
    },
    [242] = {642, zones = {243}}, -- Blackrock Depths
    [234] = {644, zones = {235, 236, 237, 238, 239, 240}}, -- Dire Maul
    [160] = { -- Drak'Tharon Keep
        482,
        heroic = {493, 2039, 2057, 2151},
        zones = {161},
    },
    [401] = { -- End Time
        heroic = {6117, 5995, 6130},
        zones = {402, 403, 404, 405, 406},
    },
    [437] = { -- Gate of the Setting Sun
        6945,
        heroic = {6759, 6479, 6476, 6715},
        zones = {438},
    },
    [293] = { -- Grim Batol
        4840,
        heroic = {5298, 5062, 5297},
    },
    [226] = {634, zones = {227, 228, 229}}, -- Gnomeregan
    [153] = { -- Gundrak
        484,
        heroic = {495, 2040, 2152, 1864, 2058},
        zones = {154},
    },
    [138] = { -- Halls of Lightning
        486,
        heroic = {497, 2042, 1867, 1834},
        zones = {139},
    },
    [297] = { -- Halls of Origination
        4841,
        heroic = {5296, 5065, 5293, 5294, 5295},
        zones = {298, 299},
    },
    [185] = { -- Halls of Reflection
        4518,
        heroic = {4521, 4526},
    },
    [140] = { -- Halls of Stone
        485,
        heroic = {496, 1866, 2154, 2155},
    },
    [347] = { -- Hellfire Ramparts
        647,
        heroic = {667}
    },
    [399] = { -- Hour of Twilight
        heroic = {6119, 6132, 6084},
    },
    [277] = { -- Lost City of the Tol'vir
        4848,
        heroic = {5291, 5292, 5066, 5290},
    },
    [348] = { -- Magisters' Terrace
        661,
        heroic = {682},
        zones = {349},
    },
    [272] = { -- Mana-Tombs
        651,
        heroic = {671},
    },
    [280] = {640, zones = {281}}, -- Maraudon
    [453] = { -- Mogu'shan Palace
        6755,
        heroic = {6478, 6756, 6713, 6736, 6715},
        zones = {454, 455},
    },
    [274] = { -- Old Hillsbrad Foothills
        652,
        heroic = {673},
    },
    [184] = { -- Pit of Saron
        4517,
        heroic = {4520, 4524, 4525},
    },
    [213] = {629}, -- Ragefire Chasm
    [300] = {636}, -- Razorfen Downs
    [301] = {635}, -- Razorfen Kraul
    [431] = { -- Scarlet Halls
        7413,
        heroic = {6760, 6684, 6427},
        zones = {432},
    },
    [435] = { -- Scarlet Monastery
        637, 6946,
        heroic = {6761, 6929, 6928},
        zones = {436},
    },
    [476] = { -- Scholomance
        645,
        heroic = {6762, 6531, 6394, 6396, 6821, 6715},
        zones = {477, 478, 479},
    },
    [275] = {}, -- ScholomanceOLD
    [258] = { -- Sethekk Halls
        653,
        heroic = {674},
        zones = {259},
    },
    [443] = { -- Shado-Pan Monastery
        6469,
        heroic = {6470, 6471, 6477, 6472, 6715},
        zones = {444, 445, 446},
    },
    [260] = { -- Shadow Labyrinth
        654,
        heroic = {675},
    },
    [310] = { -- Shadowfang Keep
        631,
        heroic = {5505, 5093, 5503, 5504},
        zones = {311, 312, 313, 314, 315, 316},
    },
    [457] = { -- Siege of Niuzao Temple
        heroic = {6763, 6485, 6822, 6688, 6715},
        zones = {458, 459},
    },
    [439] = { -- Stormstout Brewery
        6457, 6400, 6402,
        heroic = {6456, 6420, 6089, 6715},
        zones = {440, 441, 442},
    },
    [317] = {646, zones = {318}}, -- Stratholme
    [429] = { -- Temple of the Jade Serpent
        6757,
        heroic = {6758, 6475, 6460, 6671, 6715},
        zones = {430},
    },
    [269] = { -- The Arcatraz
        660,
        heroic = {681},
        zones = {270, 271},
    },
    [273] = { -- The Black Morass
        655,
        heroic = {676},
    },
    [261] = { -- The Blood Furnace
        648,
        heroic = {668},
    },
    [266] = { -- The Botanica
        659,
        heroic = {680},
    },
    [130] = { -- The Culling of Stratholme
        479,
        heroic = {500, 1872, 1817},
        zones = {131},
    },
    [291] = { -- The Deadmines
        628,
        heroic = {5083, 5370, 5369, 5368, 5367, 5366, 5371},
        zones = {292},
    },
    [183] = { -- The Forge of Souls
        4516,
        heroic = {4519, 4522, 4523},
    },
    [267] = { -- The Mechanar
        658,
        heroic = {679},
        zones = {268},
    },
    [370] = { -- The Nexus
        478,
        heroic = {490, 2037, 2036, 2150},
    },
    [142] = { -- The Oculus
        487,
        heroic = {498, 1868, 1871, 2044, 2045, 2046},
        zones = {143, 144, 145, 146},
    },
    [246] = { -- The Shattered Halls
        657,
        heroic = {678},
    },
    [265] = { -- The Slave Pens
        649,
        heroic = {669},
    },
    [263] = { -- The Steamvault
        656,
        heroic = {677},
        zones = {264},
    },
    [225] = {633}, -- The Stockade
    [324] = { -- The Stonecore
        4846,
        heroic = {5063, 5287},
    },
    [220] = {641}, -- The Temple of Atal'Hakkar
    [262] = { -- The Underbog
        650,
        heroic = {670},
    },
    [168] = { -- The Violet Hold
        483,
        heroic = {494, 2153, 1865, 2041, 1816},
    },
    [325] = { -- The Vortex Pinnacle
        4847,
        heroic = {5289, 5064, 5288},
    },
    [322] = { -- Throne of the Tides
        4839,
        heroic = {5061, 5285, 5286},
        zones = {323},
    },
    [171] = { -- Trial of the Champion
        is_alliance and 4296 or 3778,
        heroic = {is_alliance and 4298 or 4297, 3802, 3803, 3804},
    },
    [230] = {638, zones = {231}}, -- Uldaman
    [133] = { -- Utgarde Keep
        477,
        heroic = {489, 1919},
        zones = {134, 135},
    },
    [136] = { -- Utgarde Pinnacle
        488,
        heroic = {499, 1873, 2043, 2156, 2157},
        zones = {137},
    },
    [279] = {630}, -- Wailing Caverns
    [398] = { -- Well of Eternity
        heroic = {6118, 6127, 6070}
    },
    [333] = { -- Zul'Aman
        5769, 5858, 5760, 5761, 5750,
        unavailable = {691},
    },
    [219] = {639}, -- Zul'Farrak
    [337] = { -- Zul'Gurub
        5768, 5765, 5743, 5762, 5759, 5744,
        unavailable = {688, 560, 957},
    },
}
battlegrounds = {
    [91] = {1167, 226}, -- Alterac Valley
    [93] = {1169}, -- Arathi Basin
    [519] = {}, -- Deepwind Gorge
    [397] = {1171, 587, 1258, 211}, -- Eye of the Storm
    [169] = {3857, 3845}, -- Isle of Conquest
    [423] = {7106}, -- Silvershard Mines
    [128] = {2194}, -- Strand of the Ancients
    [449] = {6981}, -- Temple of Kotmogu
    [275] = {5258}, -- The Battle for Gilneas
    [206] = {5223}, -- Twin Peaks
    [92] = {1172, 1259}, -- Warsong Gulch
}
zones = {
    [204] = {4825, 4975, 5452, is_alliance and 5318 or 5319}, -- Abyssal Depths
    [327] = {687, 689, 7934}, -- Ahn'Qiraj: The Fallen Kingdom (the open-world thing)
    [468] = {}, -- Ammen Vale
    [14] = {761}, -- Arathi Highlands
    [63] = {845, 4827}, -- Ashenvale
    [76] = {852, 5448, 5546, 5547}, -- Azshara
    [97] = {860, zones = {98, 99}}, -- Azuremyst Isle
    [15] = {765, 4827}, -- Badlands
    [282] = {}, -- Baradin Hold
    [250] = {643, 1307, 2188, zones = {251, 252, 253, 254, 255}}, -- Blackrock Spire
    [105] = {865, 1276}, -- Blade's Edge Mountains
    [17] = {766}, -- Blasted Lands
    [106] = {861}, -- Bloodmyst Isle
    [114] = {1264, 561}, -- Borean Tundra
    [36] = {775}, -- Burning Steppes
    [462] = {}, -- Camp Narache
    [427] = {zones = {428}}, -- Coldridge Valley
    [127] = {1457}, -- Crystalsong Forest
    [125] = {1956, 545, zones = {126}}, -- Dalaran
    [407] = {
        6020, 6021, 6022, 6023, 6026, 6027, 6028, 6029, is_alliance and 6030 or 6031, 6032, 6025, 6332, 9252,
        zones = {408},
    }, -- Darkmoon Island
    [62] = {844, 4827}, -- Darkshore
    [89] = {6584}, -- Darnassus
    [42] = {777, zones = {43, 44, 45, 46}}, -- Deadwind Pass
    [465] = {zones = {466}}, -- Deathknell
    [207] = {4864, 5445, 5446, 5447, 5449, zones = {208, 209}}, -- Deepholm
    [66] = {848, zones = {67, 68}}, -- Desolace
    [115] = {1265, 1277, 547}, -- Dragonblight
    [422] = {6978, 6545, 7312, 7313, 7314, 7316}, -- Dread Wastes
    [27] = {627, zones = {28, 29, 30, 31}}, -- Dun Morogh
    [1] = {728, 4827, zones = {2, 3, 4, 5, 6}}, -- Durotar
    [47] = {778}, -- Duskwood
    [70] = {850}, -- Dustwallow Marsh
    [23] = {771, 5442, zones = {24}}, -- Eastern Plaguelands
    [463] = {zones = {464}}, -- Echo Isles
    [37] = {776, zones = {38, 39, 40, 41}}, -- Elwynn Forest
    [94] = {859}, -- Eversong Woods
    [77] = {853}, -- Felwood
    [69] = {849}, -- Feralas
    [95] = {858, zones = {96}}, -- Ghostlands
    [202] = {}, -- Gilneas City
    -- [217] = {}, -- Gilneas
    [116] = {1266, 1596}, -- Grizzly Hills
    [100] = {862}, -- Hellfire Peninsula
    [25] = {772, 4827, 5365, 5364}, -- Hillsbrad Foothills
    [117] = {1263}, -- Howling Fjord
    [170] = {}, -- Hrothgar's Landing
    [118] = { -- Icecrown
        1270,
        -- the tournament
        2756, 2772, 2836, 2773, 3736,
    },
    [87] = {6584}, -- Ironforge
    [507] = {}, -- Isle of Giants
    [122] = {868}, -- Isle of Quel'Danas
    [504] = { -- Isle of Thunder
        8121, 8101, 8104, 8105, 8106, 8107, 8108, 8110, 8111, 8112, 8114, 8115, 8116, 8117, 8118, 8119, 8120, 8212,
        zones = {505, 506},
    },
    [201] = {4825, 4975, 5452, is_alliance and 5318 or 5319}, -- Kelp'thar Forest
    [194] = {zones = {195, 196, 197}}, -- Kezan
    [418] = {
        6975, 6547, 7518, is_alliance and 7928 or 7929, 7287, 7614, 7274,
        zones = {419, 420, 421},
    }, -- Krasarang Wilds
    [379] = { -- Kun-Lai Summit
        6976, 6480, 7386, 7286,
        zones = {380, 381, 382, 383, 384, 385, 386, 387},
    },
    [48] = {779, 4827}, -- Loch Modan
    [338] = {5859, 5866, 5867, 5870, 5871, 5872, 5873, 5874, 5879}, -- Molten Front
    [80] = {855}, -- Moonglade
    [198] = {4863, 4959, 5483, 5859, 5860, 5861, 5862, 5864, 5865, 5868, 5869}, -- Mount Hyjal
    [7] = {736, zones = {8, 9}}, -- Mulgore
    [107] = {866, 939, 1576}, -- Nagrand
    [109] = {843, 545}, -- Netherstorm
    [469] = {zones = {470}}, -- New Tinkertown
    [10] = {750, zones = {11}}, -- Northern Barrens
    [50] = {781, 940}, -- Northern Stranglethorn
    [425] = {zones = {426}}, -- Northshire
    [85] = {6621, zones = {86}}, -- Orgrimmar
    [124] = {}, -- Plaguelands: The Scarlet Enclave
    [49] = {780}, -- Redridge Mountains
    [218] = {}, -- Ruins of Gilneas City
    [217] = {}, -- Ruins of Gilneas
    [32] = {774, zones = {33, 34, 35}}, -- Searing Gorge
    [460] = {}, -- Shadowglen
    [104] = {864}, -- Shadowmoon Valley
    [111] = {1165, 903}, -- Shattrath City
    [205] = {4825, 4975, 5452, is_alliance and 5318 or 5319}, -- Shimmering Expanse
    [119] = {1268, 938, 961, 962, 952}, -- Sholazar Basin
    -- [905] = {}, -- Shrine of Seven Stars
    -- [903] = {}, -- Shrine of Two Moons
    [81] = {856, zones = {82}}, -- Silithus
    [110] = {6621}, -- Silvermoon City
    [21] = {769, 4827}, -- Silverpine Forest
    [199] = {4996, 4827}, -- Southern Barrens
    [65] = {847}, -- Stonetalon Mountains
    [84] = {6584}, -- Stormwind City
    [224] = {}, -- Stranglethorn Vale
    [467] = {}, -- Sunstrider Isle
    [51] = {782}, -- Swamp of Sorrows
    [71] = {851, 4827, zones = {72, 73, 74, 75}}, -- Tanaris
    [57] = {842, zones = {58, 59, 60, 61}}, -- Teldrassil
    [108] = {867, 1275}, -- Terokkar Forest
    [210] = {4995, 389, 396, 4827}, -- The Cape of Stranglethorn
    [103] = {6584}, -- The Exodar
    [26] = {773}, -- The Hinterlands
    [371] = {6351, 6550, 7289, 7290, 7291, 7381, zones = {372, 373, 374, 375}}, -- The Jade Forest
    -- [682] = {}, -- The Lost Isles
    -- [751] = {}, -- The Maelstrom
    [120] = {1269, 1428}, -- The Storm Peaks
    [433] = {7533, 7534, 8030, 7535, 7536, 8325, zones = {434}}, -- The Veiled Stair
    [378] = {}, -- The Wandering Isle
    [64] = {846, 4827}, -- Thousand Needles
    [88] = {6621}, -- Thunder Bluff
    [554] = { -- Timeless Isle
        8725, 8726, 8728, 8712, 8714, 8715, 8723, 8724, 8730, 8722, 8729, 8727, 8743, 8519, 8716, 8717, 8718, 8719,
        8720, 8721, 8535, 8533,
        zones = {555},
    },
    [18] = {768, zones = {19, 20}}, -- Tirisfal Glades
    [245] = {is_alliance and 5718 or 5719}, -- Tol Barad Peninsula
    [244] = {4874, is_alliance and 5489 or 5490, is_alliance and 5718 or 5719}, -- Tol Barad
    [388] = {6977, 7299, 7298, 7307, 7308, 7309, 7288, zones = {389}}, -- Townlong Steppes
    [241] = {4866, 5451, 4960, 4958}, -- Twilight Highlands
    [249] = {4865, 5317, 4888, 4961}, -- Uldum
    [78] = {854, zones = {79}}, -- Un'Goro Crater
    [90] = {6621}, -- Undercity
    [390] = { -- Vale of Eternal Blossoms
        6979, 6546, 7317, 7318, 7319, 7322, 7323, 7324,
        unavailable = {7315},
        zones = {391, 392, 393, 394, 395, 396},
    },
    [376] = { -- Valley of the Four Winds
        6969, 6544, 6551, 7292, 7293, 7294, 7295, 7325, 7502, 6517, 7296,
        zones = {377},
    },
    [461] = {}, -- Valley of Trials
    [203] = {4825, 4975, 5452, is_alliance and 5318 or 5319}, -- Vashj'ir
    [22] = {770}, -- Western Plaguelands
    [52] = {802, 4827, zones = {53, 54, 55}}, -- Westfall
    [56] = {841}, -- Wetlands
    [123] = {1752, 2199, 1717, 1751, 1755, 1727, 1723}, -- Wintergrasp
    [83] = {857, 5443}, -- Winterspring
    [102] = {863, 893}, -- Zangarmarsh
    [121] = {1267, 1576, 1596}, -- Zul'Drak
    -- Draenor:
    [588] = {9102, 9105, 9106, 9216, 9218, 9219, 9220, 9222, 9228, zones = {589}}, -- Ashran
    [525] = { -- Frostfire Ridge
        8937, 9533, 9534, 9537, 9536, 9535, 9710, 9711,
        -- zones = {526, 527, 528, 529, 530, 531, 532, 533},
    },
    [543] = { -- Gorgrond
        9607,
        -- zones = {544, 545, 546, 547, 548, 549}
    },
    [550] = { -- Nagrand
        9615,
        -- zones = {551, 552, 553},
    },
    [539] = { -- Shadowmoon Valley
        9433, 9434, 9432, 9436, 9435, 9437, 9483, 9479, 9481,
        -- zones = {540, 541},
    },
    [542] = {9605}, -- Spires of Arak
    [535] = { -- Talador
        9674,
        -- zones = {536, 537, 538},
    },
    [534] = {10261, 10259, 10069, 10061, 10071, 10052}, -- Tanaan Jungle
    -- Draenor garrisons:
    [585] = {zones = {586, 587}}, -- Frostwall (Horde)
    [579] = {zones = {580, 581}}, -- Lunarfall (Alliance)
    -- Draenor capitals:
    [622] = {}, -- Stormshield
    [624] = {}, -- Warspear
}
if is_alliance then
    tinsert(zones[116], 2016) -- Grizzly Hills
    tinsert(zones[123], 1737) -- Wintergrasp
    tinsert(zones[83], 3356) -- Winterspring
    extend(zones[241], {5320, 5481}) -- Twilight Highlands
    tinsert(zones[62], 5453) -- Darkshore
    extend(zones[84], {388, 545}) -- Stormwind City
    tinsert(zones[89], 388) -- Darnassus
    extend(zones[87], {388, 545}) -- Ironforge
    tinsert(zones[103], 388) -- Exodar
    extend(zones[85], {604, 610, 614}) -- Orgrammar
    extend(zones[88], {604, 611, 614}) -- Thunder Bluff
    extend(zones[90], {604, 612, 614}) -- Undercity
    extend(zones[110], {604, 613, 614}) -- Silvermoon City
    extend(zones[118], {3676, 2782}) -- Icecrown
    extend(zones[588], {9104, 9214, 9225, 9256, 9408, 9714}) -- Ashran
    tinsert(zones[525], 9530) -- Frostfire
    tinsert(zones[535], 8920) -- Talador
    extend(zones[539], {8845, 9528, 9602}) -- Shadowmoon
    tinsert(zones[543], 8923) -- Gorgrond
    extend(zones[534], {10067, 10068, 10072}) -- Tanaan
    tinsert(zones[550], 8927) -- Nagrand
    -- bgs
    tinsert(battlegrounds[91], 907) -- Alterac Valley
    tinsert(battlegrounds[93], 907) -- Arathi Basin
    tinsert(battlegrounds[92], 907) -- Warsong Gulch
    tinsert(battlegrounds[169], 3846) -- Isle of Conquest
end
if is_horde then
    tinsert(zones[76], 5454) -- Azshara
    tinsert(zones[116], 2017) -- Grizzly Hills
    tinsert(zones[123], 2476) -- Wintergrasp
    extend(zones[241], {5482, 5321}) -- Twilight Highlands
    extend(zones[85], {1006, 545}) -- Orgrimmar
    tinsert(zones[88], 1006) -- Thunder Bluff
    extend(zones[90], {1006, 545}) -- Undercity
    tinsert(zones[110], 1006) -- Silvermoon City
    extend(zones[84], {603, 615, 619}) -- Stormwind City
    extend(zones[87], {603, 616, 619}) -- Ironforge
    extend(zones[89], {603, 617, 619}) -- Darnassus
    extend(zones[103], {603, 618, 619}) -- Exodar
    extend(zones[118], {3677, 2788}) -- Icecrown
    extend(zones[588], {9103, 9215, 9217, 9224, 9257, 9715}) -- Ashran
    extend(zones[525], {8671, 9529, 9531, 9606}) -- Frostfire
    tinsert(zones[535], 8919) -- Talador
    tinsert(zones[543], 8924) -- Gorgrond
    extend(zones[534], {10074, 10075, 10265}) -- Tanaan
    tinsert(zones[550], 8928) -- Nagrand
    -- bgs
    tinsert(battlegrounds[91], 714) -- Alterac Valley
    tinsert(battlegrounds[93], 714) -- Arathi Basin
    tinsert(battlegrounds[92], 714) -- Warsong Gulch
    tinsert(battlegrounds[169], 4176) -- Isle of Conquest
end

-- These are the "you've done X quests", or "you've completed this storyline" ones
quests = {
    -- regular zones
    [14] = 4896, -- Arathi Highlands
    [15] = 4900, -- Badlands
    [105] = 1193, -- Blade's Edge Mountains
    [17] = 4909, -- Blasted Lands
    [36] = 4901, -- Burning Steppes
    [207] = 4871, -- Deepholm
    [66] = 4930, -- Desolace
    [422] = 6540, -- Dread Wastes
    [23] = 4892, -- Eastern Plaguelands
    [77] = 4931, -- Felwood
    [118] = 40, -- Icecrown
    [504] = 8099, -- Isle of Thunder
    [198] = 4870, -- Mount Hyjal
    [109] = 1194, -- Netherstorm
    [50] = 4906, -- Northern Stranglethorn
    [32] = 4910, -- Searing Gorge
    [104] = 1195, -- Shadowmoon Valley
    [119] = 39, -- Sholazar Basin
    [81] = 4934, -- Silithus
    [51] = 4904, -- Swamp of Sorrows
    [71] = 4935, -- Tanaris
    [210] = 4905, -- The Cape of Stranglethorn
    [26] = 4897, -- The Hinterlands
    [120] = 38, -- The Storm Peaks
    [64] = 4938, -- Thousand Needles
    [388] = 6539, -- Townlong Steppes
    [249] = 4872, -- Uldum
    [78] = 4939, -- Un'Goro Crater
    [376] = 6301, -- Valley of the Four Winds
    [22] = 4893, -- Western Plaguelands
    [83] = 4940, -- Winterspring
    [102] = 1190, -- Zangarmarsh
    [121] = 36, -- Zul'Drak
}
if is_alliance then
    -- quests
    quests[204] = 4869 -- Abyssal Depths
    quests[63] = 4925 -- Ashenvale
    quests[106] = 4926 -- Bloodmyst Isle
    quests[114] = 33 -- Borean Tundra
    quests[62] = 4928 -- Darkshore
    quests[115] = 35 -- Dragonblight
    quests[47] = 4903 -- Duskwood
    quests[70] = 4929 -- Dustwallow Marsh
    quests[69] = 4932 -- Feralas
    quests[116] = 37 -- Grizzly Hills
    quests[100] = 1189 -- Hellfire Peninsula
    quests[117] = 34 -- Howling Fjord
    quests[371] = 6300-- Jade Forest
    quests[201] = 4869 -- Kelp'thar Forest
    quests[418] = 6535 -- Krasarang Wilds
    quests[379] = 6537 -- Kun-Lai Summit
    quests[48] = 4899 -- Loch Modan
    quests[107] = 1192 -- Nagrand
    quests[49] = 4902 -- Redridge Mountains
    quests[205] = 4869 -- Shimmering Expanse
    quests[199] = 4937 -- Southern Barrens
    quests[108] = 1191 -- Terokkar Forest
    quests[241] = 4873 -- Twilight Highlands
    quests[203] = 4869 -- Vashj'ir
    quests[52] = 4903 -- Westfall
    quests[56] = 4899 -- Wetlands
end
if is_horde then
    -- quests
    quests[204] = 4982 -- Abyssal Depths
    quests[63] = 4976 -- Ashenvale
    quests[76] = 4927 -- Azshara
    quests[114] = 1358 -- Borean Tundra
    quests[115] = 1359 -- Dragonblight
    quests[70] = 4978 -- Dustwallow Marsh
    quests[69] = 4979 -- Feralas
    quests[95] = 4908 -- Ghostlands
    quests[116] = 1357 -- Grizzly Hills
    quests[100] = 1271 -- Hellfire Peninsula
    quests[25] = 4895 -- Hillsbrad Foothills
    quests[117] = 1356 -- Howling Fjord
    quests[371] = 6534 -- Jade Forest
    quests[201] = 4982 -- Kelp'thar Forest
    quests[418] = 6536 -- Krasarang Wilds
    quests[379] = 6538 -- Kun-Lai Summit
    quests[107] = 1273 -- Nagrand
    quests[10] = 4933 -- Northern Barrens
    quests[205] = 4982 -- Shimmering Expanse
    quests[21] = 4894 -- Silverpine Forest
    quests[199] = 4981 -- Southern Barrens
    quests[65] = 4980 -- Stonetalon Mountains
    quests[108] = 1272 -- Terokkar Forest
    quests[241] = 5501 -- Twilight Highlands
    quests[203] = 4982 -- Vashj'ir
end

-- assemble!
for zoneid,aid in pairs(quests) do
    tinsert(zones[zoneid], 1, aid)
end

-- these are the ones we'll pop up only if there's a trigger, or a direct request
skills = {
    [PROFESSIONS_COOKING] = {
        1563, 5845,
        zones = {
            [504] = {1998, is_alliance and 1782 or 1783, 3217, 3296}, -- Dalaran
            [481] = {906}, -- Shattrath City
        },
    },
    [PROFESSIONS_FISHING] = {
        1516, 5478, 5479, 5851,
        zones = {
            [504] = {2096, 1958}, -- Dalaran
            [673] = {306}, -- The Cape of Stranglethorn
            [37] = {306}, -- Northern Stranglethorn
            [341] = {1837}, -- Ironforge
            [321] = {1836, 150}, -- Orgrimmar
            [780] = {144}, -- Serpentshrine Cavern
            [481] = {905}, -- Shattrath City
            [301] = {150}, -- Stormwind City
            [478] = {905, 726}, -- Terokkar Forest
            -- the BG ones
            [401] = {1785}, -- Alterac Valley
            [461] = {1785}, -- Arathi Basin
            [813] = {1785}, -- Eye of the Storm
            [512] = {1785}, -- Strand of the Ancients
            [443] = {1785}, -- Warsong Gulch
        },
        unavailable = {560}, -- ZG woo 
    },
}
if is_alliance then
    skills[PROFESSIONS_COOKING].zones[381] = {5842} -- Darnassus
    skills[PROFESSIONS_COOKING].zones[341] = {5841} -- Ironforge
    skills[PROFESSIONS_COOKING].zones[301] = {5474} -- Stormwind
    skills[PROFESSIONS_COOKING].zones[381] = {5848} -- Darnassus
    tinsert(skills[PROFESSIONS_FISHING].zones[341], 5847) -- Ironforge
    tinsert(skills[PROFESSIONS_FISHING].zones[301], 5476) -- Stormwind
end
if is_horde then
    skills[PROFESSIONS_COOKING].zones[321] = {5475} -- Orgrimmar
    skills[PROFESSIONS_COOKING].zones[362] = {5843} -- Thunder Bluff
    skills[PROFESSIONS_COOKING].zones[382] = {5844} -- Undercity
    tinsert(skills[PROFESSIONS_FISHING].zones[321], 5477) -- Orgrimmar
    skills[PROFESSIONS_FISHING].zones[362] = {5849} -- Thunder Bluff
    skills[PROFESSIONS_FISHING].zones[382] = {5850} -- Undercity
end

pvp = {238, 245, is_alliance and 246 or 1005, 247, 229, 227, 231, 1785}
