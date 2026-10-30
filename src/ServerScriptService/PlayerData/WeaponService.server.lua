local ChangeWeapon = game.ReplicatedStorage.RemoteEvents.PlayerData.ChangeWeapon
local ProfileManager = require(game.ServerScriptService.PlayerData.Manager)
local bindable = game.ReplicatedStorage.Bindables.CombatData
local remote = game.ReplicatedStorage.RemoteEvents.Combat.RequestHBConfig
local WeaponConfig = require(game.ServerScriptService.Config.WeaponConfig)
local AdminConfig = require(game.ServerScriptService.Config.AdminConfig)

local function ownsWeapon(data, weaponName, weaponClass)
	local owned = data.WeaponSkins[weaponClass]
	return owned ~= nil and owned[weaponName] == true
end

ChangeWeapon.OnServerEvent:Connect(function(player, weaponName)
	local data = ProfileManager.GetData(player)
	if not data or typeof(weaponName) ~= "string" then return end

	local config = WeaponConfig.Preset(weaponName)
	if not config then
		warn("[WeaponService] Unknown weapon:", weaponName)
		return
	end
	if not AdminConfig.GetFlag("AnyWeapon") and not ownsWeapon(data, weaponName, config.WeaponClass) then
		warn("[WeaponService]", player.Name, "does not own", weaponName)
		return
	end

	data.EquippedWeapon = weaponName
	data.WeaponClass = config.WeaponClass
	print("Equipped weapon:", weaponName, config)

	remote:FireClient(player, config)
	bindable:Fire(player, config)
	ChangeWeapon:FireClient(player, config)
end)