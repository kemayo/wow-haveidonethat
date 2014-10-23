local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")
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
    if IsAddOnLoaded("Blizzard_AchievementUI") then
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
            return GetMapNameByID(a.id) < GetMapNameByID(b.id)
        end

        local function mapid_category_builder(name, type, ids)
            local mapid_categories = {}
            for mapid, ids in pairs(ids) do
                if #ids > 0 or ids.normal or ids.heroic or ids.size10 or ids.size25 or ids.lfr then
                    tinsert(mapid_categories, {id = mapid, type = type, label = GetMapNameByID(mapid)})
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
            PlaySound("igCharacterInfoTab")
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

    --fix terrain phased zones with multiple IDs
    local zone_overrides = {
        [683] = 606, -- hyjal_terrain1
        [748] = 720, -- uldum_terrain1
        [770] = 700, -- twilight highlands
        [905] = 811, -- vale of eternal blossoms
        [903] = 811, -- vale of eternal blossoms
    }
    function GetCanonicalZoneID(zoneid)
        return zone_overrides[zoneid] or zoneid
    end

    local function get_achievements_by_zoneid(zoneid)
        return zones[zoneid] or scenarios[zoneid] or dungeons[zoneid] or raids[zoneid] or battlegrounds[zoneid]
    end
    local to_suggest = {}
    function update_achievements()
        wipe(to_suggest)
        if frame.suggest_type == "smart" then
            zoneid = GetCanonicalZoneID(GetCurrentMapAreaID())
            local suggestions = get_achievements_by_zoneid(zoneid)
            local instance_type, size, variant = mod:WorkOutInstanceType()

            local to_suggest = suggestion_handler(to_suggest, suggestions, size, variant)

            local trade = GetTradeSkillLine()
            if trade and skills[trade] then
                prepend(to_suggest, skills[trade])
            end
            for skillname,skillsuggestions in pairs(skills) do
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

        local backdrop = CreateFrame("Frame", nil, frame)
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

        sidebar = CreateFrame("Frame", frame:GetName().."Sidebar", AchievementFrame)
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
    [878] = { -- A Brewing Storm
        7252, 7258, 7257, 7261,
        heroic = {8310},
    },
    [912] = {7988, 7989, 7990, 7991, 7992, 7993}, -- A Little Patience
    [899] = {7271, 7273, 7272}, -- Arena of Annihilation
    [883] = {8016, 8017}, -- Assault on Zan'vess
    [940] = { -- Battle on the High Seas
        8314, 8347,
        heroic = {8364},
    },
    [939] = { -- Blood in the Snow
        8316, 8329, 8330,
        heroic = {8312},
    },
    [884] = {6923, 6931, 6930, }, -- Brewmoon Festival
    [955] = {8410, 8518}, -- Celestial Tournament
    [900] = { -- Crypt of Forgotten Kings
        7522, 7276, 7275, 8368,
        heroic = {8311},
    },
    [914] = {8009, 7987, 7986}, -- Dagger in the Dark
    [937] = { -- Dark Heart of Pandaria
        8317, 8319,
        heroic = {8318},
    },
    [880] = {7265, 7267, 7266}, -- Greenstone Village
    [938] = {8294, 8295}, -- The Secrets of Ragefire
    [882] = {7249, 7231, 7232, 7239, 7248}, -- Unga Ingoo
}
if is_alliance then
    scenarios[911] = {8010, 8011, 8012} -- Lion's Landing (A)
    scenarios[906] = { -- Theramore's Fall (A)
        7523, 7526, 7527,
        unavailable = {7467},
    }
end
if is_horde then
    scenarios[920] = {8013, 8014, 8015} -- Domination Point (H)
    scenarios[851] = { -- Theramore's Fall (H)
        7524, 7529, 7530,
        unavailable = {7468},
    }
end
raids = {
    [766] = {687, 7934}, -- Ahn'Qiraj (the raid)
    [796] = {697}, -- Black Temple
    [754] = { -- Blackwing Descent
        4842, 5306, 5307, 5308, 5309, 4849, 5310,
        heroic = {5094, 5107, 5108, 5109, 5115, 5116},
    },
    [755] = {685, 7934}, -- Blackwing Lair
    [824] = { -- Dragon Soul
        6106, 6107,
        normal = {6177, 6174, 6128, 6129, 6175, 6084, 6105, 6133, 6180},
        heroic = {6109, 6110, 6111, 6112, 6113, 6114, 6115, 6116},
    },
    [800] = { -- Firelands
        5802, 5828, 5855, 5821, 5810, 5813, 5829, 5830, 5799, 5855,
        heroic = {5803, 5807, 5808, 5806, 5809, 5805, 5804},
    },
    [776] = {692}, -- Gruul's Lair
    [897] = { -- Heart of Fear
        6718, 6845,
        normal = {6936, 6518, 6683, 6553, 6937, 6922},
        heroic = {6729, 6726, 6727, 6730, 6725, 6728},
    },
    [775] = {695}, -- Hyjal Summit
    [604] = { -- Icecrown Citadel
        size10 = {
            4532, 4580, 4601, 4534, 4538, 4577, 4535, 4536, 4537, 4578, 4581, 4539, 4579, 4582,
            heroic = {4636},
        },
        size25 = {
            4608, 4620, 4621, 4610, 4614, 4615, 4611, 4612, 4613, 4616, 4622, 4618, 4619, 4617,
            heroic = {4637},
        },
    },
    [799] = {690, 8293}, -- Karazhan
    [779] = {693}, -- Magtheridon's Lair
    [896] = { -- Mogu'shan Vaults
        6458, 6844,
        normal = {6674, 6687, 6823, 6455, 7056, 6686},
        heroic = {6723, 6720, 6722, 6721, 6719, 6724},
    },
    [696] = {686, 7934}, -- Molten Core
    [535] = { -- Naxxramas
        7934,
        size10 = {2146, 576, 578, 572, 1856, 2176, 2178, 2180, 568, 1996, 1997, 1858, 564, 2182, 2184, 566, 574, 562},
        size25 = {579, 565, 577, 575, 2177, 563, 567, 1857, 569, 573, 1859, 2139, 2181, 2183, 2185, 2147, 2140, 2179},
        unavailable = {2186, 2187},
    },
    [718] = { -- Onyxia's Lair
        size10 = {4396, 4402, 4403, 4404},
        unavailable = {684},
    },
    [717] = {689}, -- Ruins of Ahn'Qiraj
    [780] = {694, 8293}, -- Serpentshrine Cavern
    [953] = { -- Siege of Orgrimmar
        8458, 8459, 8461, 8462,
        normal = {
            8679, -- completion
            9454, -- challenges meta
            8536, 8528, 8532, 8521, 8530, 8520, 8453, 8448, 8538, 8543, 8529, 8527, 8531, 8537,
        },
        heroic = {
            8463, 8465, 8466, 8467, 8468, 8469, 8470, 8471, 8472, 8478, 8479, 8480, 8481, 8482,
        },
    },
    [789] = {698}, -- Sunwell Plateau
    [782] = {696, 8293}, -- Tempest Keep
    [886] = { -- Terrace of Endless Spring
        6689,
        normal = {6824, 6717, 6825, 6933},
        heroic = {6733, 6731, 6734, 6732},
    },
    [758] = { -- The Bastion of Twilight
        4850, 5300, 4852, 5311, 5312,
        heroic = {5118, 5117, 5119, 5120, 5121},
    },
    [527] = { -- The Eye of Eternity
        size10 = {622, 1874, 2148, 1869},
        size25 = {623, 1875, 2149, 1870},
    },
    [531] = { -- The Obsidian Sanctum
        size10 = {1876, 2047, 2049, 2050, 2051, 624},
        size25 = {625, 2048, 2052, 2053, 2054, 1877},
    },
    [609] = { -- The Ruby Sanctum
        size10 = {
            4817,
            heroic = {4818},
        },
        size25 = {
            4815,
            heroic = {4816},
        },
    },
    [773] = { -- Throne of the Four Winds
        4851, 5304, 5305,
        heroic = {5122, 5123, },
    },
    [930] = { -- Throne of Thunder
        8070, 8071, 8069, 8072,
        normal = {8089, 8037, 8087, 8090, 8094, 8073, 8082, 8098, 8081, 8086},
        heroic = {8124, 8067},
    },
    [543] = { -- Trial of the Crusader
        size10 = {
            3917, 3936, 3798, 3799, 3800, 3996, 3797,
            heroic = {3918},
        },
        size25 = {
            3916, 3937, 3815, 3816, 3997, 3813,
            heroic = {3812},
        },
        unavailable = {3808, 3817},
    },
    [529] = { -- Ulduar
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
    },
    [532] = { -- Vault of Archavon
        size10 = {1722, 3136, 3836, 4016},
        size25 = {1721, 3137, 3837, 4017},
    },
}
dungeons = {
    [522] = { -- Ahn'kahet: The Old Kingdom
        481,
        heroic = {492, 2056, 1862, 2038}
    },
    [722] = { -- Auchenai Crypts
        666,
        heroic = {672},
    },
    [533] = { -- Azjol-Nerub
        480,
        heroic = {491, 1860, 1296, 1297},
    },
    [688] = {632}, -- Blackfathom Deeps
    [753] = { -- Blackrock Caverns
        4833,
        heroic = {5282, 5284, 5281, 5060, 5283},
    },
    [704] = {642}, -- Blackrock Depths
    [699] = {644}, -- Dire Maul
    [534] = { -- Drak'Tharon Keep
        482,
        heroic = {493, 2039, 2057, 2151},
    },
    [820] = { -- End Time
        heroic = {6117, 5995, 6130},
    },
    [875] = { -- Gate of the Setting Sun
        6945,
        heroic = {6759, 6479, 6476, 6715},
    },
    [757] = { -- Grim Batol
        4840,
        heroic = {5298, 5062, 5297},
    },
    [691] = {634}, -- Gnomeregan
    [530] = { -- Gundrak
        484,
        heroic = {495, 2040, 2152, 1864, 2058},
    },
    [525] = { -- Halls of Lightning
        486,
        heroic = {497, 2042, 1867, 1834},
    },
    [759] = { -- Halls of Origination
        4841,
        heroic = {5296, 5065, 5293, 5294, 5295}
    },
    [603] = { -- Halls of Reflection
        4518,
        heroic = {4521, 4526},
    },
    [526] = { -- Halls of Stone
        485,
        heroic = {496, 1866, 2154, 2155},
    },
    [797] = { -- Hellfire Ramparts
        647,
        heroic = {667}
    },
    [819] = { -- Hour of Twilight
        heroic = {6119, 6132, 6084},
    },
    [747] = { -- Lost City of the Tol'vir
        4848,
        heroic = {5291, 5292, 5066, 5290},
    },
    [798] = { -- Magisters' Terrace
        661,
        heroic = {682},
    },
    [732] = { -- Mana-Tombs
        651,
        heroic = {671},
    },
    [750] = {640}, -- Maraudon
    [885] = { -- Mogu'shan Palace
        6755,
        heroic = {6478, 6756, 6713, 6736, 6715},
    },
    [734] = { -- Old Hillsbrad Foothills
        652,
        heroic = {673},
    },
    [602] = { -- Pit of Saron
        4517,
        heroic = {4520, 4524, 4525},
    },
    [680] = {629}, -- Ragefire Chasm
    [760] = {636}, -- Razorfen Downs
    [761] = {635}, -- Razorfen Kraul
    [871] = { -- Scarlet Halls
        7413,
        heroic = {6760, 6684, 6427},
    },
    [874] = { -- Scarlet Monastery
        637, 6946,
        heroic = {6761, 6929, 6928},
    },
    [898] = { -- Scholomance
        645,
        heroic = {6762, 6531, 6394, 6396, 6821, 6715},
    },
    [763] = {}, -- ScholomanceOLD
    [723] = { -- Sethekk Halls
        653,
        heroic = {674},
    },
    [877] = { -- Shado-Pan Monastery
        6469,
        heroic = {6470, 6471, 6477, 6472, 6715},
    },
    [724] = { -- Shadow Labyrinth
        654,
        heroic = {675},
    },
    [764] = { -- Shadowfang Keep
        631,
        heroic = {5505, 5093, 5503, 5504},
    },
    [887] = { -- Siege of Niuzao Temple
        heroic = {6763, 6485, 6822, 6688, 6715},
    },
    [876] = { -- Stormstout Brewery
        6457, 6400, 6402,
        heroic = {6456, 6420, 6089, 6715},
    },
    [765] = {646}, -- Stratholme
    [867] = { -- Temple of the Jade Serpent
        6757,
        heroic = {6758, 6475, 6460, 6671, 6715},
    },
    [731] = { -- The Arcatraz
        660,
        heroic = {681},
    },
    [733] = { -- The Black Morass
        655,
        heroic = {676},
    },
    [725] = { -- The Blood Furnace
        648,
        heroic = {668},
    },
    [729] = { -- The Botanica
        659,
        heroic = {680},
    },
    [521] = { -- The Culling of Stratholme
        479,
        heroic = {500, 1872, 1817},
    },
    [756] = { -- The Deadmines
        628,
        heroic = {5083, 5370, 5369, 5368, 5367, 5366, 5371},
    },
    [601] = { -- The Forge of Souls
        4516,
        heroic = {4519, 4522, 4523},
    },
    [730] = { -- The Mechanar
        658,
        heroic = {679},
    },
    [803] = { -- The Nexus
        478,
        heroic = {490, 2037, 2036, 2150},
    },
    [528] = { -- The Oculus
        487,
        heroic = {498, 1868, 1871, 2044, 2045, 2046},
    },
    [710] = { -- The Shattered Halls
        657,
        heroic = {678},
    },
    [728] = { -- The Slave Pens
        649,
        heroic = {669},
    },
    [727] = { -- The Steamvault
        656,
        heroic = {677},
    },
    [690] = {633}, -- The Stockade
    [768] = { -- The Stonecore
        4846,
        heroic = {5063, 5287},
    },
    [536] = { -- The Violet Hold
        483,
        heroic = {494, 2153, 1865, 2041, 1816},
    },
    [769] = { -- The Vortex Pinnacle
        4847,
        heroic = {5289, 5064, 5288},
    },
    [767] = { -- Throne of the Tides
        4839,
        heroic = {5061, 5285, 5286},
    },
    [542] = { -- Trial of the Champion
        is_alliance and 4296 or 3778,
        heroic = {is_alliance and 4298 or 4297, 3802, 3803, 3804},
    },
    [692] = {638}, -- Uldaman
    [523] = { -- Utgarde Keep
        477,
        heroic = {489, 1919},
    },
    [524] = { -- Utgarde Pinnacle
        488,
        heroic = {499, 1873, 2043, 2156, 2157},
    },
    [749] = {630}, -- Wailing Caverns
    [816] = { -- Well of Eternity
        heroic = {6118, 6127, 6070}
    },
    [781] = { -- Zul'Aman
        5769, 5858, 5760, 5761, 5750,
        unavailable = {691},
    },
    [686] = {639}, -- Zul'Farrak
    [793] = { -- Zul'Gurub
        5768, 5765, 5743, 5762, 5759, 5744,
        unavailable = {688, 560, 957},
    },
}
battlegrounds = {
    [401] = {1167, 226}, -- Alterac Valley
    [461] = {1169}, -- Arathi Basin
    [935] = {}, -- Deepwind Gorge
    [813] = {1171, 587, 1258, 211}, -- Eye of the Storm
    [540] = {3857, 3845}, -- Isle of Conquest
    [860] = {7106}, -- Silvershard Mines
    [512] = {2194}, -- Strand of the Ancients
    [881] = {6981}, -- Temple of Kotmogu
    [736] = {5258}, -- The Battle for Gilneas
    [626] = {5223}, -- Twin Peaks
    [443] = {1172, 1259}, -- Warsong Gulch
}
zones = {
    [614] = {4825, 4975, 5452, is_alliance and 5318 or 5319}, -- Abyssal Depths
    [772] = {687, 689, 7934}, -- Ahn'Qiraj: The Fallen Kingdom (the open-world thing)
    [894] = {}, -- Ammen Vale
    [16] = {761}, -- Arathi Highlands
    [43] = {845, 4827}, -- Ashenvale
    [181] = {852, 5448, 5546, 5547}, -- Azshara
    [464] = {860}, -- Azuremyst Isle
    [17] = {765, 4827}, -- Badlands
    [752] = {}, -- Baradin Hold
    [721] = {643, 1307, 2188}, -- Blackrock Spire
    [475] = {865, 1276}, -- Blade's Edge Mountains
    [19] = {766}, -- Blasted Lands
    [476] = {861}, -- Bloodmyst Isle
    [486] = {1264, 561}, -- Borean Tundra
    [29] = {775}, -- Burning Steppes
    [890] = {}, -- Camp Narache
    [866] = {}, -- Coldridge Valley
    [510] = {1457}, -- Crystalsong Forest
    [504] = {1956, 545,}, -- Dalaran
    [823] = {6020, 6021, 6022, 6023, 6026, 6027, 6028, 6029, is_alliance and 6030 or 6031, 6032, 6025}, -- Darkmoon Island
    [42] = {844, 4827}, -- Darkshore
    [381] = {6584}, -- Darnassus
    [32] = {777}, -- Deadwind Pass
    [892] = {}, -- Deathknell
    [640] = {4864, 5445, 5446, 5447, 5449}, -- Deepholm
    [101] = {848}, -- Desolace
    [488] = {1265, 1277, 547}, -- Dragonblight
    [858] = {6978, 6545, 7312, 7313, 7314, 7316}, -- Dread Wastes
    [27] = {627}, -- Dun Morogh
    [4] = {728, 4827}, -- Durotar
    [34] = {778}, -- Duskwood
    [141] = {850}, -- Dustwallow Marsh
    [23] = {771, 5442}, -- Eastern Plaguelands
    [891] = {}, -- Echo Isles
    [30] = {776}, -- Elwynn Forest
    [462] = {859}, -- Eversong Woods
    [182] = {853}, -- Felwood
    [121] = {849}, -- Feralas
    [463] = {858}, -- Ghostlands
    [611] = {}, -- Gilneas City
    [679] = {}, -- Gilneas
    [490] = {1266, 1596}, -- Grizzly Hills
    [465] = {862}, -- Hellfire Peninsula
    [24] = {772, 4827, 5365, 5364}, -- Hillsbrad Foothills
    [491] = {1263}, -- Howling Fjord
    [541] = {}, -- Hrothgar's Landing
    [492] = { -- Icecrown
        1270,
        -- the tournament
        2756, 2772, 2836, 2773, 3736,
    },
    [341] = {6584}, -- Ironforge
    [929] = {}, -- Isle of Giants
    [499] = {868}, -- Isle of Quel'Danas
    [928] = {8121, 8101, 8104, 8105, 8106, 8107, 8108, 8110, 8111, 8112, 8114, 8115, 8116, 8117, 8118, 8119, 8120, 8212}, -- Isle of Thunder
    [610] = {4825, 4975, 5452, is_alliance and 5318 or 5319}, -- Kelp'thar Forest
    [605] = {}, -- Kezan
    [857] = {6975, 6547, 7518, is_alliance and 7928 or 7929, 7287, 7614, 7274}, -- Krasarang Wilds
    [809] = {6976, 6480, 7386, 7286}, -- Kun-Lai Summit
    [35] = {779, 4827}, -- Loch Modan
    [795] = {5859, 5866, 5867, 5870, 5871, 5872, 5873, 5874, 5879}, -- Molten Front
    [241] = {855}, -- Moonglade
    [606] = {4863, 4959, 5483, 5859, 5860, 5861, 5862, 5864, 5865, 5868, 5869}, -- Mount Hyjal
    [9] = {736}, -- Mulgore
    [477] = {866, 939, 1576}, -- Nagrand
    [479] = {843, 545}, -- Netherstorm
    [895] = {}, -- New Tinkertown
    [11] = {750}, -- Northern Barrens
    [37] = {781, 940}, -- Northern Stranglethorn
    [864] = {}, -- Northshire
    [321] = {6621}, -- Orgrimmar
    [502] = {}, -- Plaguelands: The Scarlet Enclave
    [36] = {780}, -- Redridge Mountains
    [685] = {}, -- Ruins of Gilneas City
    [684] = {}, -- Ruins of Gilneas
    [28] = {774}, -- Searing Gorge
    [888] = {}, -- Shadowglen
    [473] = {864}, -- Shadowmoon Valley
    [481] = {1165, 903}, -- Shattrath City
    [615] = {4825, 4975, 5452, is_alliance and 5318 or 5319}, -- Shimmering Expanse
    [493] = {1268, 938, 961, 962, 952}, -- Sholazar Basin
    [905] = {}, -- Shrine of Seven Stars
    [903] = {}, -- Shrine of Two Moons
    [261] = {856}, -- Silithus
    [480] = {6621}, -- Silvermoon City
    [21] = {769, 4827}, -- Silverpine Forest
    [607] = {4996, 4827}, -- Southern Barrens
    [81] = {847}, -- Stonetalon Mountains
    [301] = {6584}, -- Stormwind City
    [689] = {}, -- Stranglethorn Vale
    [893] = {}, -- Sunstrider Isle
    [38] = {782}, -- Swamp of Sorrows
    [161] = {851, 4827}, -- Tanaris
    [41] = {842}, -- Teldrassil
    [478] = {867, 1275}, -- Terokkar Forest
    [673] = {4995, 389, 396, 4827}, -- The Cape of Stranglethorn
    [471] = {6584}, -- The Exodar
    [26] = {773}, -- The Hinterlands
    [806] = {6351, 6550, 7289, 7290, 7291, 7381}, -- The Jade Forest
    [682] = {}, -- The Lost Isles
    [751] = {}, -- The Maelstrom
    [495] = {1269, 1428}, -- The Storm Peaks
    [687] = {641}, -- The Temple of Atal'Hakkar
    [726] = { -- The Underbog
        650,
        heroic = {670},
    },
    [873] = {7533, 7534, 8030, 7535, 7536, 8325}, -- The Veiled Stair
    [808] = {}, -- The Wandering Isle
    [61] = {846, 4827}, -- Thousand Needles
    [362] = {6621}, -- Thunder Bluff
    [951] = {8725, 8726, 8728, 8712, 8714, 8715, 8723, 8724, 8730, 8722, 8729, 8727, 8743, 8519, 8716, 8717, 8718, 8719, 8720, 8721, 8535, 8533}, -- Timeless Isle
    [20] = {768}, -- Tirisfal Glades
    [709] = {is_alliance and 5718 or 5719}, -- Tol Barad Peninsula
    [708] = {4874, is_alliance and 5489 or 5490, is_alliance and 5718 or 5719}, -- Tol Barad
    [810] = {6977, 7299, 7298, 7307, 7308, 7309, 7288}, -- Townlong Steppes
    [700] = {4866, 5451, 4960, 4958}, -- Twilight Highlands
    [720] = {4865, 5317, 4888, 4961}, -- Uldum
    [201] = {854}, -- Un'Goro Crater
    [382] = {6621}, -- Undercity
    [811] = { -- Vale of Eternal Blossoms
        6979, 6546, 7317, 7318, 7319, 7322, 7323, 7324,
        unavailable = {7315},
    },
    [807] = {6969, 6544, 6551, 7292, 7293, 7294, 7295, 7325, 7502, 6517, 7296}, -- Valley of the Four Winds
    [889] = {}, -- Valley of Trials
    [613] = {4825, 4975, 5452, is_alliance and 5318 or 5319}, -- Vashj'ir
    [22] = {770}, -- Western Plaguelands
    [39] = {802, 4827}, -- Westfall
    [40] = {841}, -- Wetlands
    [501] = {1752, 2199, 1717, 1751, 1755, 1727, 1723}, -- Wintergrasp
    [281] = {857, 5443}, -- Winterspring
    [467] = {863, 893}, -- Zangarmarsh
    [496] = {1267, 1576, 1596}, -- Zul'Drak
}
if is_alliance then
    tinsert(zones[490], 2016) -- Grizzly Hills
    tinsert(zones[501], 1737) -- Wintergrasp
    tinsert(zones[281], 3356) -- Winterspring
    extend(zones[700], {5320, 5481}) -- Twilight Highlands
    tinsert(zones[42], 5453) -- Darkshore
    extend(zones[301], {388, 545}) -- Stormwind City
    tinsert(zones[381], 388) -- Darnassus
    extend(zones[341], {388, 545}) -- Ironforge
    tinsert(zones[471], 388) -- Exodar
    tinsert(zones[321], {604, 610, 614}) -- Orgrammar
    tinsert(zones[362], {604, 611, 614}) -- Thunder Bluff
    tinsert(zones[382], {604, 612, 614}) -- Undercity
    tinsert(zones[480], {604, 613, 614}) -- Silvermoon City
    extend(zones[492], {3676, 2782}) -- Icecrown
    -- bgs
    tinsert(battlegrounds[401], 907) -- Alterac Valley
    tinsert(battlegrounds[461], 907) -- Arathi Basin
    tinsert(battlegrounds[443], 907) -- Warsong Gulch
    tinsert(battlegrounds[540], 3846) -- Isle of Conquest
end
if is_horde then
    tinsert(zones[181], 5454) -- Azshara
    tinsert(zones[490], 2017) -- Grizzly Hills
    tinsert(zones[501], 2476) -- Wintergrasp
    extend(zones[700], {5482, 5321}) -- Twilight Highlands
    extend(zones[321], {1006, 545}) -- Orgrimmar
    tinsert(zones[362], 1006) -- Thunder Bluff
    extend(zones[382], {1006, 545}) -- Undercity
    tinsert(zones[480], 1006) -- Silvermoon City
    extend(zones[301], {603, 615, 619}) -- Stormwind City
    extend(zones[341], {603, 616, 619}) -- Ironforge
    extend(zones[381], {603, 617, 619}) -- Darnassus
    extend(zones[471], {603, 618, 619}) -- Exodar
    extend(zones[492], {3677, 2788}) -- Icecrown
    -- bgs
    tinsert(battlegrounds[401], 714) -- Alterac Valley
    tinsert(battlegrounds[461], 714) -- Arathi Basin
    tinsert(battlegrounds[443], 714) -- Warsong Gulch
    tinsert(battlegrounds[540], 4176) -- Isle of Conquest
end

-- These are the "you've done X quests", or "you've completed this storyline" ones
quests = {
    -- regular zones
    [16] = 4896, -- Arathi Highlands
    [17] = 4900, -- Badlands
    [475] = 1193, -- Blade's Edge Mountains
    [19] = 4909, -- Blasted Lands
    [29] = 4901, -- Burning Steppes
    [640] = 4871, -- Deepholm
    [101] = 4930, -- Desolace
    [858] = 6540, -- Dread Wastes
    [23] = 4892, -- Eastern Plaguelands
    [182] = 4931, -- Felwood
    [492] = 40, -- Icecrown
    [928] = 8099, -- Isle of Thunder
    [606] = 4870, -- Mount Hyjal
    [479] = 1194, -- Netherstorm
    [37] = 4906, -- Northern Stranglethorn
    [28] = 4910, -- Searing Gorge
    [473] = 1195, -- Shadowmoon Valley
    [493] = 39, -- Sholazar Basin
    [261] = 4934, -- Silithus
    [38] = 4904, -- Swamp of Sorrows
    [161] = 4935, -- Tanaris
    [673] = 4905, -- The Cape of Stranglethorn
    [26] = 4897, -- The Hinterlands
    [495] = 38, -- The Storm Peaks
    [61] = 4938, -- Thousand Needles
    [810] = 6539, -- Townlong Steppes
    [720] = 4872, -- Uldum
    [201] = 4939, -- Un'Goro Crater
    [807] = 6301, -- Valley of the Four Winds
    [22] = 4893, -- Western Plaguelands
    [281] = 4940, -- Winterspring
    [467] = 1190, -- Zangarmarsh
    [496] = 36, -- Zul'Drak
}
if is_alliance then
    -- quests
    quests[614] = 4869 -- Abyssal Depths
    quests[43] = 4925 -- Ashenvale
    quests[476] = 4926 -- Bloodmyst Isle
    quests[486] = 33 -- Borean Tundra
    quests[42] = 4928 -- Darkshore
    quests[488] = 35 -- Dragonblight
    quests[34] = 4903 -- Duskwood
    quests[141] = 4929 -- Dustwallow Marsh
    quests[121] = 4932 -- Feralas
    quests[490] = 37 -- Grizzly Hills
    quests[465] = 1189 -- Hellfire Peninsula
    quests[491] = 34 -- Howling Fjord
    quests[806] = 6300-- Jade Forest
    quests[610] = 4869 -- Kelp'thar Forest
    quests[857] = 6535 -- Krasarang Wilds
    quests[809] = 6537 -- Kun-Lai Summit
    quests[35] = 4899 -- Loch Modan
    quests[477] = 1192 -- Nagrand
    quests[36] = 4902 -- Redridge Mountains
    quests[615] = 4869 -- Shimmering Expanse
    quests[607] = 4937 -- Southern Barrens
    quests[478] = 1191 -- Terokkar Forest
    quests[700] = 4873 -- Twilight Highlands
    quests[613] = 4869 -- Vashj'ir
    quests[39] = 4903 -- Westfall
    quests[40] = 4899 -- Wetlands
end
if is_horde then
    -- quests
    quests[614] = 4982 -- Abyssal Depths
    quests[43] = 4976 -- Ashenvale
    quests[181] = 4927 -- Azshara
    quests[486] = 1358 -- Borean Tundra
    quests[488] = 1359 -- Dragonblight
    quests[141] = 4978 -- Dustwallow Marsh
    quests[121] = 4979 -- Feralas
    quests[463] = 4908 -- Ghostlands
    quests[490] = 1357 -- Grizzly Hills
    quests[465] = 1271 -- Hellfire Peninsula
    quests[24] = 4895 -- Hillsbrad Foothills
    quests[491] = 1356 -- Howling Fjord
    quests[806] = 6534 -- Jade Forest
    quests[610] = 4982 -- Kelp'thar Forest
    quests[857] = 6536 -- Krasarang Wilds
    quests[809] = 6538 -- Kun-Lai Summit
    quests[477] = 1273 -- Nagrand
    quests[11] = 4933 -- Northern Barrens
    quests[615] = 4982 -- Shimmering Expanse
    quests[21] = 4894 -- Silverpine Forest
    quests[607] = 4981 -- Southern Barrens
    quests[81] = 4980 -- Stonetalon Mountains
    quests[478] = 1272 -- Terokkar Forest
    quests[700] = 5501 -- Twilight Highlands
    quests[613] = 4982 -- Vashj'ir
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
