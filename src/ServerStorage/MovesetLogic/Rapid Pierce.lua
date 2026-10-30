local Skill = require(game.ServerScriptService.Combat.SkillClasses.Skill)

-- A flurry of pierces, then a block-breaking finisher. A hit with the finisher opens the
-- Lightspeed Strike follow-up (state LightspeedStrike_Variant2) for 0.75s.
local RapidPierce = Skill.extend(script.Name, {
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
			Damage = 4,
			Size = Vector3.new(12,5,12),
			Offset = CFrame.new(0,0,-5),
			Lifetime = 0.2,
			Delay = 1.7,
			BlockBreak = true,
			States = {
				["HitStun"] = 1,
				["Ragdoll"] = 1.5,
			},
			Knockback = 30,
			HitRagdoll = false,
			Finisher = true,
			SelfStateOnHit = {
				["LightspeedStrike_Variant2"] = 0.75
			}
		}
	},
	Duration = 2,
	SelfState = {
		["Slow"] = 1.75
	},
	HyperArmor = false
})

function RapidPierce:Run()
	self:Begin("Release")
	self:RunSections()
end

return RapidPierce
