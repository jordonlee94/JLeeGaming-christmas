-- JleeGaming Christmas Script Config

Config = {}

Config.TreeProp = `prop_xmas_tree_int`

-- Interaction distance for qb-target
Config.InteractionDistance = 2.0


Config.TreeCooldown = 300 -- 5 minutes (0 disables)



Config.Rewards = {
    { type = 'money', method = 'cash', amount = 50 },
    { type = 'item', name = 'vusliders', amount = 1 },
    { type = 'item', name = 'bscoke', amount = 1 },
    -- coin rewarded from trees
    { type = 'item', name = 'christmas_coin', amount = 1 },
}


Config.TradeIn = {
    Location = { x =127.64, y = -1028.87, z = 29.45 }, -- change to desired coords
    Distance = 2.0,
    PedModel = 'a_m_m_business_01', -- ped model to spawn at trade location (set to nil to disable ped)
    PedHeading = 0.0,
    -- cost in coins for each box
    Costs = {
        small = 5,
        medium = 12,
        large = 25,
    },
    CoinItem = 'christmas_coin',
    -- item names given for boxes
    Items = {
        small = 'christmas_box_small',
        medium = 'christmas_box_medium',
        large = 'christmas_box_large',
    }
}



Config.BoxRewards = {
    small = {
        count = 3, -- number of random entries to give when opening
        pool = {
       { type = 'money', method = 'cash', amount = 2500 },
    { type = 'item', name = 'vusliders', amount = 5 },
    { type = 'item', name = 'bscoke', amount = 5 },
        }
    },
    medium = {
        count = 3,
        pool = {
       { type = 'money', method = 'cash', amount = 5000 },
    { type = 'item', name = 'vusliders', amount = 10 },
    { type = 'item', name = 'bscoke', amount = 10 },
        }
    },
    large = {
        count = 3,
        pool = {
         { type = 'money', method = 'cash', amount = 7500 },
       { type = 'item', name = 'vusliders', amount = 10 },
    { type = 'item', name = 'bposting_tablet', amount = 1 },
        }
    }
}


Config.TreeLocations = {
  vector4(223.45, -796.70, 30.77, 71),
  vector4(226.63, -788.12, 30.77, 66),
 vector4(228.82, -782.30, 30.77, 74),
 vector4(188.39, -859.70, 30.94, 55),
vector4(282.68, -593.55, 43.38, 255),
 vector4(285.31, -587.41, 43.38, 260),
 vector4(287.34, -581.26, 43.38, 246),
vector4(306.16, -587.21, 43.19, 52),
vector4(424.07, -973.71, 30.71, 93),
vector4(424.36, -983.86, 30.71, 95),
vector4(412.89, -1016.33, 29.33, 6),
vector4(-1024.86, -1511.79, 5.59, 124),
vector4(-1015.86, -1524.10, 5.59, 131),
vector4(-1008.92, -1509.30, 5.79, 132),
vector4(539.57, -174.07, 54.48, 102),
vector4(-1663.89, -1019.85, 13.02, 317),
vector4(-1673.09, -1031.53, 13.02, 328),
vector4(-1679.15, -1038.33, 13.02, 140),
vector4(-1663.97, -1113.45, 13.08, 151),
vector4(-1875.33, -1305.73, 3.07, 259),
vector4(-1879.72, -1290.40, 3.07, 302),
vector4(-1888.93, -1282.83, 3.07, 332),
vector4(-1902.00, -1280.65, 3.07, 4),
vector4(-1904.04, -1310.05, 3.05, 311),
vector4(-1928.25, -1340.46, 3.05, 149),
vector4(203.04, -895.04, 30.16, 185),
vector4(171.44, -949.55, 30.96, 263),
vector4(847.23, -888.25, 25.25, 280),
vector4(847.47, -896.99, 25.25, 271),
vector4(832.70, -886.12, 25.25, 186),
vector4(837.79, -886.20, 25.25, 177),

   
}

Config.TargetLabel = "Loot Christmas Tree"

Config.PlayAnimation = true
Config.Animation = {
    dict = "amb@prop_human_bum_bin@idle_b",
    name = "idle_d",
    duration = 2
}


Config.RequiredItem = nil


Config.ShowTradeBlip = true
Config.Debug = false
