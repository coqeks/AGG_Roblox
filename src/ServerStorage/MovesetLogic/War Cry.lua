local Skill = require(game.ServerScriptService.Combat.SkillClasses.Skill)

-- Awakening skill: a wide shout that slows and Fears everyone nearby
local WarCry = Skill.extend(script.Name, {
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
})

function WarCry:Run()
	self:Begin(1)
	self:RunSections()
end

return WarCry
