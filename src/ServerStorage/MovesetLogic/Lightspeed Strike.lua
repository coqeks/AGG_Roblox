local Skill        = require(game.ServerScriptService.Combat.SkillClasses.Skill)
local Targeting    = require(game.ServerScriptService.Combat.SkillClasses.Targeting)
local stateManager = require(game.ServerScriptService.PlayerStates.StateManager)

-- Set by Rapid Pierce's finisher hit (its SelfStateOnHit): casting during it does the follow-up instead
local FOLLOW_UP_STATE = "LightspeedStrike_Variant2"

local LightspeedStrike = Skill.extend(script.Name, {
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
			HitRagdoll = false,
			Finisher = true,
			DashDistance = 40, -- forward teleport at DashAt (by the caster's client, or the server for entities)
			DashAt = 0.75,
		},
		[2] = { -- follow-up after Rapid Pierce
			Damage = 10,
			Size = Vector3.new(8,8,25),
			Offset = CFrame.new(0,0,10),
			Lifetime = 0.1,
			Delay = 0.26,
			BlockBreak = false,
			States = {
				["HitStun"] = 1.5,
			},
			HitRagdoll = true,
			Finisher = true,
			Duration = 0.75, -- UsingSkill and Fixed time
			DashDistance = 20,
			DashAt = 0.25,
		}
	},
	Duration = 1.6,
	SelfState = {
		["Fixed"] = 1.5
	},
	HyperArmor = false
})

function LightspeedStrike:Run()
	local sections = self.Config.Sections
	if stateManager:HasState(self.Character, FOLLOW_UP_STATE) then
		local followUp = sections[2]
		self:Begin(2, nil, followUp.Duration, { Fixed = followUp.Duration })
		self:DashIfEntity(followUp)
		self:RunSections({ followUp })
		return
	end

	self:Begin(1)
	self:DashIfEntity(sections[1])
	self:RunSections({ sections[1] })
end

-- A player's own client moves them forward (Movesets["Lightspeed Strike"], at DashAt); entities have
-- no client, so the server moves them at the same moment
function LightspeedStrike:DashIfEntity(section)
	if self.Player then return end
	self:After(section.DashAt, function()
		local root = self.Root
		local look = root.CFrame.LookVector
		local result = workspace:Raycast(root.Position, look * section.DashDistance, Targeting.MapOnlyParams())
		if result then
			root.CFrame = CFrame.new(result.Position - look * 2) * root.CFrame.Rotation
		else
			root.CFrame *= CFrame.new(0, 0, -section.DashDistance)
		end
	end)
end

-- The follow-up picks the target up out of ragdoll
function LightspeedStrike:OnHit(target, section, landed)
	if landed and section == self.Config.Sections[2] then
		stateManager:RemoveState(target, "Ragdoll")
	end
end

return LightspeedStrike
