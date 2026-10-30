local Template = {

	PlayerKills = 0,
	Streak = 0,
	Deaths = 0,
	BeastKills = 0,
	CombatExp = 0,
	Level = 1,
	Gold = 10,
	EquippedWeapon = "Iron Gladius",
	WeaponClass = "Sword",
	Stats = {
		STR = 0,
		AGI = 0,
		DEF = 0,
		INT = 0,
		Total = 0,
		Available = 1
	},
	UnlockedSkills = {
		Sword = {
			[1] = false,
			[2] = false,
			[3] = false,
			[4] = false
		},
		Dagger = {
			[3] = false,
			[2] = false,
			[1] = false,
			[4] = false
		},
		Spear = {
			["1"] = true,
			["2"] = false,
			["3"] = false
		}
	},
	UnlockedWeaponClass = {
		Sword = true,
		Dagger = false,
		Spear = false
	},
	WeaponMastery = {
		Sword = 0,
		Dagger = 0,
		Spear = 0
	},
	WeaponSkins = {
		Sword = {
			["Iron Gladius"] = true
		},
		Dagger = {
			["Iron Dagger"] = true
		},
		GreatSword = {
			["Iron Greatsword"] = true
		}
	}
}


export type PlayerData = typeof(Template)

return Template

