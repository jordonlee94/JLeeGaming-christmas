local QBCore = exports['qb-core']:GetCoreObject()

-- Cache commonly used config values to avoid deep table lookups
local CFG = Config
local TREE_LOCATIONS = CFG.TreeLocations or {}
local TRADE_ITEMS = (CFG.TradeIn and CFG.TradeIn.Items) or {}
local TRADE_COSTS = (CFG.TradeIn and CFG.TradeIn.Costs) or {}
local TRADE_COIN = CFG.TradeIn and CFG.TradeIn.CoinItem

-- Seed RNG once
math.randomseed(os.time())

-- Server side state for looted trees (in-memory)
local LootedTrees = {}
local PendingOp = {}




-- Load on start (no persistence)
-- Per-player cooldowns / rate-limits
local PlayerLastAction = {} -- [src] = timestamp of last loot/trade attempt
local PlayerAttempts = {} -- [src] = {count = n, windowStart = ts}
local PlayerPositions = {} -- [src] = { x=, y=, z=, ts= } (updated periodically from clients)


local PendingTokenCounter = 0 -- incremental token counter (avoids math.random for every op)

local function debugPrint(...)
    if CFG.Debug then
        print("[jlee_xmas]", ...)
    end
end

-- Periodic sweeper to clean expired LootedTrees and stale PlayerPositions/PendingOp
CreateThread(function()
    while true do
        local now = os.time()
        -- sweep looted trees
        local changed = false
        for idx, expiry in pairs(LootedTrees) do
            if expiry and expiry <= now then
                LootedTrees[idx] = nil
                changed = true
            end
        end
        if changed then end
        -- sweep stale player positions older than 90s
        for src, p in pairs(PlayerPositions) do
            if not p.ts or now - p.ts > 90 then
                PlayerPositions[src] = nil
            end
        end
        -- clear pending ops older than BOX_OPEN_DURATION + 60
        for src, p in pairs(PendingOp) do
            if p.start and now - p.start > (tonumber(CFG.BoxOpenDuration) or 10) + 60 then
                PendingOp[src] = nil
            end
        end
        Citizen.Wait(30 * 1000)
    end
end)

-- Validate reward entry and give to player (optimized: precompute weights once)
local _RewardPool = nil -- cached table: { rewards = {...}, weights = {...}, total = number }
local function _buildRewardPool()
    local rewards = Config.Rewards or {}
    local pool = { rewards = rewards, weights = {}, total = 0 }
    if #rewards == 0 then return pool end
    local targetName = 'christmas_coin'
    local otherCount = 0
    for i, r in ipairs(rewards) do
        if r.type == 'item' and r.name == targetName then
            pool.weights[i] = 35
            pool.total = pool.total + 35
        else
            otherCount = otherCount + 1
        end
    end
    local remaining = 65
    if otherCount > 0 then
        local per = remaining / otherCount
        for i, r in ipairs(rewards) do
            if not pool.weights[i] then
                pool.weights[i] = per
                pool.total = pool.total + per
            end
        end
    else
        for i, r in ipairs(rewards) do
            if not pool.weights[i] then pool.weights[i] = 0 end
        end
    end
    return pool
end

local function GiveReward(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end
    if not _RewardPool then _RewardPool = _buildRewardPool() end
    local rewards = _RewardPool.rewards
    if not rewards or #rewards == 0 then return false end
    local total = _RewardPool.total
    if total <= 0 then
        -- fallback to uniform random
        local pick = rewards[ math.random(1, #rewards) ]
        rewards = { pick }
        total = 1
    end
    local pick = math.random() * total
    local acc = 0
    local chosen = nil
    for i, r in ipairs(rewards) do
        acc = acc + (_RewardPool.weights[i] or 0)
        if pick <= acc then chosen = r break end
    end
    if not chosen then chosen = rewards[ math.random(1, #rewards) ] end

    if chosen.type == 'money' then
        local method = chosen.method or 'cash'
        local amount = tonumber(chosen.amount) or 0
        if amount > 0 then
            player.Functions.AddMoney(method, amount)
            return { type = 'money', method = method, amount = amount }
        end
    elseif chosen.type == 'item' then
        local name = chosen.name
        local amount = tonumber(chosen.amount) or 1
        if name then
            local ok = player.Functions.AddItem(name, amount)
            if ok then return { type = 'item', name = name, amount = amount } end
        end
    end
    return false
end

-- helper: give a configured reward entry (used for boxes)
local function GiveConfiguredReward(src, reward)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end
    if reward.type == 'money' then
        local method = reward.method or 'cash'
        local amount = tonumber(reward.amount) or 0
        if amount > 0 then
            player.Functions.AddMoney(method, amount)
            return true, { type = 'money', method = method, amount = amount }
        end
    elseif reward.type == 'item' then
        local name = reward.name
        local amount = tonumber(reward.amount) or 1
        if name then
            local ok = player.Functions.AddItem(name, amount)
            if ok then
                return true, { type = 'item', name = name, amount = amount }
            end
        end
    end
    return false
end

-- Server event: client requests to loot a tree index
RegisterNetEvent('jlee_xmas:lootTree', function(index)
    local src = source
    index = tonumber(index)
    -- received loot request

    if not index or not Config.TreeLocations[index] then
        print('[jlee_xmas] Invalid index from', src, index)
        debugPrint('Invalid index from', src, index)
        return
    end

    -- basic rate-limits to prevent spamming/flooding
    local now = os.time()
    local minInterval = Config.MinPlayerInterval or 2 -- seconds between actions per-player
    if PlayerLastAction[src] and now - PlayerLastAction[src] < minInterval then
        debugPrint('Player', src, 'is spamming loot requests')
        return
    end
    PlayerLastAction[src] = now

    -- per-minute attempt window
    local window = 60
    local maxAttempts = Config.MaxAttemptsPerMinute or 30
    local pa = PlayerAttempts[src]
    if not pa or now - pa.windowStart >= window then
        PlayerAttempts[src] = { count = 1, windowStart = now }
    else
        pa.count = pa.count + 1
        if pa.count > maxAttempts then
            debugPrint('Player', src, 'exceeded attempts per minute')
            return
        end
    end

    -- optional required item check
    if Config.RequiredItem then
        local player = QBCore.Functions.GetPlayer(src)
        if not player or not player.Functions.GetItemByName(Config.RequiredItem) then
            debugPrint('Player', src, 'missing required item', Config.RequiredItem)
            TriggerClientEvent('QBCore:Notify', src, 'You need a ' .. Config.RequiredItem .. ' to loot this.', 'error')
            return
        end
        -- optionally consume required item on use (configurable)
        if Config.ConsumeRequiredItem then
            local removed = player.Functions.RemoveItem(Config.RequiredItem, 1)
            if not removed then
                TriggerClientEvent('QBCore:Notify', src, 'Could not consume required item.', 'error')
                return
            end
        end
    end

    -- Check cooldown/state
    if LootedTrees[index] and LootedTrees[index] > now then
        debugPrint('Tree '..tostring(index)..' already looted until '..tostring(LootedTrees[index]))
        TriggerClientEvent('QBCore:Notify', src, 'This tree has already been looted.', 'error')
        return
    end

    -- mark immediately to avoid race conditions where multiple requests race to give rewards
    if CFG.TreeCooldown and CFG.TreeCooldown > 0 then
        LootedTrees[index] = now + CFG.TreeCooldown
        -- rely on sweeper thread to clear expired entries
    else
        LootedTrees[index] = math.huge
    end
    -- persist updated state


    -- Give reward (after marking to avoid duping)
    local result = GiveReward(src)
    if not result then
        -- rollback
        LootedTrees[index] = nil
        print('[jlee_xmas] Failed to give reward to', src)
        TriggerClientEvent('QBCore:Notify', src, 'Failed to give reward.', 'error')
        return
    end



    -- Trees remain visible after looting; do not notify clients to remove props.
    debugPrint('Tree', index, 'was looted but left visible')

    debugPrint('Giving result to', src, result.type, result.amount or result.name)

    -- Notify player
    if result.type == 'money' then
        TriggerClientEvent('QBCore:Notify', src, 'You found '..tostring(result.amount)..' '..(result.method or 'cash'), 'success')
    elseif result.type == 'item' then
        -- show friendly item label if available
        local itemDef = QBCore.Shared.Items[result.name]
        local label = itemDef and itemDef.label or result.name
        TriggerClientEvent('QBCore:Notify', src, 'You received '..tostring(result.amount)..'x '..label, 'success')
        -- qb-inventory item box (if inventory resource present)
        if itemDef then
            TriggerClientEvent('inventory:client:ItemBox', src, itemDef, 'add')
        end
    end

    debugPrint('Player', src, 'looted tree', index)
end)

-- Provide a server callback to check if a tree is currently loot-able (used by client)
QBCore.Functions.CreateCallback('jlee_xmas:canLoot', function(source, cb, index)
    index = tonumber(index)
    if not index or not Config.TreeLocations[index] then
        cb(false)
        return
    end
    local now = os.time()
    if LootedTrees[index] and LootedTrees[index] > now then
        cb(false)
    else
        cb(true)
    end
end)

-- Trade-in server event: exchange coins for boxes
RegisterNetEvent('jlee_xmas:tradeForBox', function(boxType)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    -- basic rate limiting
    local now = os.time()
    local minInterval = Config.MinPlayerInterval or 2
    if PlayerLastAction[src] and now - PlayerLastAction[src] < minInterval then
        debugPrint('Player', src, 'is spamming trade requests')
        return
    end
    PlayerLastAction[src] = now

    boxType = tostring(boxType or '')
    if not Config.TradeIn.Items[boxType] then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid box type.', 'error')
        return
    end
    local cost = Config.TradeIn.Costs[boxType]
    if not cost or cost <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid cost.', 'error')
        return
    end
    local coinItem = player.Functions.GetItemByName(Config.TradeIn.CoinItem)
    local have = coinItem and coinItem.amount or 0
    if have < cost then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough Christmas Coins.', 'error')
        return
    end
    -- remove coins and give box
    local removed = player.Functions.RemoveItem(Config.TradeIn.CoinItem, cost)
    if not removed then
        TriggerClientEvent('QBCore:Notify', src, 'Could not remove coins.', 'error')
        return
    end
    local boxItem = Config.TradeIn.Items[boxType]
    local gave = player.Functions.AddItem(boxItem, 1)
    if gave then
        TriggerClientEvent('QBCore:Notify', src, 'You received a '..boxType..' box!', 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Could not give box item.', 'error')
    end
end)

-- Box opening handlers (usable items)
-- We'll perform the item removal server-side, then ask the client to play
-- the open animation/progress and confirm back. A pending table with a
-- token and timestamp prevents simple client-side bypassing.

local BOX_OPEN_DURATION = tonumber(Config.BoxOpenDuration) or 10 -- seconds (uniform server-side duration)

local function startOpenBox(src, boxCategory)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    -- rate limit usage of boxes
    local now = os.time()
    local minInterval = Config.MinPlayerInterval or 1
    if PlayerLastAction[src] and now - PlayerLastAction[src] < minInterval then
        debugPrint('Player', src, 'is spamming openBox')
        return
    end
    PlayerLastAction[src] = now

    local cfg = Config.BoxRewards[boxCategory]
    if not cfg or not cfg.pool or #cfg.pool <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'This box is empty.', 'error')
        return
    end
    -- remove the box item from player (must succeed to prevent duping)
    local boxItemName = Config.TradeIn.Items[boxCategory]
    if boxItemName then
        local removed = player.Functions.RemoveItem(boxItemName, 1)
        if not removed then
            TriggerClientEvent('QBCore:Notify', src, 'You do not have that box.', 'error')
            return
        end
    end

    -- create a pending operation with a token
    -- use incremental token to avoid heavy RNG calls and collisions
    PendingTokenCounter = PendingTokenCounter + 1
    local token = PendingTokenCounter
    PendingOp[src] = { token = token, start = now, boxCategory = boxCategory }
    -- send client event to play animation/progress (client cannot give rewards directly)
    TriggerClientEvent('jlee_xmas:playOpenBox', src, { token = token, duration = BOX_OPEN_DURATION })
    -- rely on sweeper thread to clear stale PendingOp entries
end

local function finishOpenBox(src, token)
    local now = os.time()
    local pending = PendingOp[src]
    if not pending or pending.token ~= token then
        debugPrint('Invalid or missing pending token from', src)
        return
    end
    local elapsed = now - pending.start
    -- allow small leeway but ensure server-side enforced duration
    if elapsed + 1 < BOX_OPEN_DURATION then
        debugPrint('Player', src, 'attempted to finish box too quickly (', elapsed, 's)')
        return
    end

    -- OK: perform reward giving
    local boxCategory = pending.boxCategory
    PendingOp[src] = nil

    local cfg = Config.BoxRewards[boxCategory]
    if not cfg or not cfg.pool or #cfg.pool <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'This box is empty.', 'error')
        return
    end

    local given = {}
    local messages = {}
    for i=1,(cfg.count or 1) do
        local pick = cfg.pool[ math.random(1, #cfg.pool) ]
        local ok, info = GiveConfiguredReward(src, pick)
        -- debug/logging to help troubleshoot missing rewards
        if not ok then
            debugPrint('GiveConfiguredReward failed for player', src, 'reward=', json.encode(pick))
        end
        if ok and info then
            table.insert(given, info)
            if info.type == 'money' then
                table.insert(messages, tostring(info.amount) .. ' ' .. (info.method or 'cash'))
            elseif info.type == 'item' then
                local itemDef = QBCore.Shared.Items[info.name]
                local label = itemDef and itemDef.label or info.name
                table.insert(messages, tostring(info.amount) .. 'x ' .. label)
                if itemDef then
                    TriggerClientEvent('inventory:client:ItemBox', src, itemDef, 'add')
                end
            end
        end
    end

    if #given == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Box contained nothing.', 'error')
    else
        local summary = table.concat(messages, ', ')
        TriggerClientEvent('QBCore:Notify', src, 'You opened the box and received: '..summary, 'success')
    end
end

-- Register usable items so players can "use" the boxes to open them (derived from Config)
-- Cache the registration functions locally to avoid repeated table lookups
local createUsable = QBCore.Functions.CreateUsableItem or QBCore.Functions.CreateUseableItem
if createUsable then
    for k,v in pairs(Config.TradeIn.Items or {}) do
        -- wrap k into a local to preserve value in closure
        local boxKey = k
        createUsable(v, function(source)
            startOpenBox(source, boxKey)
        end)
    end
else
    for k,v in pairs(Config.TradeIn.Items or {}) do
        debugPrint('No usable item registration function found on QBCore.Functions for item', v)
    end
end

-- Client will call this to confirm they've finished the opening sequence
RegisterNetEvent('jlee_xmas:finishOpenBox', function(token)
    local src = source
    finishOpenBox(src, token)
end)

-- Handle client position updates (clients should periodically send their coords)
RegisterNetEvent('jlee_xmas:updatePosition', function(pos)
    local src = source
    if type(pos) == 'table' and pos.x and pos.y and pos.z then
        PlayerPositions[src] = { x = tonumber(pos.x), y = tonumber(pos.y), z = tonumber(pos.z), ts = os.time() }
    end
end)

-- Cleanup pending state and rate-limits when players disconnect to avoid memory leaks
AddEventHandler('playerDropped', function(reason)
    local src = source
    if PendingOp[src] then
        PendingOp[src] = nil
        debugPrint('Cleared pending op for disconnected player', src)
    end
    if PlayerLastAction[src] then
        PlayerLastAction[src] = nil
    end
    if PlayerAttempts[src] then
        PlayerAttempts[src] = nil
    end
    if PlayerPositions[src] then
        PlayerPositions[src] = nil
    end
end)

-- Optional console command to reset all trees
RegisterCommand('jlee_resettrees', function(source, args, raw)
    if source ~= 0 then return end
    LootedTrees = {}
    print('[jlee_xmas] All trees reset')
end, true)
