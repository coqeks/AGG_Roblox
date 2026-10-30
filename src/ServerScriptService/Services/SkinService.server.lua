local dataManager = require(game.ServerScriptService.PlayerData.Manager)

local buyEvent = game.ReplicatedStorage.RemoteEvents.PlayerData.BuyWeaponSkin
local notificationEvent = game.ReplicatedStorage.RemoteEvents.GUI.Notification
local getSkinsEvent = game.ReplicatedStorage.RemoteEvents.PlayerData.GetWeaponSkins

local weaponSkins = require(game.ServerScriptService.Config.WeaponConfig).WeaponSkins

local PRICE = 2500

local function getRandomKey(dict)
	-- Get all keys into a list
	local keys = {}
	for k in pairs(dict) do
		table.insert(keys, k)
	end

	-- Pick random key, then get value
	local randomKey = keys[math.random(1, #keys)]
	local randomValue = dict[randomKey]
	return randomKey, randomValue
end


buyEvent.OnServerEvent:Connect(function(player)
	local profile = dataManager.GetData(player)
	if not profile then warn("[SkinRollService] No profile") return end
	
	local rollableSkins = {}
	
	for class, unlocked in profile.UnlockedWeaponClass do
		if unlocked and weaponSkins[class] then
			for key, value in pairs(weaponSkins[class]) do
				rollableSkins[key] = value
			end
		end
	end
	
	rollableSkins["Linked Sword"] = nil --/Not rollable
	
	print(rollableSkins)
	
	if profile.Gold >= PRICE then
		local key = getRandomKey(rollableSkins)
		local skinClass
		for class, list in weaponSkins do
			if list[key] then
				skinClass = class
			end
		end
		
		print(key, skinClass)
		if profile.WeaponSkins[skinClass][key] then
			print("Duplicate, half refunded")
			dataManager.AdjustGold(player, -PRICE/2)
		else
			dataManager.AdjustGold(player, -PRICE)
			profile.WeaponSkins[skinClass][key] = true
			print("New skin unlocked")
		end
		notificationEvent:FireClient(player, "SkinRoll", "- Rolled: " .. key .. " -")
	end
end)

getSkinsEvent.OnServerEvent:Connect(function(player)
	local profile = dataManager.GetData(player)
	if not profile then warn("[SkinRollService] No profile") return end
	
	-- Build response: { Sword = {{skinName, description}, ...}, Dagger = {...} }
	local skins = {}

	for class, unlockedSkinList in pairs(profile.WeaponSkins) do
		skins[class] = {}
		for skinName, unlocked in pairs(unlockedSkinList) do
			if unlocked then
				local skinInfo = weaponSkins[class][skinName]
				if skinInfo then
					table.insert(skins[class], {skinName, skinInfo})
				end
			end
		end
	end

	print("[SkinRollService] Sending skins to", player.Name, skins)
	getSkinsEvent:FireClient(player, skins)
end)