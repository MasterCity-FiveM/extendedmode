local isLoadoutLoaded, isPaused, isDead, isFirstSpawn, pickups = false, false, false, true, {}

CreateThread(function()
	while true do
		Wait(0)

		if NetworkIsPlayerActive(PlayerId()) then
			TriggerServerEvent('esx:onPlayerJoined')
			break
		end
	end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(playerData)
	ESX.PlayerLoaded = true
	ESX.PlayerData = playerData
	
	-- Removed some unnecessary statement here checking if you were Michael, it did nothing really.
	-- Was also kind of broken because anyone who has a SP save no using Michael wouldn't even get it.

	local playerPed = PlayerPedId()

	if Config.EnablePvP then
		SetCanAttackFriendly(playerPed, true, false)
		NetworkSetFriendlyFireOption(true)
	end

	if Config.EnableHud then
		for k,v in ipairs(playerData.accounts) do
			local accountTpl = '<div><img src="img/accounts/' .. v.name .. '.png"/>&nbsp;{{money}}</div>'
			ESX.UI.HUD.RegisterElement('account_' .. v.name, k, 0, accountTpl, {money = ESX.Math.GroupDigits(v.money)})
		end

		local jobTpl = '<div>{{job_label}} - {{grade_label}}</div>'

		if playerData.job.grade_label == '' or playerData.job.grade_label == playerData.job.label then
			jobTpl = '<div>{{job_label}}</div>'
		end

		ESX.UI.HUD.RegisterElement('job', #playerData.accounts, 0, jobTpl, {
			job_label = playerData.job.label,
			grade_label = playerData.job.grade_label
		})
	end

	-- Using spawnmanager now to spawn the player, this is the right way to do it, and it transitions better.
	exports.spawnmanager:spawnPlayer({
		x = playerData.coords.x,
		y = playerData.coords.y,
		z = playerData.coords.z,
		heading = playerData.coords.heading,
		model = Config.DefaultPlayerModel,
		skipFade = false
	}, function()
		isLoadoutLoaded = true
		TriggerServerEvent('esx:onPlayerSpawn')
		TriggerEvent('esx:onPlayerSpawn')
		TriggerEvent('esx:restoreLoadout')
	end)
end)

RegisterNetEvent('es:activateMoney')
AddEventHandler('es:activateMoney', function(money)
	ESX.PlayerData.money = money
end)

RegisterNetEvent('esx:setMaxWeight')
AddEventHandler('esx:setMaxWeight', function(newMaxWeight) ESX.PlayerData.maxWeight = newMaxWeight end)

AddEventHandler('esx:onPlayerSpawn', function() isDead = false end)
AddEventHandler('esx:onPlayerDeath', function() isDead = true end)
AddEventHandler('skinchanger:loadDefaultModel', function() isLoadoutLoaded = false end)

AddEventHandler('skinchanger:modelLoaded', function()
	while not ESX.PlayerLoaded do
		Wait(100)
	end

	TriggerEvent('esx:restoreLoadout')
end)

AddEventHandler('esx:restoreLoadout', function()
	local playerPed = PlayerPedId()
	local ammoTypes = {}
	
	ESX.TriggerServerCallback('esx:getPlayerData', function(ServerData)
		if ServerData and ServerData.loadout and #ServerData.loadout > 0 then
			RemoveAllPedWeapons(playerPed, true)

			for k,v in ipairs(ServerData.loadout) do
				local weaponName = v.name

				GiveWeaponToPed(playerPed, weaponName, 0, false, false)
				SetPedWeaponTintIndex(playerPed, weaponName, v.tintIndex)

				local ammoType = GetPedAmmoTypeFromWeapon(playerPed, weaponName)
				for k2,v2 in ipairs(v.components) do
					local componentHash = ESX.GetWeaponComponent(weaponName, v2).hash

					GiveWeaponComponentToPed(playerPed, weaponName, componentHash)
				end

				if not ammoTypes[ammoType] then
					AddAmmoToPed(playerPed, weaponName, v.ammo)
					ammoTypes[ammoType] = true
				end
				
				TriggerEvent("Master_Inventory:LoadAttachments", weaponName)
			end
		else
			RemoveAllPedWeapons(playerPed, true)
		end
		
		isLoadoutLoaded = true
	end)
	
end)

RegisterNetEvent('esx:setAccountMoney')
AddEventHandler('esx:setAccountMoney', function(account)
	for k,v in ipairs(ESX.PlayerData.accounts) do
		if v.name == account.name then
			ESX.PlayerData.accounts[k] = account
			break
		end
	end

	if Config.EnableHud then
		ESX.UI.HUD.UpdateElement('account_' .. account.name, {
			money = ESX.Math.GroupDigits(account.money)
		})
	end
end)

RegisterNetEvent('esx:addInventoryItem')
AddEventHandler('esx:addInventoryItem', function(item, count, showNotification, newItem)
	local found = false

	for k,v in ipairs(ESX.PlayerData.inventory) do
		if v.name == item then
			ESX.UI.ShowInventoryItemNotification(true, v.label, count - v.count)
			ESX.PlayerData.inventory[k].count = count

			found = true
			break
		end
	end

	-- If the item wasn't found in your inventory -> run
	if(found == false and newItem --[[Just a check if there is a newItem]])then
		-- Add item newItem to the players inventory
		ESX.PlayerData.inventory[#ESX.PlayerData.inventory + 1] = {
			name = newItem.name,
			count = count,
			label = newItem.label,
			weight = newItem.weight,
			limit = newItem.limit,
			usable = newItem.usable,
			rare = newItem.rare,
			canRemove = newItem.canRemove
		}

		-- Show a notification that a new item was added
		ESX.UI.ShowInventoryItemNotification(true, newItem.label, count)
	else
		-- Don't show this error for now
		-- print("^1[ExtendedMode]^7 Error: there is an error while trying to add an item to the inventory, item name: " .. item)
	end

	if showNotification then
		ESX.UI.ShowInventoryItemNotification(true, item, count)
	end

	if ESX.UI.Menu.IsOpen('default', 'es_extended', 'inventory') then
		ESX.ShowInventory()
	end
end)

RegisterNetEvent('esx:removeInventoryItem')
AddEventHandler('esx:removeInventoryItem', function(item, count, showNotification)
	for k,v in ipairs(ESX.PlayerData.inventory) do
		if v.name == item then
			ESX.UI.ShowInventoryItemNotification(false, v.label, v.count - count)
			ESX.PlayerData.inventory[k].count = count
			break
		end
	end

	if showNotification then
		ESX.UI.ShowInventoryItemNotification(false, item, count)
	end

	if ESX.UI.Menu.IsOpen('default', 'es_extended', 'inventory') then
		ESX.ShowInventory()
	end
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
end)

RegisterNetEvent('esx:setJobSub')
AddEventHandler('esx:setJobSub', function(job)
	if job ~= nil then
		job = tostring(job):upper()
	end
	
	ESX.PlayerData.job.job_sub = job
end)

RegisterNetEvent('esx:addWeapon')
AddEventHandler('esx:addWeapon', function(weaponName, ammo)
	-- Removed PlayerPedId() from being stored in a variable, not needed
	-- when it's only being used once, also doing it in a few
	-- functions below this one
	GiveWeaponToPed(PlayerPedId(), weaponName, ammo, false, false)
end)

RegisterNetEvent('esx:addWeaponComponent')
AddEventHandler('esx:addWeaponComponent', function(weaponName, weaponComponent)
	local componentHash = ESX.GetWeaponComponent(weaponName, weaponComponent).hash
	GiveWeaponComponentToPed(PlayerPedId(), weaponName, componentHash)
end)

RegisterNetEvent('esx:setWeaponAmmo')
AddEventHandler('esx:setWeaponAmmo', function(weaponName, weaponAmmo)
	SetPedAmmo(PlayerPedId(), weaponName, weaponAmmo)
end)

RegisterNetEvent('esx:setWeaponTint')
AddEventHandler('esx:setWeaponTint', function(weaponName, weaponTintIndex)
	SetPedWeaponTintIndex(PlayerPedId(), weaponName, weaponTintIndex)
end)

RegisterNetEvent('esx:removeWeapon')
AddEventHandler('esx:removeWeapon', function(weaponName)
	local playerPed = PlayerPedId()
	RemoveWeaponFromPed(playerPed, weaponName)
	SetPedAmmo(playerPed, weaponName, 0) -- remove leftover ammo
end)

RegisterNetEvent('esx:removeWeaponComponent')
AddEventHandler('esx:removeWeaponComponent', function(weaponName, weaponComponent)
	local componentHash = ESX.GetWeaponComponent(weaponName, weaponComponent).hash
	RemoveWeaponComponentFromPed(PlayerPedId(), weaponName, componentHash)
end)

RegisterNetEvent('esx:teleport')
AddEventHandler('esx:teleport', function(coords)
	-- The coords x, y and z were having 0.0 added to them here to make them floats
	-- Since we are forcing vectors in the teleport function now we don't need to do it
	ESX.Game.Teleport(PlayerPedId(), coords)
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	if Config.EnableHud then
		ESX.UI.HUD.UpdateElement('job', {
			job_label   = job.label,
			grade_label = job.grade_label
		})
	end
end)

RegisterNetEvent('esx:spawnVehicle')
AddEventHandler('esx:spawnVehicle', function(vehicle)
	if IsModelInCdimage(vehicle) then
		local playerPed = PlayerPedId()
		local playerCoords, playerHeading = GetEntityCoords(playerPed), GetEntityHeading(playerPed)

		ESX.Game.SpawnVehicle(vehicle, playerCoords, playerHeading, function(vehicle)
			TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
		end)
	else
		TriggerEvent('chat:addMessage', { args = { '^1SYSTEM', 'Invalid vehicle model.' } })
	end
end)

-- Removed drawing pickups here immediately and decided to add them to a table instead
-- Also made createMissingPickups use the other pickup function instead of having the
-- same code twice, further down we cull pickups when not needed

function AddPickup(pickupId, pickupLabel, pickupCoords, pickupType, pickupName, pickupComponents, pickupTint)
	pickups[pickupId] = {
		label = pickupLabel,
		textRange = false,
		coords = pickupCoords,
		type = pickupType,
		name = pickupName,
		components = pickupComponents,
		tint = pickupTint,
		object = nil,
		deleteNow = false
	}
end

RegisterNetEvent('esx:createPickup')
AddEventHandler('esx:createPickup', function(pickupId, label, playerId, pickupType, name, components, tintIndex, isInfinity, pickupCoords)
    local playerPed, entityCoords, forward, objectCoords
    
    if isInfinity then
        objectCoords = pickupCoords
    else
        playerPed = GetPlayerPed(GetPlayerFromServerId(playerId))
        entityCoords = GetEntityCoords(playerPed)
        forward = GetEntityForwardVector(playerPed)
        objectCoords = (entityCoords + forward * 1.0)
    end

    AddPickup(pickupId, label, objectCoords, pickupType, name, components, tintIndex)
end)

RegisterNetEvent('esx:createMissingPickups')
AddEventHandler('esx:createMissingPickups', function(missingPickups)
	for pickupId, pickup in pairs(missingPickups) do
		AddPickup(pickupId, pickup.label, vec(pickup.coords.x, pickup.coords.y, pickup.coords.z), pickup.type, pickup.name, pickup.components, pickup.tintIndex)
	end
end)

RegisterNetEvent('esx:registerSuggestions')
AddEventHandler('esx:registerSuggestions', function(registeredCommands)
	for name,command in pairs(registeredCommands) do
		if command.suggestion then
			TriggerEvent('chat:addSuggestion', ('/%s'):format(name), command.suggestion.help, command.suggestion.arguments)
		end
	end
end)

RegisterNetEvent('esx:removePickup')
AddEventHandler('esx:removePickup', function(id)
	local pickup = pickups[id]
	if pickup and pickup.object then
		ESX.Game.DeleteObject(pickup.object)
		if pickup.type == 'item_weapon' then
			RemoveWeaponAsset(pickup.name)
		else
			SetModelAsNoLongerNeeded(Config.DefaultPickupModel)
		end
		pickup.deleteNow = true
	end
end)

RegisterNetEvent('esx:deleteVehicle')
AddEventHandler('esx:deleteVehicle', function(radius)
	local playerPed = PlayerPedId()

	if radius and tonumber(radius) then
		radius = tonumber(radius) + 0.01
		local vehicles = ESX.Game.GetVehiclesInArea(GetEntityCoords(playerPed), radius)

		for k,entity in ipairs(vehicles) do
			local attempt = 0

			while not NetworkHasControlOfEntity(entity) and attempt < 100 and DoesEntityExist(entity) do
				Wait(100)
				NetworkRequestControlOfEntity(entity)
				attempt = attempt + 1
			end

			if DoesEntityExist(entity) and NetworkHasControlOfEntity(entity) then
				ESX.Game.DeleteVehicle(entity)
			end
		end
	else
		local vehicle, attempt = ESX.Game.GetVehicleInDirection(), 0

		if IsPedInAnyVehicle(playerPed, true) then
			vehicle = GetVehiclePedIsIn(playerPed, false)
		end

		while not NetworkHasControlOfEntity(vehicle) and attempt < 100 and DoesEntityExist(vehicle) do
			Wait(100)
			NetworkRequestControlOfEntity(vehicle)
			attempt = attempt + 1
		end

		if DoesEntityExist(vehicle) and NetworkHasControlOfEntity(vehicle) then
			ESX.Game.DeleteVehicle(vehicle)
		end
	end
end)

-- Pause menu disables HUD display
if Config.EnableHud then
	CreateThread(function()
		while true do
			Wait(300)

			if IsPauseMenuActive() and not isPaused then
				isPaused = true
				ESX.UI.HUD.SetDisplay(0.0)
			elseif not IsPauseMenuActive() and isPaused then
				isPaused = false
				ESX.UI.HUD.SetDisplay(1.0)
			end
		end
	end)
end

local nWeapons = {
	[GetHashKey("WEAPON_STUNGUN")] = 0.01,
	[GetHashKey("WEAPON_FLAREGUN")] = 0.01,
	[GetHashKey("WEAPON_SNSPISTOL")] = 0.02,
	[GetHashKey("WEAPON_SNSPISTOL_MK2")] = 0.025,
	[GetHashKey("WEAPON_PISTOL")] = 0.025,
	[GetHashKey("WEAPON_PISTOL_MK2")] =  0.03,
	[GetHashKey("WEAPON_APPISTOL")] = 0.05,
	[GetHashKey("WEAPON_COMBATPISTOL")] = 0.03,
	[GetHashKey("WEAPON_PISTOL50")] = 0.05,
	[GetHashKey("WEAPON_HEAVYPISTOL")] = 0.03,
	[GetHashKey("WEAPON_VINTAGEPISTOL")] = 0.025,
	[GetHashKey("WEAPON_MARKSMANPISTOL")] = 0.03,
	[GetHashKey("WEAPON_REVOLVER")] = 0.045,
	[GetHashKey("WEAPON_REVOLVER_MK2")] = 0.055,
	[GetHashKey("WEAPON_DOUBLEACTION")] = 0.025,
	[GetHashKey("WEAPON_MICROSMG")] = 0.035,
	[GetHashKey("WEAPON_COMBATPDW")] = 0.045,
	[GetHashKey("WEAPON_SMG")] = 0.045,
	[GetHashKey("WEAPON_SMG_MK2")] = 0.055,
	[GetHashKey("WEAPON_ASSAULTSMG")] = 0.050,
	[GetHashKey("WEAPON_MACHINEPISTOL")] = 0.035,
	[GetHashKey("WEAPON_MINISMG")] = 0.035,
	[GetHashKey("WEAPON_MG")] = 0.07,
	[GetHashKey("WEAPON_COMBATMG")] = 0.08,
	[GetHashKey("WEAPON_COMBATMG_MK2")] = 0.085,
	[GetHashKey("WEAPON_ASSAULTRIFLE")] = 0.07,
	[GetHashKey("WEAPON_ASSAULTRIFLE_MK2")] = 0.075,
	[GetHashKey("WEAPON_CARBINERIFLE")] = 0.06,
	[GetHashKey("WEAPON_CARBINERIFLE_MK2")] = 0.065,
	[GetHashKey("WEAPON_ADVANCEDRIFLE")] = 0.06,
	[GetHashKey("WEAPON_GUSENBERG")] = 0.05,
	[GetHashKey("WEAPON_SPECIALCARBINE")] = 0.06,
	[GetHashKey("WEAPON_SPECIALCARBINE_MK2")] = 0.075,
	[GetHashKey("WEAPON_BULLPUPRIFLE")] = 0.05,
	[GetHashKey("WEAPON_BULLPUPRIFLE_MK2")] = 0.065,
	[GetHashKey("WEAPON_COMPACTRIFLE")] = 0.05,
	[GetHashKey("WEAPON_PUMPSHOTGUN")] = 0.07,
	[GetHashKey("WEAPON_PUMPSHOTGUN_MK2")] = 0.085,
	[GetHashKey("WEAPON_SAWNOFFSHOTGUN")] = 0.06,
	[GetHashKey("WEAPON_ASSAULTSHOTGUN")] = 0.12,
	[GetHashKey("WEAPON_BULLPUPSHOTGUN")] = 0.08,
	[GetHashKey("WEAPON_DBSHOTGUN")] = 0.05,
	[GetHashKey("WEAPON_AUTOSHOTGUN")] = 0.08,
	[GetHashKey("WEAPON_MUSKET")] = 0.04,
	[GetHashKey("WEAPON_HEAVYSHOTGUN")] = 0.13,
	[GetHashKey("WEAPON_SNIPERRIFLE")] = 0.2,
	[GetHashKey("WEAPON_HEAVYSNIPER")] = 0.3,
	[GetHashKey("WEAPON_HEAVYSNIPER_MK2")] = 0.35,
	[GetHashKey("WEAPON_MARKSMANRIFLE_MK2")] = 0.1,
	[GetHashKey("WEAPON_GRENADELAUNCHER")] = 0.08,
	[GetHashKey("WEAPON_RPG")] = 0.9,
	[GetHashKey("WEAPON_HOMINGLAUNCHER")] = 0.9,
	[GetHashKey("WEAPON_MINIGUN")] = 0.20,
	[GetHashKey("WEAPON_RAILGUN")] = 1.0,
	[GetHashKey("WEAPON_COMPACTLAUNCHER")] = 0.08,
	[GetHashKey("WEAPON_FIREWORK")] = 0.5
}

local recoils = {
	[453432689] = 0.3, -- PISTOL
	[3219281620] = 0.3, -- PISTOL MK2
	[1593441988] = 0.2, -- COMBAT PISTOL
	[584646201] = 0.1, -- AP PISTOL
	[2578377531] = 0.6, -- PISTOL .50
	[324215364] = 0.2, -- MICRO SMG
	[736523883] = 0.1, -- SMG
	[2024373456] = 0.1, -- SMG MK2
	[4024951519] = 0.1, -- ASSAULT SMG
	[3220176749] = 0.2, -- ASSAULT RIFLE
	[961495388] = 0.2, -- ASSAULT RIFLE MK2
	[2210333304] = 0.1, -- CARBINE RIFLE
	[4208062921] = 0.1, -- CARBINE RIFLE MK2
	[2937143193] = 0.1, -- ADVANCED RIFLE
	[2634544996] = 0.1, -- MG
	[2144741730] = 0.1, -- COMBAT MG
	[3686625920] = 0.1, -- COMBAT MG MK2
	[487013001] = 0.4, -- PUMP SHOTGUN
	[1432025498] = 0.4, -- PUMP SHOTGUN MK2
	[2017895192] = 0.7, -- SAWNOFF SHOTGUN
	[3800352039] = 0.4, -- ASSAULT SHOTGUN
	[2640438543] = 0.2, -- BULLPUP SHOTGUN
	[911657153] = 0.1, -- STUN GUN
	[100416529] = 0.5, -- SNIPER RIFLE
	[205991906] = 0.7, -- HEAVY SNIPER
	[177293209] = 0.7, -- HEAVY SNIPER MK2
	[856002082] = 1.2, -- REMOTE SNIPER
	[2726580491] = 1.0, -- GRENADE LAUNCHER
	[1305664598] = 1.0, -- GRENADE LAUNCHER SMOKE
	[2982836145] = 0.0, -- RPG
	[1752584910] = 0.0, -- STINGER
	[1119849093] = 0.01, -- MINIGUN
	[3218215474] = 0.2, -- SNS PISTOL
	[2009644972] = 0.25, -- SNS PISTOL MK2
	[1627465347] = 0.1, -- GUSENBERG
	[3231910285] = 0.2, -- SPECIAL CARBINE
	[-1768145561] = 0.25, -- SPECIAL CARBINE MK2
	[3523564046] = 0.5, -- HEAVY PISTOL
	[2132975508] = 0.2, -- BULLPUP RIFLE
	[-2066285827] = 0.25, -- BULLPUP RIFLE MK2
	[137902532] = 0.4, -- VINTAGE PISTOL
	[-1746263880] = 0.4, -- DOUBLE ACTION REVOLVER
	[2828843422] = 0.7, -- MUSKET
	[984333226] = 0.2, -- HEAVY SHOTGUN
	[3342088282] = 0.3, -- MARKSMAN RIFLE
	[1785463520] = 0.35, -- MARKSMAN RIFLE MK2
	[1672152130] = 0, -- HOMING LAUNCHER
	[1198879012] = 0.9, -- FLARE GUN
	[171789620] = 0.2, -- COMBAT PDW
	[3696079510] = 0.9, -- MARKSMAN PISTOL
  	[1834241177] = 2.4, -- RAILGUN
	[3675956304] = 0.3, -- MACHINE PISTOL
	[3249783761] = 0.6, -- REVOLVER
	[-879347409] = 0.65, -- REVOLVER MK2
	[4019527611] = 0.7, -- DOUBLE BARREL SHOTGUN
	[1649403952] = 0.3, -- COMPACT RIFLE
	[317205821] = 0.2, -- AUTO SHOTGUN
	[125959754] = 0.5, -- COMPACT LAUNCHER
	[3173288789] = 0.1, -- MINI SMG		
}

local weapon_suppressor = {
	[GetHashKey('WEAPON_PISTOL')] = GetHashKey('COMPONENT_AT_PI_SUPP_02'),
	[GetHashKey('WEAPON_COMBATPISTOL')] = GetHashKey('COMPONENT_AT_PI_SUPP'),
	[GetHashKey('WEAPON_APPISTOL')] = GetHashKey('COMPONENT_AT_PI_SUPP'),
	[GetHashKey('WEAPON_PISTOL50')] = GetHashKey('COMPONENT_AT_AR_SUPP_02'),
	[GetHashKey('WEAPON_HEAVYPISTOL')] = GetHashKey('COMPONENT_AT_PI_SUPP'),
	[GetHashKey('WEAPON_VINTAGEPISTOL')] = GetHashKey('COMPONENT_AT_PI_SUPP'),
	[GetHashKey('WEAPON_MACHINEPISTOL')] = GetHashKey('COMPONENT_AT_PI_SUPP'),
	[GetHashKey('WEAPON_SMG')] = GetHashKey('COMPONENT_AT_PI_SUPP'),
	[GetHashKey('WEAPON_ASSAULTSMG')] = GetHashKey('COMPONENT_AT_AR_SUPP_02'),
	[GetHashKey('WEAPON_MICROSMG')] = GetHashKey('COMPONENT_AT_AR_SUPP_02'),
	[GetHashKey('WEAPON_PUMPSHOTGUN')] = GetHashKey('COMPONENT_AT_SR_SUPP'),
	[GetHashKey('WEAPON_ASSAULTSHOTGUN')] = GetHashKey('COMPONENT_AT_AR_SUPP'),
	[GetHashKey('WEAPON_BULLPUPSHOTGUN')] = GetHashKey('COMPONENT_AT_AR_SUPP_02'),
	[GetHashKey('WEAPON_HEAVYSHOTGUN')] = GetHashKey('COMPONENT_AT_AR_SUPP_02'),
	[GetHashKey('WEAPON_ASSAULTRIFLE')] = GetHashKey('COMPONENT_AT_AR_SUPP_02'),
	[GetHashKey('WEAPON_CARBINERIFLE')] = GetHashKey('COMPONENT_AT_AR_SUPP'),
	[GetHashKey('WEAPON_ADVANCEDRIFLE')] = GetHashKey('COMPONENT_AT_AR_SUPP'),
	[GetHashKey('WEAPON_SPECIALCARBINE')] = GetHashKey('COMPONENT_AT_AR_SUPP_02'),
	[GetHashKey('WEAPON_BULLPUPRIFLE')] = GetHashKey('COMPONENT_AT_AR_SUPP_02'),
	[GetHashKey('WEAPON_SNIPERRIFLE')] = GetHashKey('COMPONENT_AT_AR_SUPP_02'),
	[GetHashKey('WEAPON_MARKSMANRIFLE')] = GetHashKey('COMPONENT_AT_AR_SUPP_02'),
}

local weapon_grips = {
	[GetHashKey('WEAPON_COMBATPDW')] = GetHashKey('COMPONENT_AT_AR_AFGRIP'),
	[GetHashKey('WEAPON_ASSAULTSHOTGUN')] = GetHashKey('COMPONENT_AT_AR_AFGRIP'),
	[GetHashKey('WEAPON_BULLPUPSHOTGUN')] = GetHashKey('COMPONENT_AT_AR_AFGRIP'),
	[GetHashKey('WEAPON_HEAVYSHOTGUN')] = GetHashKey('COMPONENT_AT_AR_AFGRIP'),
	[GetHashKey('WEAPON_ASSAULTRIFLE')] = GetHashKey('COMPONENT_AT_AR_AFGRIP'),
	[GetHashKey('WEAPON_CARBINERIFLE')] = GetHashKey('COMPONENT_AT_AR_AFGRIP'),
	[GetHashKey('WEAPON_SPECIALCARBINE')] = GetHashKey('COMPONENT_AT_AR_AFGRIP'),
	[GetHashKey('WEAPON_BULLPUPRIFLE')] = GetHashKey('COMPONENT_AT_AR_AFGRIP'),
	[GetHashKey('WEAPON_COMBATMG')] = GetHashKey('COMPONENT_AT_AR_AFGRIP'),
	[GetHashKey('WEAPON_MARKSMANRIFLE')] = GetHashKey('COMPONENT_AT_AR_AFGRIP'),
	[GetHashKey('WEAPON_PUMPSHOTGUN_MK2')] = GetHashKey('COMPONENT_AT_AR_AFGRIP_02'),
	[GetHashKey('WEAPON_ASSAULTRIFLE_MK2')] = GetHashKey('COMPONENT_AT_AR_AFGRIP_02'),
	[GetHashKey('WEAPON_CARBINERIFLE_MK2')] = GetHashKey('COMPONENT_AT_AR_AFGRIP_02'),
	[GetHashKey('WEAPON_CARBINERIFLE_MK2')] = GetHashKey('COMPONENT_AT_AR_AFGRIP_02'),
	[GetHashKey('WEAPON_SPECIALCARBINE_MK2')] = GetHashKey('COMPONENT_AT_AR_AFGRIP_02'),
	[GetHashKey('WEAPON_BULLPUPRIFLE_MK2')] = GetHashKey('COMPONENT_AT_AR_AFGRIP_02'),
	[GetHashKey('WEAPON_COMBATMG_MK2')] = GetHashKey('COMPONENT_AT_AR_AFGRIP_02'),
	[GetHashKey('WEAPON_HEAVYSNIPER_MK2')] = GetHashKey('COMPONENT_AT_AR_AFGRIP_02'),
	[GetHashKey('WEAPON_MARKSMANRIFLE_MK2')] = GetHashKey('COMPONENT_AT_AR_AFGRIP_02'),
}

-- Keep track of ammo usage
CreateThread(function()
	while true do
		Wait(0)

		if isDead then
			Wait(500)
		else
			local playerPed = PlayerPedId()
			local ped = GetPlayerPed(-1)
			DisableControlAction(1, 44, true)
						
			if IsPedShooting(playerPed) then
				local _, weaponHash = GetCurrentPedWeapon(playerPed, true)
				local weapon = ESX.GetWeaponFromHash(weaponHash)

				if weapon then
					local ammoCount = GetAmmoInPedWeapon(playerPed, weaponHash)
					TriggerServerEvent('esx:updateWeaponAmmo', weapon.name, ammoCount)
				end
				
				
				if weaponHash ~= -1569615261 then
					 if (weapon_suppressor[weaponHash] and HasPedGotWeaponComponent(ped, weaponHash, weapon_suppressor[weaponHash])) or (weapon_grips[weaponHash] and HasPedGotWeaponComponent(ped, weaponHash, weapon_grips[weaponHash])) then
						ReduceRecoil = true
					else
						ReduceRecoil = false
					end
					
					if nWeapons[weaponHash] then	
						if ReduceRecoil then
							ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', (nWeapons[weaponHash]/3)*2)
						else
							ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', nWeapons[weaponHash])
						end
					end

					if recoils[weaponHash] and recoils[weaponHash] ~= 0 then
						local hold = ReduceRecoil and ((recoils[weaponHash]*2)/3) or recoils[weaponHash]
						if not (tv >= hold) then
							p = GetGameplayCamRelativePitch()
							if GetFollowPedCamViewMode() ~= 4 then
								SetGameplayCamRelativePitch(p + 0.1, 0.2)
							end
							tv = tv + 0.1
						end
					end
				end
			else
				tv = 0
			end
		end
	end
end)

-- CreateThread(function()
-- 	while true do
-- 		Wait(0)

-- 		if IsControlJustReleased(0, 289) then
-- 			if IsInputDisabled(0) and not isDead and not ESX.UI.Menu.IsOpen('default', 'es_extended', 'inventory') then
-- 				ESX.ShowInventory()
-- 			end
-- 		end
-- 	end
-- end)

-- Disable wanted level
if Config.DisableWantedLevel then
	-- Previous they were creating a contstantly running loop to check if the wanted level
	-- changed and then setting back to 0. This is all thats needed to disable a wanted level.
	SetMaxWantedLevel(0)
end

-- Pickups
CreateThread(function()
	while true do
		Wait(0)
		local playerPed = PlayerPedId()
		local playerCoords, letSleep = GetEntityCoords(playerPed), true
		-- For whatever reason there was a constant check to get the closest player here when it
		-- wasn't even being used
		
		-- Major refactor here, this culls the pickups if not within range.

		for pickupId, pickup in pairs(pickups) do
			local distance = #(playerCoords - pickup.coords)
			if pickup.deleteNow then
				pickup = nil
			else
				if distance < 50 then
					if not DoesEntityExist(pickup.object) then
						letSleep = false
						if pickup.type == 'item_weapon' then
							ESX.Streaming.RequestWeaponAsset(pickup.name)
							pickup.object = CreateWeaponObject(pickup.name, 50, pickup.coords, true, 1.0, 0)
							SetWeaponObjectTintIndex(pickup.object, pickup.tint)

							for _, comp in ipairs(pickup.components) do
								local component = ESX.GetWeaponComponent(pickup.name, comp)
								GiveWeaponComponentToWeaponObject(pickup.object, component.hash)
							end
							
							SetEntityAsMissionEntity(pickup.object, true, false)
							PlaceObjectOnGroundProperly(pickup.object)
							SetEntityRotation(pickup.object, 90.0, 0.0, 0.0)
							local model = GetEntityModel(pickup.object)
							local heightAbove = GetEntityHeightAboveGround(pickup.object)
							local currentCoords = GetEntityCoords(pickup.object)
							local modelDimensionMin, modelDimensionMax = GetModelDimensions(model)
							local size = (modelDimensionMax.y - modelDimensionMin.y) / 2
							SetEntityCoords(pickup.object, currentCoords.x, currentCoords.y, (currentCoords.z - heightAbove) + size)
						else
							ESX.Game.SpawnLocalObject(Config.DefaultPickupModel, pickup.coords, function(obj)
								pickup.object = obj
							end)

							while not pickup.object do
								Wait(10)
							end
							
							SetEntityAsMissionEntity(pickup.object, true, false)
							PlaceObjectOnGroundProperly(pickup.object)
						end

						FreezeEntityPosition(pickup.object, true)
						SetEntityCollision(pickup.object, false, true)
					end
				else
					if DoesEntityExist(pickup.object) then
						DeleteObject(pickup.object)
						if pickup.type == 'item_weapon' then
							RemoveWeaponAsset(pickup.name)
						else
							SetModelAsNoLongerNeeded(Config.DefaultPickupModel)
						end
					end
				end
				
				if distance < 5 then
					local label = pickup.label
					letSleep = false

					if distance < 1 then
						if IsControlJustReleased(0, 38) then
							-- Removed the closestDistance check here, not needed
							if IsPedOnFoot(playerPed) and not pickup.textRange then
								pickup.textRange = true

								local dict, anim = 'weapons@first_person@aim_rng@generic@projectile@sticky_bomb@', 'plant_floor'
								-- Lets use our new function instead of manually doing it
								ExM.Game.PlayAnim(dict, anim, true, 1000)
								Wait(1000)

								TriggerServerEvent('esx:onPickup', pickupId)
								PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
							end
						end

						label = ('%s~n~%s'):format(label, _U('standard_pickup_prompt'))
					end
					
					local pickupCoords = GetEntityCoords(pickup.object)
					ESX.Game.Utils.DrawText3D(vec(pickupCoords.x, pickupCoords.y, pickupCoords.z + 0.5), label, 1.2, 4)
				elseif pickup.textRange then
					pickup.textRange = false
				end
			end
		end

		if letSleep then
			Wait(500)
		end
	end
end)

-- Update current player coords
CreateThread(function()
	-- wait for player to restore coords
	while not isLoadoutLoaded do
		Wait(1000)
	end
	
	local previousCoords = vector3(ESX.PlayerData.coords.x, ESX.PlayerData.coords.y, ESX.PlayerData.coords.z)
	local playerHeading = ESX.PlayerData.heading
	local formattedCoords = {x = ESX.Math.Round(previousCoords.x, 1), y = ESX.Math.Round(previousCoords.y, 1), z = ESX.Math.Round(previousCoords.z, 1), heading = playerHeading}

	while true do
		-- update the players position every second instead of a configed amount otherwise
		-- serverside won't catch up
		Wait(1000)
		
		local playerPed = PlayerPedId()
		local playerCoords = GetEntityCoords(playerPed)
		local distance = #(playerCoords - previousCoords)

		if distance > 10 then
			previousCoords = playerCoords
			playerHeading = ESX.Math.Round(GetEntityHeading(playerPed), 1)
			formattedCoords = {x = ESX.Math.Round(playerCoords.x, 1), y = ESX.Math.Round(playerCoords.y, 1), z = ESX.Math.Round(playerCoords.z, 1), heading = playerHeading}
			TriggerServerEvent('esx:updateCoords', formattedCoords)
			if distance > 1 then
				TriggerServerEvent('esx:updateCoords', formattedCoords)
			end
		end
		
		for i=1, #Config.Weapons, 1 do

			local weaponName = Config.Weapons[i].name
			local weaponHash = GetHashKey(weaponName)
			local weaponComponents = {}

			if HasPedGotWeapon(playerPed, weaponHash, false) and weaponName ~= 'WEAPON_UNARMED' then
				local ammo = GetAmmoInPedWeapon(playerPed, weaponHash)
				TriggerServerEvent('esx:updateWeaponAmmo', weaponName, ammo)
			end
		end
	end
end)
