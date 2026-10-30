-- Skill names per weapon class and slot (used by PlayerData.Manager).
-- `Configs` is a reference copy of the original skill configurations; nothing reads it at runtime.
-- Live tuning is the `Config` table inside each ServerStorage.MovesetLogic module.
local SkillConfig = {}
local HitboxType = require(game.ReplicatedStorage.Combat.HitboxClass.Types)

export type Config = {
	CD : number,
	Sections : {any},
	Duration : number,
	Selfstate : {[string] : number}?,
	HyperArmor : boolean?
}

SkillConfig.Skills = {
	["Sword"] = {
		[1] = "Rapid Pierce",
		[2] = "Cross Slash",
		[3] = "Lightspeed Strike",
		[4] = "War Cry"
	},
	["Dagger"] = {
		[1] = "Dagger Throw",
		[2] = "Shade Step",
		[3] = "Lethality"
	},
	["GreatSword"] = {
		[1] = "Rising Blade",
		[2] = "Lion's Claw",
		[3] = "Berserk"
	},
	["Spear"] = {
		[1] = "Piercing Strike",
		[2] = "Whirl Wind",
		[3] = "Serpent Storm"
	}
}

SkillConfig.Configs = {
	["Rapid Pierce"] = {
		CD = 15,
		Sections = {
			[1] = {
				Damage = 1,
				Size = Vector3.new(5,5,10),
				Offset = CFrame.new(0,0,-5),
				DT = 0.1,
				Lifetime = 1.0,
				Delay = 0.4,
				BlockBreak = false,
				States = {
					["Slow"] = 0.3,
					["Stun"] = 0.3
				},
				HitRagdoll = false
			},
			[2] = {
				Damage = 8,
				Size = Vector3.new(12,5,12),
				Offset = CFrame.new(0,0,-5),
				Lifetime = 0.2,
				Delay = 1.7,
				BlockBreak = true,
				States = {
					["HitStun"] = 1,
					["Ragdoll"] = 1.5,
				},
				Knockback = 50,
				HitRagdoll = false,
				Finisher = true
			}
		},
		Duration = 2,
		SelfState = {
			["Slow"] = 1.75
		},
		HyperArmor = false
	} :: Config,
	["Cross Slash"] = {
		CD = 12,
		Sections = {
			[1] = {
				Damage = 6,
				Size = Vector3.new(10,8,10),
				Offset = CFrame.new(0,0,-3),
				Lifetime = 0.1,
				Delay = 0.45,
				BlockBreak = false,
				States = {
					["Slow"] = 0.5,
					["HitStun"] = 0.5
				},
				HitRagdoll = false
			},
			[2] = {
				Damage = 6,
				Size = Vector3.new(10,8,10),
				Offset = CFrame.new(0,0,-3),
				Lifetime = 0.1,
				Delay = 0.75,
				BlockBreak = false,
				States = {
					["Slow"] = 0.5,
					["HitStun"] = 0.5
				},
				HitRagdoll = false
			},
			[3] = {
				Damage = 6,
				Size = Vector3.new(10,8,6),
				Offset = CFrame.new(0,0,-8),
				Lifetime = 0.1,
				Delay = 1.2,
				BlockBreak = true,
				States = {
					["HitStun"] = 1,
					["Ragdoll"] = 1.5,
				},
				Knockback = 25,
				Crittable = true,
				HitRagdoll = true,
				Finisher = false
			}
		},
		Duration = 2,
		SelfState = {
			["Fixed"] = 1.3
		},
		HyperArmor = false
	},
	["Lightspeed Strike"] = {
		CD = 14,
		Sections = {
			[1] = {
				Damage = 16,
				Size = Vector3.new(10,10,42),
				Offset = CFrame.new(0,0,18),
				Lifetime = 0.1,
				Delay = 0.76,
				BlockBreak = false,
				States = {
					["HitStun"] = 1.75,
				},
				Weld = false,
				HitRagdoll = false,
				Finisher = true
			}
		},
		Duration = 1.6,
		SelfState = {
			["Fixed"] = 1.5
		},
		HyperArmor = true
	},
	["War Cry"] = {
		CD = 20,
		Sections = {
			[1] = {
				Damage = 2,
				Size = Vector3.new(60,20,60),
				Offset = CFrame.new(0,0,0),
				DT = 0.125,
				Lifetime = 0.5,
				Delay = 0.5,
				BlockBreak = false,
				States = {
					["Slow"] = 1,
					["Fear"] = 8
				}
			}
		},
		Duration = 1.2,
		HyperArmor = false
	},
	["Dagger Throw"] = {
		CD = 10,
		Sections = {
			[1] = {
				Damage = 5,
				Size = 1.25,
				Offset = CFrame.new(0,0,0),
				Lifetime = 2,
				Delay = 0.50,
				BlockBreak = false,
				States = {
					["HitStun"] = 0.5
				},
				Projectile = true,
				ProjectileSpeed = 100
			},
			[2] = {
				Damage = 5,
				Size = 1.25,
				Offset = CFrame.new(0,0,0),
				Lifetime = 2,
				Delay = 0.75,
				BlockBreak = false,
				States = {
					["HitStun"] = 0.5
				},
				Projectile = true,
				ProjectileSpeed = 100
			},
			[3] = {
				Damage = 5,
				Size = 1.25,
				Offset = CFrame.new(0,0,0),
				Lifetime = 2,
				Delay = 1,
				BlockBreak = false,
				States = {
					["HitStun"] = 1
				},
				Projectile = true,
				ProjectileSpeed = 100
			}
		},
		Duration = 2,
		SelfState = {
			["Slow"] = 1.5
		}
	},
	["Shade Step"] = {
		CD = 14,
		Sections = false,
		Duration = 1
	}
}

function SkillConfig.GetConfig(skillName)
	if not SkillConfig.Configs[skillName] then warn("No config for: ", skillName) return end
	return SkillConfig.Configs[skillName]
end

return SkillConfig
