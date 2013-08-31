local myname, ns = ...
local mod = ns:NewModule("suggest")
local core = ns:GetModule("core")

local is_alliance = UnitFactionGroup("player") == "Alliance"
local is_horde = UnitFactionGroup("player") == "Horde"
local zones, quests


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

function mod:UpdateSuggestions(zoneid, size, variant)
    zoneid = zoneid or GetCurrentMapAreaID()
    local suggestions = zones[zoneid]
    if not suggestions then
        return
    end
    local _, current_size, current_variant = self:WorkOutInstanceType()
    if size == nil then
        size = current_size
    end
    if variant == nil then
        variant = current_variant
    end
    wipe(accumulate)
    local to_suggest = suggestion_handler(suggestions, size, variant)
    for i,aid in ipairs(to_suggest) do
        local _, name, _, done = GetAchievementInfo(aid)
        self.Print(name, done)
    end
end

function mod:Suggest()

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
    [614] = {}, -- Abyssal Depths
    [522] = { -- Ahn'kahet: The Old Kingdom
        481,
        heroic = {492, 2056, 1862, 2038}
    },
    [766] = {687}, -- Ahn'Qiraj
    [772] = {687, 689}, -- Ahn'Qiraj: The Fallen Kingdom
    [401] = {}, -- Alterac Valley
    [894] = {}, -- Ammen Vale
    [461] = {}, -- Arathi Basin
    [16] = {}, -- Arathi Highlands
    [43] = {}, -- Ashenvale
    [722] = { -- Auchenai Crypts
        666,
        heroic = {672},
    },
    [533] = { -- Azjol-Nerub
        480,
        heroic = {491, 1860, 1296, 1297},
    },
    [181] = {}, -- Azshara
    [464] = {}, -- Azuremyst Isle
    [17] = {}, -- Badlands
    [752] = {}, -- Baradin Hold
    [796] = {697}, -- Black Temple
    [688] = {632}, -- Blackfathom Deeps
    [753] = { -- Blackrock Caverns
        4833,
        heroic = {5282, 5284, 5281, 5060, 5283},
    },
    [704] = {642}, -- Blackrock Depths
    [721] = {643, 1307, 2188}, -- Blackrock Spire
    [754] = {}, -- Blackwing Descent
    [755] = {685}, -- Blackwing Lair
    [475] = {}, -- Blade's Edge Mountains
    [19] = {}, -- Blasted Lands
    [476] = {}, -- Bloodmyst Isle
    [486] = {}, -- Borean Tundra
    [884] = {}, -- Brewmoon Festival
    [29] = {}, -- Burning Steppes
    [890] = {}, -- Camp Narache
    [866] = {}, -- Coldridge Valley
    [900] = {}, -- Crypt of Forgotten Kings
    [510] = {}, -- Crystalsong Forest
    [504] = {}, -- Dalaran
    [823] = {}, -- Darkmoon Island
    [42] = {}, -- Darkshore
    [381] = {}, -- Darnassus
    [32] = {}, -- Deadwind Pass
    [892] = {}, -- Deathknell
    [640] = {}, -- Deepholm
    [101] = {}, -- Desolace
    [699] = {644}, -- Dire Maul
    [824] = {}, -- Dragon Soul
    [488] = {}, -- Dragonblight
    [534] = {
        482,
        heroic = {493, 2039, 2057, 2151},
    }, -- Drak'Tharon Keep
    [858] = {}, -- Dread Wastes
    [27] = {}, -- Dun Morogh
    [4] = {}, -- Durotar
    [34] = {}, -- Duskwood
    [141] = {}, -- Dustwallow Marsh
    [23] = {}, -- Eastern Plaguelands
    [891] = {}, -- Echo Isles
    [30] = {}, -- Elwynn Forest
    [820] = {}, -- End Time
    [462] = {}, -- Eversong Woods
    [813] = {}, -- Eye of the Storm
    [182] = {}, -- Felwood
    [121] = {}, -- Feralas
    [800] = { -- Firelands
        heroic = {5803},
    },
    [875] = { -- Gate of the Setting Sun
        heroic = {6759, 6479, 6476},
    },
    [463] = {}, -- Ghostlands
    [611] = {}, -- Gilneas City
    [679] = {}, -- Gilneas
    [691] = {634}, -- Gnomeregan
    [757] = { -- Grim Batol
        4840,
        heroic = {5298, 5062, 5297},
    },
    [490] = {}, -- Grizzly Hills
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
    [897] = {
        heroic = {6729, 6726, 6727, 6730, 6725, 6728},
    }, -- Heart of Fear
    [465] = {}, -- Hellfire Peninsula
    [797] = { -- Hellfire Ramparts
        647,
        heroic = {667}
    },
    [24] = {}, -- Hillsbrad Foothills
    [819] = {}, -- Hour of Twilight
    [491] = {}, -- Howling Fjord
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
    [492] = {}, -- Icecrown
    [341] = {}, -- Ironforge
    [540] = {}, -- Isle of Conquest
    [929] = {}, -- Isle of Giants
    [499] = {}, -- Isle of Quel'Danas
    [928] = {}, -- Isle of Thunder
    [799] = {690}, -- Karazhan
    [610] = {}, -- Kelp'thar Forest
    [605] = {}, -- Kezan
    [857] = {}, -- Krasarang Wilds
    [809] = {}, -- Kun-Lai Summit
    [35] = {}, -- Loch Modan
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
        heroic = {6478, 6756, 6713, 6736},
    },
    [896] = {
        heroic = {6723, 6720, 6722, 6721, 6719, 6724},
    }, -- Mogu'shan Vaults
    [696] = {686}, -- Molten Core
    [795] = {}, -- Molten Front
    [241] = {}, -- Moonglade
    [683] = {}, -- Mount Hyjal
    [9] = {}, -- Mulgore
    [477] = {}, -- Nagrand
    [535] = { -- Naxxramas
        size10 = {2146, 576, 578, 572, 1856, 2176, 2178, 2180, 568, 1996, 1997, 1858, 564, 2182, 2184, 566, 574, 562},
        size25 = {579, 565, 577, 575, 2177, 563, 567, 1857, 569, 573, 1859, 2139, 2181, 2183, 2185, 2147, 2140, 2179},
        unavailable = {2186, 2187},
    },
    [479] = {}, -- Netherstorm
    [895] = {}, -- New Tinkertown
    [11] = {}, -- Northern Barrens
    [37] = {}, -- Northern Stranglethorn
    [864] = {}, -- Northshire
    [734] = { -- Old Hillsbrad Foothills
        652,
        heroic = {673},
    },
    [718] = {
        size10 = {4396, 4402, 4403, 4404},
        unavailable = {684},
    }, -- Onyxia's Lair
    [321] = {}, -- Orgrimmar
    [602] = { -- Pit of Saron
        4517,
        heroic = {4520, 4524, 4525},
    },
    [502] = {}, -- Plaguelands: The Scarlet Enclave
    [899] = {}, -- Proving Grounds
    [680] = {629}, -- Ragefire Chasm
    [760] = {636}, -- Razorfen Downs
    [761] = {635}, -- Razorfen Kraul
    [36] = {}, -- Redridge Mountains
    [717] = {689}, -- Ruins of Ahn'Qiraj
    [685] = {}, -- Ruins of Gilneas City
    [684] = {}, -- Ruins of Gilneas
    [871] = { -- Scarlet Halls
        7413,
        heroic = {6760, 6684, 6427},
    },
    [874] = { -- Scarlet Monastery
        637,
        heroic = {6761, 6929, 6928},
    },
    [898] = { -- Scholomance
        645,
        heroic = {6762, 6531, 6394, 6396, 6821},
    },
    [763] = {}, -- ScholomanceOLD
    [28] = {}, -- Searing Gorge
    [780] = {694, 144}, -- Serpentshrine Cavern
    [723] = { -- Sethekk Halls
        653,
        heroic = {674},
    },
    [877] = { -- Shado-Pan Monastery
        6469,
        heroic = {6470, 6471, 6477, 6472},
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
    [473] = {}, -- Shadowmoon Valley
    [481] = {}, -- Shattrath City
    [615] = {}, -- Shimmering Expanse
    [493] = {}, -- Sholazar Basin
    [905] = {}, -- Shrine of Seven Stars
    [903] = {}, -- Shrine of Two Moons
    [887] = { -- Siege of Niuzao Temple
        heroic = {6763, 6485, 6822, 6688},
    },
    [261] = {}, -- Silithus
    [480] = {}, -- Silvermoon City
    [21] = {}, -- Silverpine Forest
    [860] = {}, -- Silvershard Mines
    [607] = {}, -- Southern Barrens
    [81] = {}, -- Stonetalon Mountains
    [876] = { -- Stormstout Brewery
        6457,
        heroic = {6456, 6420, 6089},
    },
    [301] = {}, -- Stormwind City
    [512] = {}, -- Strand of the Ancients
    [689] = {}, -- Stranglethorn Vale
    [765] = {646}, -- Stratholme
    [893] = {}, -- Sunstrider Isle
    [789] = {698}, -- Sunwell Plateau
    [38] = {}, -- Swamp of Sorrows
    [161] = {}, -- Tanaris
    [41] = {}, -- Teldrassil
    [782] = {696}, -- Tempest Keep
    [881] = {}, -- Temple of Kotmogu
    [867] = { -- Temple of the Jade Serpent
        6757,
        heroic = {6758, 6475, 6460, 6671},
    },
    [478] = {}, -- Terokkar Forest
    [886] = { -- Terrace of Endless Spring
        heroic = {6733, 6731, 6734, 6732},
    },
    [731] = { -- The Arcatraz
        660,
        heroic = {681},
    },
    [758] = {}, -- The Bastion of Twilight
    [677] = {}, -- The Battle for Gilneas (Old City Map)
    [736] = {}, -- The Battle for Gilneas
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
    [673] = {}, -- The Cape of Stranglethorn
    [521] = { -- The Culling of Stratholme
        479,
        heroic = {500, 1872, 1817},
    },
    [756] = {
        628,
        heroic = {5083, 5370, 5369, 5368, 5367, 5366, 5371},
    }, -- The Deadmines
    [471] = {}, -- The Exodar
    [527] = {
        size10 = {622, 1874, 2148, 1869},
    }, -- The Eye of Eternity
    [601] = { -- The Forge of Souls
        4516,
        heroic = {4519, 4522, 4523},
    },
    [26] = {}, -- The Hinterlands
    [806] = {}, -- The Jade Forest
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
    [768] = {
        4846,
        heroic = {5063, 5287},
    }, -- The Stonecore
    [495] = {}, -- The Storm Peaks
    [687] = {641}, -- The Temple of Atal'Hakkar
    [726] = { -- The Underbog
        650,
        heroic = {670},
    },
    [873] = {}, -- The Veiled Stair
    [536] = { -- The Violet Hold
        483,
        heroic = {494, 2153, 1865, 2041, 1816},
    },
    [769] = { -- The Vortex Pinnacle
        4847,
        heroic = {5289, 5064, 5288},
    },
    [808] = {}, -- The Wandering Isle
    [61] = {}, -- Thousand Needles
    [773] = {}, -- Throne of the Four Winds
    [767] = { -- Throne of the Tides
        4839,
        heroic = {5061, 5285, 5286},
    },
    [930] = { -- Throne of Thunder
        heroic = {8124, 8067},
    },
    [362] = {}, -- Thunder Bluff
    [20] = {}, -- Tirisfal Glades
    [709] = {}, -- Tol Barad Peninsula
    [708] = {}, -- Tol Barad
    [810] = {}, -- Townlong Steppes
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
    [770] = {}, -- Twilight Highlands
    [626] = {}, -- Twin Peaks
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
    [748] = {}, -- Uldum
    [201] = {}, -- Un'Goro Crater
    [382] = {}, -- Undercity
    [882] = {}, -- Unga Ingoo
    [523] = { -- Utgarde Keep
        477,
        heroic = {489, 1919},
    },
    [524] = {
        488,
        heroic = {499, 1873, 2043, 2156, 2157},
    }, -- Utgarde Pinnacle
    [811] = {}, -- Vale of Eternal Blossoms
    [807] = {}, -- Valley of the Four Winds
    [889] = {}, -- Valley of Trials
    [613] = {}, -- Vashj'ir
    [532] = { -- Vault of Archavon
        size10 = {1722, 3136, 3836, 4016},
        size25 = {1721, 3137, 3837, 4017},
    },
    [749] = {630}, -- Wailing Caverns
    [443] = {}, -- Warsong Gulch
    [816] = {}, -- Well of Eternity
    [22] = {}, -- Western Plaguelands
    [39] = {}, -- Westfall
    [40] = {}, -- Wetlands
    [501] = {}, -- Wintergrasp
    [281] = {}, -- Winterspring
    [883] = {}, -- Zan'vess
    [467] = {}, -- Zangarmarsh
    [781] = { -- Zul'Aman
        unavailable = {691},
    },
    [496] = {}, -- Zul'Drak
    [686] = {639}, -- Zul'Farrak
    [793] = { -- Zul'Gurub
        unavailable = {688, 560, 957},
    },
}

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
    [23] = 4892, -- Eastern Plaguelands
    [182] = 4931, -- Felwood
    [492] = 40, -- Icecrown
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
    [748] = 4872, -- Uldum
    [201] = 4939, -- Un'Goro Crater
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
    quests[610] = 4869 -- Kelp'thar Forest
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
    quests[610] = 4982 -- Kelp'thar Forest
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

