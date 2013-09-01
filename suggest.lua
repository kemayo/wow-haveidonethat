local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")
local mod = ns:NewModule("suggest")
local core = ns:GetModule("core")

local is_alliance = UnitFactionGroup("player") == "Alliance"
local is_horde = UnitFactionGroup("player") == "Horde"
local zones, quests, skills, pvp

local prof1, prof2, archaeology, fishing, cooking, firstAid = GetProfessions()
local COOKING = GetProfessionInfo(cooking)
local FISHING = GetProfessionInfo(fishing)
local ARCHAEOLOGY = GetProfessionInfo(archaeology)
local FIRSTAID = GetProfessionInfo(firstAid)

function mod:OnLoad()
    if IsAddOnLoaded("Blizzard_AchievementUI") then
        self:CreateButton()
    else
        mod:RegisterEvent("ADDON_LOADED")
    end
end

function mod:ADDON_LOADED(event, addon)
    if addon ~= "Blizzard_AchievementUI" then
        return
    end
    self:CreateButton()
    self:UnregisterEvent("ADDON_LOADED")
end

function mod:CreateButton()
    local tab = CreateFrame("Button", "AchievementFrameTabHIDT", AchievementFrame, "AchievementFrameTabButtonTemplate")
    tab:SetPoint("TOPRIGHT", "AchievementFrame", "BOTTOMRIGHT", -5, 0)
    tab:SetText("What now?")

    tab:SetScript("OnClick", function(_, button)
        if (button) then
            PlaySound("igCharacterInfoTab")
        end
        self:Suggest()
    end)
end

do
    local frame
    local BUTTON_HEIGHT = 48
    local function GetTooltipAnchor(frame)
        local x, y = frame:GetCenter()

        if not x or not y then
            return "TOPLEFT", "BOTTOMLEFT"
        end
        local vhalf = (y > _G.UIParent:GetHeight() / 2) and "TOP" or "BOTTOM"
        local hhalf = (x > _G.UIParent:GetWidth() * 2 / 3) and "RIGHT" or (x < _G.UIParent:GetWidth() / 3) and "LEFT" or ""
        return vhalf .. hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP") .. (hhalf == "RIGHT" and "LEFT" or "RIGHT")
    end
    local function button_click(self)
        WatchFrame_OpenAchievementFrame(self, self.id)
    end
    function mod:CreateFrame()
        if not frame then
            if not IsAddOnLoaded("Blizzard_AchievementUI") then
                LoadAddOn("Blizzard_AchievementUI")
            end

            frame = CreateFrame("Frame", "HIDTSuggestionsBox", UIParent, "BasicFrameTemplate")
            frame:SetHeight(400)
            frame:SetWidth(500)
            frame:SetPoint("CENTER")
            frame:SetMovable(true)
            frame:SetClampedToScreen(true)
            frame:EnableMouse(true)
            frame:RegisterForDrag("LeftButton")
            frame:SetScript("OnDragStart", frame.StartMoving)
            frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
            frame:SetToplevel(true)
            frame.TitleText:SetText(myfullname)
            frame:Hide()

            local scroll_frame = CreateFrame("ScrollFrame", "$parentScrollFrame", frame, "HybridScrollFrameTemplate")
            scroll_frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -27)
            scroll_frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -27, 4)
            scroll_frame:SetFrameLevel(frame:GetFrameLevel() + 1)
            scroll_frame:EnableMouse(true)
            frame.scroll_frame = scroll_frame

            scroll_frame.update = function()
                self:UpdateSuggestions(frame)
            end
            scroll_frame:SetScript("OnShow", scroll_frame.update)
            frame:SetScript("OnShow", scroll_frame.update)

            local scroll_bar = CreateFrame("Slider", "$parentScrollBar", scroll_frame, "HybridScrollBarTemplate")
            scroll_bar:SetPoint("TOPLEFT", scroll_frame, "TOPRIGHT", 4, -13)
            scroll_bar:SetPoint("BOTTOMLEFT", scroll_frame, "BOTTOMRIGHT", 4, 13)
            scroll_bar.doNotHide = true

            scroll_frame.scrollBar = scroll_bar
            scroll_frame.buttonHeight = math.floor(BUTTON_HEIGHT + .5)

            local scroll_child = scroll_frame.scrollChild
            local num_buttons = math.ceil(frame:GetHeight() / BUTTON_HEIGHT) + 1
            local buttons = {}
            for i=1, num_buttons do
                -- local button = CreateFrame("Button", "$parentButton"..i, scroll_child)
                local button = CreateFrame("Button", "$parentButton"..i, scroll_child, "SummaryAchievementTemplate")
                button.isSummary = true
                AchievementFrameSummary_LocalizeButton(button)
                -- the onload of this template adds us to a cache... let's take care of that...
                tremove(AchievementFrameSummaryAchievements.buttons)
                button:SetScript("OnClick", button_click)

                if i == 1 then
                    button:SetPoint("TOPLEFT", scroll_child, "TOPLEFT", 0, 0)
                    button:SetPoint("TOPRIGHT", scroll_child, "TOPRIGHT", 0, 0)
                else
                    button:SetPoint("TOPLEFT", buttons[i - 1], "BOTTOMLEFT", 0, 3)
                    button:SetPoint("TOPRIGHT", buttons[i - 1], "BOTTOMRIGHT", 0, 3)
                end

                button.id_text = button.icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                button.id_text:SetPoint("BOTTOM", button.icon, "BOTTOM", 0, 10)

                tinsert(buttons, button)
            end
            scroll_frame.buttons = buttons

            scroll_child:SetWidth(scroll_frame:GetWidth())
            scroll_child:SetHeight(num_buttons * BUTTON_HEIGHT)
            scroll_frame:SetVerticalScroll(0)
            scroll_frame:UpdateScrollChildRect()

            scroll_bar:SetMinMaxValues(0, num_buttons * BUTTON_HEIGHT)
            scroll_bar:SetValueStep(.005)
            scroll_bar:SetValue(0)

            tinsert(UISpecialFrames, frame:GetName())
        end
        return frame
    end
    function mod:Suggest()
        self:CreateFrame()
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
        end
    end
end

local accumulate = {}
local function suggestion_handler(suggestions, size, variant)
    for i, aid in ipairs(suggestions) do
        tinsert(accumulate, aid)
    end
    if variant and suggestions[variant] then
        suggestion_handler(suggestions.heroic, size, variant)
    end
    if size and suggestions['size' .. size] then
        suggestion_handler(suggestions[size], size, variant)
    end
    return accumulate
end
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
function mod:UpdateSuggestions(frame, zoneid, size, variant)
    zoneid = zoneid or GetCurrentMapAreaID()
    local suggestions = zones[zoneid]
    if not suggestions then
        return
    end
    local instance_type, current_size, current_variant = self:WorkOutInstanceType()
    if size == nil then
        size = current_size
    end
    if variant == nil then
        variant = current_variant
    end
    wipe(accumulate)
    local to_suggest = suggestion_handler(suggestions, size, variant)

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

        if offset_i <= num_items then
            -- This is pretty solidly copied from the default UI achievement frame
            local id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy = GetAchievementInfo(to_suggest[offset_i])
            local saturatedStyle
            if bit.band(flags, ACHIEVEMENT_FLAGS_ACCOUNT) == ACHIEVEMENT_FLAGS_ACCOUNT then
                button.accountWide = true
                saturatedStyle = "account"
            else
                button.accountWide = nil
                saturatedStyle = "normal"
            end

            button.label:SetText(name)
            button.description:SetText(description)
            AchievementShield_SetPoints(points, button.shield.points, GameFontNormal, GameFontNormalSmall)
            if points > 0 then
                button.shield.icon:SetTexture([[Interface\AchievementFrame\UI-Achievement-Shields]])
            else
                button.shield.icon:SetTexture([[Interface\AchievementFrame\UI-Achievement-Shields-NoPoints]])
            end

            button.shield.wasEarnedByMe = not (completed and not wasEarnedByMe)
            button.shield.earnedBy = earnedBy

            button.icon.texture:SetTexture(icon)
            button.id = id

            if core.db.id then
                button.id_text:SetText(id)
                button.id_text:Show()
            else
                button.id_text:Hide()
            end

            if completed then
                button.completed = true
                button.dateCompleted:SetText(string.format(SHORTDATE, day, month, year))
                button.dateCompleted:Show()
                if button.saturatedStyle ~= saturatedStyle then
                    button:Saturate()
                end
            else
                button.completed = false
                button.dateCompleted:SetText("")
                button.dateCompleted:Hide()
                button:Desaturate()
            end
            
            button.tooltipTitle = nil

            button:Show()
        else
            button:Hide()
        end
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

zones = {
    [878] = {}, -- A Brewing Storm
    [614] = {4825, 4975, 5452, is_alliance and 5318 or 5319}, -- Abyssal Depths
    [522] = { -- Ahn'kahet: The Old Kingdom
        481,
        heroic = {492, 2056, 1862, 2038}
    },
    [766] = {687, 7934}, -- Ahn'Qiraj
    [772] = {687, 689, 7934}, -- Ahn'Qiraj: The Fallen Kingdom
    [401] = {1167, 226}, -- Alterac Valley
    [894] = {}, -- Ammen Vale
    [461] = {1169}, -- Arathi Basin
    [16] = {761}, -- Arathi Highlands
    [43] = {845, 4827}, -- Ashenvale
    [722] = { -- Auchenai Crypts
        666,
        heroic = {672},
    },
    [533] = { -- Azjol-Nerub
        480,
        heroic = {491, 1860, 1296, 1297},
    },
    [181] = {852, 5448, 5546, 5547}, -- Azshara
    [464] = {860}, -- Azuremyst Isle
    [17] = {765, 4827}, -- Badlands
    [752] = {}, -- Baradin Hold
    [796] = {697}, -- Black Temple
    [688] = {632}, -- Blackfathom Deeps
    [753] = { -- Blackrock Caverns
        4833,
        heroic = {5282, 5284, 5281, 5060, 5283},
    },
    [704] = {642}, -- Blackrock Depths
    [721] = {643, 1307, 2188}, -- Blackrock Spire
    [754] = { -- Blackwing Descent
        4842, 5306, 5307, 5308, 5309, 4849, 5310,
        heroic = {5094, 5107, 5108, 5109, 5115, 5116},
    },
    [755] = {685, 7934}, -- Blackwing Lair
    [475] = {865, 1276}, -- Blade's Edge Mountains
    [19] = {766}, -- Blasted Lands
    [476] = {861}, -- Bloodmyst Isle
    [486] = {1264, 561}, -- Borean Tundra
    [884] = {}, -- Brewmoon Festival
    [29] = {775}, -- Burning Steppes
    [890] = {}, -- Camp Narache
    [866] = {}, -- Coldridge Valley
    [900] = {}, -- Crypt of Forgotten Kings
    [510] = {1457}, -- Crystalsong Forest
    [504] = {1956, 545,}, -- Dalaran
    [823] = {6020, 6021, 6022, 6023, 6026, 6027, 6028, 6029, is_alliance and 6030 or 6031, 6032, 6025}, -- Darkmoon Island
    [42] = {844, 4827}, -- Darkshore
    [381] = {6584}, -- Darnassus
    [32] = {777}, -- Deadwind Pass
    [892] = {}, -- Deathknell
    [640] = {4864, 5445, 5446, 5447, 5449}, -- Deepholm
    [101] = {848}, -- Desolace
    [699] = {644}, -- Dire Maul
    [824] = { -- Dragon Soul
        6106, 6107,
        normal = {6177, 6174, 6128, 6129, 6175, 6084, 6105, 6133, 6180},
        heroic = {6109, 6110, 6111, 6112, 6113, 6114, 6115, 6116},
    },
    [488] = {1265, 1277, 547}, -- Dragonblight
    [534] = {
        482,
        heroic = {493, 2039, 2057, 2151},
    }, -- Drak'Tharon Keep
    [858] = {6978, 6545, 7312, 7313, 7314, 7316}, -- Dread Wastes
    [27] = {627}, -- Dun Morogh
    [4] = {728, 4827}, -- Durotar
    [34] = {778}, -- Duskwood
    [141] = {850}, -- Dustwallow Marsh
    [23] = {771, 5442}, -- Eastern Plaguelands
    [891] = {}, -- Echo Isles
    [30] = {776}, -- Elwynn Forest
    [820] = {}, -- End Time
    [462] = {859}, -- Eversong Woods
    [813] = {1171, 587, 1258, 211}, -- Eye of the Storm
    [182] = {853}, -- Felwood
    [121] = {849}, -- Feralas
    [800] = { -- Firelands
        5802, 5828, 5855, 5821, 5810, 5813, 5829, 5830, 5799, 5855,
        heroic = {5803, 5807, 5808, 5806, 5809, 5805, 5804},
    },
    [875] = { -- Gate of the Setting Sun
        6945,
        heroic = {6759, 6479, 6476, 6715},
    },
    [463] = {858}, -- Ghostlands
    [611] = {}, -- Gilneas City
    [679] = {}, -- Gilneas
    [691] = {634}, -- Gnomeregan
    [757] = { -- Grim Batol
        4840,
        heroic = {5298, 5062, 5297},
    },
    [490] = {1266, 1596}, -- Grizzly Hills
    [776] = {692}, -- Gruul's Lair
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
    [897] = { -- Heart of Fear
        6718, 6845,
        normal = {6936, 6518, 6683, 6553, 6937, 6922},
        heroic = {6729, 6726, 6727, 6730, 6725, 6728},
    },
    [465] = {862}, -- Hellfire Peninsula
    [797] = { -- Hellfire Ramparts
        647,
        heroic = {667}
    },
    [24] = {772, 4827, 5365, 5364}, -- Hillsbrad Foothills
    [819] = {}, -- Hour of Twilight
    [491] = {1263}, -- Howling Fjord
    [541] = {}, -- Hrothgar's Landing
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
    [492] = { -- Icecrown
        1270,
        -- the tournament
        2756, 2772, 2836, 2773, 3736,
    },
    [341] = {6584}, -- Ironforge
    [540] = {3857, 3845}, -- Isle of Conquest
    [929] = {}, -- Isle of Giants
    [499] = {868}, -- Isle of Quel'Danas
    [928] = {8121, 8101, 8104, 8105, 8106, 8107, 8108, 8110, 8111, 8112, 8114, 8115, 8116, 8117, 8118, 8119, 8120, 8212}, -- Isle of Thunder
    [799] = {690, 8293}, -- Karazhan
    [610] = {4825, 4975, 5452, is_alliance and 5318 or 5319}, -- Kelp'thar Forest
    [605] = {}, -- Kezan
    [857] = {6975, 6547, 7518, is_alliance and 7928 or 7929, 7287}, -- Krasarang Wilds
    [809] = {6976, 6480, 7386, 7286}, -- Kun-Lai Summit
    [35] = {779, 4827}, -- Loch Modan
    [747] = { -- Lost City of the Tol'vir
        4848,
        heroic = {5291, 5292, 5066, 5290},
    },
    [798] = { -- Magisters' Terrace
        661,
        heroic = {682},
    },
    [779] = {693}, -- Magtheridon's Lair
    [732] = { -- Mana-Tombs
        651,
        heroic = {671},
    },
    [750] = {640}, -- Maraudon
    [885] = { -- Mogu'shan Palace
        6755,
        heroic = {6478, 6756, 6713, 6736, 6715},
    },
    [896] = { -- Mogu'shan Vaults
        6458, 6844,
        normal = {6674, 6687, 6823, 6455, 7056, 6686},
        heroic = {6723, 6720, 6722, 6721, 6719, 6724},
    },
    [696] = {686, 7934}, -- Molten Core
    [795] = {5859, 5866, 5867, 5870, 5871, 5872, 5873, 5874, 5879}, -- Molten Front
    [241] = {855}, -- Moonglade
    [683] = {4863, 4959, 5483, 5859, 5860, 5861, 5862, 5864, 5865, 5868, 5869}, -- Mount Hyjal
    [9] = {736}, -- Mulgore
    [477] = {866, 939, 1576}, -- Nagrand
    [535] = { -- Naxxramas
        7934,
        size10 = {2146, 576, 578, 572, 1856, 2176, 2178, 2180, 568, 1996, 1997, 1858, 564, 2182, 2184, 566, 574, 562},
        size25 = {579, 565, 577, 575, 2177, 563, 567, 1857, 569, 573, 1859, 2139, 2181, 2183, 2185, 2147, 2140, 2179},
        unavailable = {2186, 2187},
    },
    [479] = {843, 545}, -- Netherstorm
    [895] = {}, -- New Tinkertown
    [11] = {750}, -- Northern Barrens
    [37] = {781, 940}, -- Northern Stranglethorn
    [864] = {}, -- Northshire
    [734] = { -- Old Hillsbrad Foothills
        652,
        heroic = {673},
    },
    [718] = {
        size10 = {4396, 4402, 4403, 4404},
        unavailable = {684},
    }, -- Onyxia's Lair
    [321] = {6621}, -- Orgrimmar
    [602] = { -- Pit of Saron
        4517,
        heroic = {4520, 4524, 4525},
    },
    [502] = {}, -- Plaguelands: The Scarlet Enclave
    [899] = {}, -- Proving Grounds
    [680] = {629}, -- Ragefire Chasm
    [760] = {636}, -- Razorfen Downs
    [761] = {635}, -- Razorfen Kraul
    [36] = {780}, -- Redridge Mountains
    [717] = {689}, -- Ruins of Ahn'Qiraj
    [685] = {}, -- Ruins of Gilneas City
    [684] = {}, -- Ruins of Gilneas
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
    [28] = {774}, -- Searing Gorge
    [780] = {694, 8293}, -- Serpentshrine Cavern
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
    [888] = {}, -- Shadowglen
    [473] = {864}, -- Shadowmoon Valley
    [481] = {1165, 903}, -- Shattrath City
    [615] = {4825, 4975, 5452, is_alliance and 5318 or 5319}, -- Shimmering Expanse
    [493] = {1268, 938, 961, 962, 952}, -- Sholazar Basin
    [905] = {}, -- Shrine of Seven Stars
    [903] = {}, -- Shrine of Two Moons
    [887] = { -- Siege of Niuzao Temple
        heroic = {6763, 6485, 6822, 6688, 6715},
    },
    [261] = {856}, -- Silithus
    [480] = {6621}, -- Silvermoon City
    [21] = {769, 4827}, -- Silverpine Forest
    [860] = {7106}, -- Silvershard Mines
    [607] = {4996, 4827}, -- Southern Barrens
    [81] = {847}, -- Stonetalon Mountains
    [876] = { -- Stormstout Brewery
        6457, 6400, 6402,
        heroic = {6456, 6420, 6089, 6715},
    },
    [301] = {6584}, -- Stormwind City
    [512] = {2194}, -- Strand of the Ancients
    [689] = {}, -- Stranglethorn Vale
    [765] = {646}, -- Stratholme
    [893] = {}, -- Sunstrider Isle
    [789] = {698}, -- Sunwell Plateau
    [38] = {782}, -- Swamp of Sorrows
    [161] = {851, 4827}, -- Tanaris
    [41] = {842}, -- Teldrassil
    [782] = {696, 8293}, -- Tempest Keep
    [881] = {6981}, -- Temple of Kotmogu
    [867] = { -- Temple of the Jade Serpent
        6757,
        heroic = {6758, 6475, 6460, 6671, 6715},
    },
    [478] = {867, 1275}, -- Terokkar Forest
    [886] = { -- Terrace of Endless Spring
        6689,
        normal = {6824, 6717, 6825, 6933},
        heroic = {6733, 6731, 6734, 6732},
    },
    [731] = { -- The Arcatraz
        660,
        heroic = {681},
    },
    [758] = {
        4850, 5300, 4852, 5311, 5312,
        heroic = {5118, 5117, 5119, 5120, 5121},
    }, -- The Bastion of Twilight
    [677] = {5258}, -- The Battle for Gilneas (Old City Map)
    [736] = {5258}, -- The Battle for Gilneas
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
    [673] = {4995, 389, 396, 4827}, -- The Cape of Stranglethorn
    [521] = { -- The Culling of Stratholme
        479,
        heroic = {500, 1872, 1817},
    },
    [756] = {
        628,
        heroic = {5083, 5370, 5369, 5368, 5367, 5366, 5371},
    }, -- The Deadmines
    [471] = {6584}, -- The Exodar
    [527] = {
        size10 = {622, 1874, 2148, 1869},
    }, -- The Eye of Eternity
    [601] = { -- The Forge of Souls
        4516,
        heroic = {4519, 4522, 4523},
    },
    [26] = {773}, -- The Hinterlands
    [806] = {6351, 6550, 7289, 7290, 7291, 7381}, -- The Jade Forest
    [682] = {}, -- The Lost Isles
    [751] = {}, -- The Maelstrom
    [730] = { -- The Mechanar
        658,
        heroic = {679},
    },
    [803] = { -- The Nexus
        478,
        heroic = {490, 2037, 2036, 2150},
    },
    [531] = {
        size10 = {1876, 2047, 2049, 2050, 2051, 624},
    }, -- The Obsidian Sanctum
    [528] = { -- The Oculus
        487,
        heroic = {498, 1868, 1871, 2044, 2045, 2046},
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
    [495] = {1269, 1428}, -- The Storm Peaks
    [687] = {641}, -- The Temple of Atal'Hakkar
    [726] = { -- The Underbog
        650,
        heroic = {670},
    },
    [873] = {7533, 7534, 8030, 7535, 7536, 8325}, -- The Veiled Stair
    [536] = { -- The Violet Hold
        483,
        heroic = {494, 2153, 1865, 2041, 1816},
    },
    [769] = { -- The Vortex Pinnacle
        4847,
        heroic = {5289, 5064, 5288},
    },
    [808] = {}, -- The Wandering Isle
    [61] = {846, 4827}, -- Thousand Needles
    [773] = { -- Throne of the Four Winds
        4851, 5304, 5305,
        heroic = {5122, 5123, },
    },
    [767] = { -- Throne of the Tides
        4839,
        heroic = {5061, 5285, 5286},
    },
    [930] = { -- Throne of Thunder
        8070, 8071, 8069, 8072,
        normal = {8089, 8037, 8087, 8090, 8094, 8073, 8082, 8098, 8081, 8086},
        heroic = {8124, 8067},
    },
    [362] = {6621}, -- Thunder Bluff
    [20] = {768}, -- Tirisfal Glades
    [709] = {is_alliance and 5718 or 5719}, -- Tol Barad Peninsula
    [708] = {4874, is_alliance and 5489 or 5490, is_alliance and 5718 or 5719}, -- Tol Barad
    [810] = {6977, 7299, 7298, 7307, 7308, 7309, 7288}, -- Townlong Steppes
    [542] = { -- Trial of the Champion
        is_alliance and 4296 or 3778,
        heroic = {is_alliance and 4298 or 4297, 3802, 3803, 3804},
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
    [770] = {4866, 5451, 4960, 4958}, -- Twilight Highlands
    [626] = {5223}, -- Twin Peaks
    [692] = {638}, -- Uldaman
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
            3009, 3157, 3008, 3012, 3014, 3015,
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
            3011, 3161, 3010, 3013, 3017, 3016,
            -- alganon
            3037, 3002,
        },
        unavailable = {2903, 2904, 3004, 3005, 3316},
    },
    [748] = {4865, 5317, 4888, 4961}, -- Uldum
    [201] = {854}, -- Un'Goro Crater
    [382] = {6621}, -- Undercity
    [882] = {}, -- Unga Ingoo
    [523] = { -- Utgarde Keep
        477,
        heroic = {489, 1919},
    },
    [524] = {
        488,
        heroic = {499, 1873, 2043, 2156, 2157},
    }, -- Utgarde Pinnacle
    [811] = {6979, 6546, 7317, 7318, 7319, 7322, 7323, 7324}, -- Vale of Eternal Blossoms
    [807] = {6969, 6544, 6551, 7292, 7293, 7294, 7295, 7325, 7502, 6517, 7296}, -- Valley of the Four Winds
    [889] = {}, -- Valley of Trials
    [613] = {4825, 4975, 5452, is_alliance and 5318 or 5319}, -- Vashj'ir
    [532] = { -- Vault of Archavon
        size10 = {1722, 3136, 3836, 4016},
        size25 = {1721, 3137, 3837, 4017},
    },
    [749] = {630}, -- Wailing Caverns
    [443] = {1172, 1259}, -- Warsong Gulch
    [816] = {}, -- Well of Eternity
    [22] = {770}, -- Western Plaguelands
    [39] = {802, 4827}, -- Westfall
    [40] = {841}, -- Wetlands
    [501] = {1752, 2199, 1717, 1751, 1755, 1727, 1723}, -- Wintergrasp
    [281] = {857, 5443}, -- Winterspring
    [883] = {}, -- Zan'vess
    [467] = {863, 893}, -- Zangarmarsh
    [781] = { -- Zul'Aman
        5769, 5858, 5760, 5761, 5750,
        unavailable = {691},
    },
    [496] = {1267, 1576, 1596}, -- Zul'Drak
    [686] = {639}, -- Zul'Farrak
    [793] = { -- Zul'Gurub
        5768, 5765, 5743, 5762, 5759, 5744,
        unavailable = {688, 560, 957},
    },
}
if is_alliance then
    tinsert(zones[490], 2016) -- Grizzly Hills
    tinsert(zones[501], 1737) -- Wintergrasp
    tinsert(zones[281], 3356) -- Winterspring
    extend(zones[770], {5320, 5481}) -- Twilight Highlands
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
    tinsert(zones[401], 907) -- Alterac Valley
    tinsert(zones[461], 907) -- Arathi Basin
    tinsert(zones[443], 907) -- Warsong Gulch
    tinsert(zones[540], 3846) -- Isle of Conquest
end
if is_horde then
    tinsert(zones[181], 5454) -- Azshara
    tinsert(zones[490], 2017) -- Grizzly Hills
    tinsert(zones[501], 2476) -- Wintergrasp
    extend(zones[770], {5482, 5321}) -- Twilight Highlands
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
    tinsert(zones[401], 714) -- Alterac Valley
    tinsert(zones[461], 714) -- Arathi Basin
    tinsert(zones[443], 714) -- Warsong Gulch
    tinsert(zones[540], 4176) -- Isle of Conquest
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
    [683] = 4870, -- Mount Hyjal
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
    [748] = 4872, -- Uldum
    [201] = 4939, -- Un'Goro Crater
    [811] = 7315, -- Vale of Eternal Blossoms
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
    quests[770] = 4873 -- Twilight Highlands
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
    quests[770] = 5501 -- Twilight Highlands
    quests[613] = 4982 -- Vashj'ir
end

-- assemble!
for zoneid,aid in pairs(quests) do
    tinsert(zones[zoneid], 1, aid)
end

-- these are the ones we'll pop up only if there's a trigger, or a direct request
skills = {
    [COOKING] = {
        1563, 5845,
        zones = {
            [504] = {1998, is_alliance and 1782 or 1783, 3217, 3296}, -- Dalaran
            [481] = {906}, -- Shattrath City
        },
    },
    [FISHING] = {
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
    skills[COOKING].zones[381] = {5842} -- Darnassus
    skills[COOKING].zones[341] = {5841} -- Ironforge
    skills[COOKING].zones[301] = {5474} -- Stormwind
    skills[FISHING].zones[381] = {5848} -- Darnassus
    tinsert(skills[FISHING].zones[341], 5847) -- Ironforge
    tinsert(skills[FISHING].zones[301], 5476) -- Stormwind
end
if is_horde then
    skills[COOKING].zones[321] = {5475} -- Orgrimmar
    skills[COOKING].zones[362] = {5843} -- Thunder Bluff
    skills[COOKING].zones[382] = {5844} -- Undercity
    tinsert(skills[FISHING].zones[321], 5477) -- Orgrimmar
    skills[FISHING].zones[362] = {5849} -- Thunder Bluff
    skills[FISHING].zones[382] = {5850} -- Undercity
end

pvp = {238, 245, is_alliance and 246 or 1005, 247, 229, 227, 231, 1785}
