local WeaponConfig = {}

WeaponConfig.__index = WeaponConfig
local animPath = game.ReplicatedStorage.Animations.Combat

local Types = {
	["Blunt"] = "Blunt",
	["Slash"] = "Slash",
	["Pierce"] = "Pierce"
}

WeaponConfig.WeaponSkins = {
	["Sword"] = {
		["Iron Gladius"] = "Gladius forged from iron",
		["Linked Sword"] = "With Blood and Iron.",
		["Excalibur"] = "Saber!!!",
		["Katana"] = "Samurai Heart",
		["Soulsplit Katana"] = "Abandon it all",
		["«Elucidator»"] = "Sword of a legendary gamer",
		["Master Sword"] = "Blade of evil's bane"
	},
	["Dagger"] = {
		["Iron Dagger"] = "Dagger forged from iron",
		["ISoH"] = "The fight has just begun."
	},
	["GreatSword"] = {
		["Iron Greatsword"] = "Greatsword forged from iron"
	}
}

local Presets = {
	["Fist"] = {
		Size = Vector3.new(6,7,7),
		Damage = 5,
		WeaponClass = "Fist",
		HitDelay = 0.2,
		EndLag = 0.35,
		Animations = {},
		MaxCombo = 4,
		Type = Types.Blunt
	},
	["Iron Dagger"] = {
		Size = Vector3.new(6,7,7),
		Damage = 5,
		WeaponClass = "Dagger",
		HitDelay = 0.3,
		EndLag = 0.2,
		Animations = {},
		MaxCombo = 4,
		Type = Types.Slash
	},
	["Iron Gladius"] = {
		Size = Vector3.new(6,7,7.5),
		Damage = 6,
		WeaponClass = "Sword",
		HitDelay = 0.4,
		EndLag = 0.2,
		Animations = {},
		MaxCombo = 3,
		Type = Types.Slash
	},
	["Linked Sword"] = {
		Size = Vector3.new(6,7,7.5),
		Damage = 6,
		WeaponClass = "Sword",
		HitDelay = 0.4,
		EndLag = 0.2,
		Animations = {},
		MaxCombo = 3,
		Type = Types.Slash
	},
	["Katana"] = {
		Size = Vector3.new(6,7,7.5),
		Damage = 6,
		WeaponClass = "Sword",
		HitDelay = 0.4,
		EndLag = 0.2,
		Animations = {},
		MaxCombo = 3,
		Type = Types.Slash
	},
	["Master Sword"] = {
		Size = Vector3.new(6,7,7.5),
		Damage = 6,
		WeaponClass = "Sword",
		HitDelay = 0.4,
		EndLag = 0.2,
		Animations = {},
		MaxCombo = 3,
		Type = Types.Slash
	},
	["Excalibur"] = {
		Size = Vector3.new(6,7,8),
		Damage = 6,
		WeaponClass = "Sword",
		HitDelay = 0.4,
		EndLag = 0.2,
		Animations = {},
		MaxCombo = 3,
		Type = Types.Slash
	},
	["«Elucidator»"] = {
		Size = Vector3.new(6,7,7.5),
		Damage = 6,
		WeaponClass = "Sword",
		HitDelay = 0.4,
		EndLag = 0.2,
		Animations = {},
		MaxCombo = 3,
		Type = Types.Slash
	},
	["Soulsplit Katana"] = {
		Size = Vector3.new(6,7,7.5),
		Damage = 7.5,
		WeaponClass = "Sword",
		HitDelay = 0.45,
		EndLag = 0.2,
		Animations = {},
		MaxCombo = 3,
		Type = Types.Slash
	}
}

function WeaponConfig.Preset(PSName)
	if not PSName then
		return
	end
	--print("Searching config" .. PSName)
	local config = Presets[PSName]
	if config then
		return config
	end
	return 
end

function WeaponConfig.FindWeaponClass(PSName)
	local config = Presets[PSName]
	if not config then return end
	return config["WeaponClass"]
end

function WeaponConfig.FindType(PSName)
	local config = Presets[PSName]
	if not config then return end
	return config["Type"]
end

return WeaponConfig
