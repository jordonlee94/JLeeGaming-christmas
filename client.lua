print('[jlee_xmas] client.lua loaded')

local QBCore = exports['qb-core']:GetCoreObject()
local spawnedTrees = {}

local function debugPrint(...)
    if Config.Debug then
        print('[jlee_xmas]', ...)
    end
end

--==============================
-- Tree Spawning (Exact Config Placement, Z lowered by 1.0)
--==============================
local function spawnTrees()
    local model = Config.TreeProp
    RequestModel(model)
    local timeout = 1000
    while not HasModelLoaded(model) and timeout > 0 do
        Citizen.Wait(10)
        timeout = timeout - 10
    end
    if not HasModelLoaded(model) then
        debugPrint('Failed to load model for trees', tostring(model))
        return
    end

    for i, v in ipairs(Config.TreeLocations) do
        local tx = v.x or v[1]
        local ty = v.y or v[2]
        local tz = (v.z or v[3]) - 1.0  -- 👈 LOWER Z BY 1.0 HERE
        local theading = v.heading or v.w or v[4] or 0.0

        -- Ensure world & collision are loaded
        RequestCollisionAtCoord(tx, ty, tz)
        local tries = 0
        while not HasCollisionLoadedAroundEntity(PlayerPedId()) and tries < 50 do
            Citizen.Wait(100)
            tries = tries + 1
        end

        -- Spawn the object exactly at config coords (Z lowered)
        local obj = CreateObjectNoOffset(model, tx, ty, tz, false, false, false)
        if DoesEntityExist(obj) then
            SetEntityAsMissionEntity(obj, true, true)
            SetEntityHeading(obj, theading)
            SetEntityCoordsNoOffset(obj, tx, ty, tz, false, false, false)
            SetEntityCollision(obj, true, true)
            FreezeEntityPosition(obj, true)

            spawnedTrees[i] = obj
            debugPrint(('Tree #%d spawned at %.2f %.2f %.2f (Z lowered by 1.0)'):format(i, tx, ty, tz))

            -- Add qb-target interaction
            if exports['qb-target'] and exports['qb-target'].AddTargetEntity then
                local idx = i
                exports['qb-target']:AddTargetEntity(obj, {
                    options = {
                        {
                            type = 'client',
                            icon = 'fas fa-gift',
                            label = Config.TargetLabel or 'Open Gift',
                            action = function(entity)
                                TriggerEvent('jlee_xmas:clientAttemptLoot', { index = idx })
                            end
                        }
                    },
                    distance = Config.InteractionDistance or 2.0
                })
            end
        else
            debugPrint(('Tree #%s creation failed for model %s at %.2f, %.2f, %.2f'):format(i, tostring(model), tx, ty, tz))
        end
    end
end

--==============================
-- Cleanup Trees
--==============================
local function cleanupTrees()
    for i, obj in pairs(spawnedTrees) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    spawnedTrees = {}
end

--==============================
-- Loot Handling
--==============================
RegisterNetEvent('jlee_xmas:clientAttemptLoot', function(data)
    local bestIndex = nil
    if data and data.index then
        bestIndex = tonumber(data.index)
    else
        local ped = PlayerPedId()
        local ppos = GetEntityCoords(ped)
        local bestDist
        for i, v in ipairs(Config.TreeLocations) do
            local tx, ty, tz = v.x or v[1], v.y or v[2], (v.z or v[3]) - 1.0
            local dist = #(vector3(tx, ty, tz) - ppos)
            if not bestDist or dist < bestDist then
                bestDist = dist
                bestIndex = i
            end
        end
    end
    if not bestIndex then return end

    QBCore.Functions.TriggerCallback('jlee_xmas:canLoot', function(canLoot)
        if not canLoot then
            QBCore.Functions.Notify('This tree has already been looted.', 'error')
            return
        end

        local duration = (Config.Animation and Config.Animation.duration) or 3
        local durationMs = duration * 1000

        local function playLootAnim()
            if Config.PlayAnimation then
                local anim = Config.Animation
                if anim and anim.dict and anim.name then
                    RequestAnimDict(anim.dict)
                    local timeout = 2000
                    while not HasAnimDictLoaded(anim.dict) and timeout > 0 do
                        Citizen.Wait(10)
                        timeout = timeout - 10
                    end
                    local ped = PlayerPedId()
                    if HasAnimDictLoaded(anim.dict) then
                        TaskPlayAnim(ped, anim.dict, anim.name, 8.0, -8.0, durationMs, 49, 0, false, false, false)
                        Citizen.SetTimeout(durationMs, function()
                            ClearPedTasks(ped)
                        end)
                    end
                end
            end
        end

        if QBCore.Functions.Progressbar then
            playLootAnim()
            QBCore.Functions.Progressbar('jlee_xmas_loot_' .. tostring(bestIndex), 'Looting tree...', durationMs, false, true, {
                disableMovement = true,
                disableCombat = true
            }, {}, {}, {}, function()
                TriggerServerEvent('jlee_xmas:lootTree', bestIndex)
                ClearPedTasks(PlayerPedId())
            end, function()
                ClearPedTasks(PlayerPedId())
                QBCore.Functions.Notify('Loot cancelled', 'error')
            end)
        else
            playLootAnim()
            Citizen.Wait(durationMs)
            TriggerServerEvent('jlee_xmas:lootTree', bestIndex)
        end
    end, bestIndex)
end)

RegisterNetEvent('jlee_xmas:treeLooted', function(index)
    index = tonumber(index)
    if not index then return end
    local ent = spawnedTrees[index]
    if ent and DoesEntityExist(ent) then
        DeleteEntity(ent)
        spawnedTrees[index] = nil
    end
end)

--==============================
-- Trade-In Ped Setup
--==============================
local function setupTradeInTarget()
    if not (exports['qb-target'] and exports['qb-target'].AddTargetEntity) then return end
    local loc = Config.TradeIn and Config.TradeIn.Location
    if not loc then return end

    local pedEntity = nil
    if Config.TradeIn.PedModel then
        local model = GetHashKey(Config.TradeIn.PedModel)
        RequestModel(model)
        local t = 1000
        while not HasModelLoaded(model) and t > 0 do
            Citizen.Wait(10)
            t = t - 10
        end
        if HasModelLoaded(model) then
            pedEntity = CreatePed(4, model, loc.x, loc.y, loc.z - 1.0, Config.TradeIn.PedHeading or 0.0, false, true)
            SetEntityHeading(pedEntity, Config.TradeIn.PedHeading or 0.0)
            FreezeEntityPosition(pedEntity, true)
            SetEntityInvincible(pedEntity, true)
            SetBlockingOfNonTemporaryEvents(pedEntity, true)
            SetPedCanRagdollFromPlayerImpact(pedEntity, false)
        end
    end

    local options = {
        {
            type = 'client',
            icon = 'fas fa-coins',
            label = 'Trade Christmas Coins',
            action = function()
                if exports['qb-menu'] and exports['qb-menu'].openMenu then
                    local menu = {
                        { header = 'Trade Christmas Coins', isMenuHeader = true },
                        { header = 'Small Box - ' .. (Config.TradeIn.Costs.small or 0) .. ' coins', txt = 'Receive: ' .. (Config.TradeIn.Items.small or 'small box'), params = { event = 'jlee_xmas:clientRequestTrade', args = 'small' } },
                        { header = 'Medium Box - ' .. (Config.TradeIn.Costs.medium or 0) .. ' coins', txt = 'Receive: ' .. (Config.TradeIn.Items.medium or 'medium box'), params = { event = 'jlee_xmas:clientRequestTrade', args = 'medium' } },
                        { header = 'Large Box - ' .. (Config.TradeIn.Costs.large or 0) .. ' coins', txt = 'Receive: ' .. (Config.TradeIn.Items.large or 'large box'), params = { event = 'jlee_xmas:clientRequestTrade', args = 'large' } },
                    }
                    exports['qb-menu']:openMenu(menu)
                else
                    TriggerServerEvent('jlee_xmas:tradeForBox', 'small')
                end
            end
        }
    }

    if pedEntity and DoesEntityExist(pedEntity) then
        exports['qb-target']:AddTargetEntity(pedEntity, { options = options, distance = Config.TradeIn.Distance or 2.0 })
    end
end

-- Client handler to forward qb-menu selection to server
RegisterNetEvent('jlee_xmas:clientRequestTrade', function(boxType)
    if not boxType then return end
    TriggerServerEvent('jlee_xmas:tradeForBox', boxType)
end)

-- Client handler to play open-box animation/progress when server initiates
RegisterNetEvent('jlee_xmas:playOpenBox', function(data)
    if not data or not data.token or not data.duration then return end
    local token = data.token
    local duration = tonumber(data.duration) or 10

    local function playAnimAndProgress()
        if Config.PlayAnimation then
            local anim = Config.Animation
            if anim and anim.dict and anim.name then
                RequestAnimDict(anim.dict)
                local timeout = 2000
                while not HasAnimDictLoaded(anim.dict) and timeout > 0 do
                    Citizen.Wait(10)
                    timeout = timeout - 10
                end
                if HasAnimDictLoaded(anim.dict) then
                    TaskPlayAnim(PlayerPedId(), anim.dict, anim.name, 8.0, -8.0, duration * 1000, 49, 0, false, false, false)
                end
            end
        end

        if QBCore.Functions.Progressbar then
            QBCore.Functions.Progressbar('jlee_xmas_openbox_' .. tostring(token), 'Opening box...', duration * 1000, false, true, {
                disableMovement = true,
                disableCombat = true
            }, {}, {}, {}, function()
                ClearPedTasks(PlayerPedId())
                TriggerServerEvent('jlee_xmas:finishOpenBox', token)
            end, function()
                ClearPedTasks(PlayerPedId())
                QBCore.Functions.Notify('Opening cancelled', 'error')
            end)
        else
            Citizen.Wait(duration * 1000)
            ClearPedTasks(PlayerPedId())
            TriggerServerEvent('jlee_xmas:finishOpenBox', token)
        end
    end

    CreateThread(function()
        playAnimAndProgress()
    end)
end)

--==============================
-- Startup
--==============================
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) or not DoesEntityExist(PlayerPedId()) do
        Citizen.Wait(500)
    end

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    while not HasCollisionLoadedAroundEntity(ped) do
        Citizen.Wait(250)
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    end

    Citizen.Wait(3000)
    spawnTrees()
    setupTradeInTarget()

    if Config.TradeIn and Config.ShowTradeBlip then
        local loc = Config.TradeIn.Location
        local blip = AddBlipForCoord(loc.x, loc.y, loc.z)
        SetBlipSprite(blip, 621)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 46)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Christmas Trade')
        EndTextCommandSetBlipName(blip)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    cleanupTrees()
end)
