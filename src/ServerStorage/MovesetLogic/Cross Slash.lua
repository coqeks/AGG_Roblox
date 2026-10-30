local Skill        = require(game.ServerScriptService.Combat.SkillClasses.Skill)
local stateManager = require(game.ServerScriptService.PlayerStates.StateManager)

local skillReplicator = game.ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("SkillReplicator")

-- Two slashes. Pressing the skill key again in the follow-up window after the second slash
-- does a third, block-breaking slash (client variant 2).
local CrossSlash = Skill.extend(script.Name, {
	CD = 12,
	Sections = {
		[1] = {
			Damage = 5,
			Size = Vector3.new(10,8,10),
			Offset = CFrame.new(0,0,-3),
			Lifetime = 0.1,
			Delay = 0.45,
			BlockBreak = false,
			States = {
				["Slow"] = 0.5,
				["HitStun"] = 0.4
			},
			HitRagdoll = false
		},
		[2] = {
			Damage = 5,
			Size = Vector3.new(10,8,10),
			Offset = CFrame.new(0,0,-3),
			Lifetime = 0.1,
			Delay = 0.75,
			BlockBreak = false,
			States = {
				["Slow"] = 0.5,
				["HitStun"] = 0.4
			},
			HitRagdoll = false
		},
		[3] = { -- follow-up slash, starts as soon as it's triggered
			Damage = 6,
			Size = Vector3.new(10,8,6),
			Offset = CFrame.new(0,0,-8),
			Lifetime = 0.1,
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
	Duration = 1.2,
	SelfState = {
		["Fixed"] = 1
	},
	HyperArmor = false,

	FollowUp = {
		SpamGuard = 0.25, -- a press this soon after the second slash voids the follow-up (no mashing)
		Window = 0.25,    -- then a press within this window triggers it
		Duration = 0.5,   -- UsingSkill, Fixed and IFrame time for the follow-up
	}
})

function CrossSlash:Run()
	local sections = self.Config.Sections
	self:Begin(1)
	self:After(sections[1].Delay, function()
		self:SpawnHitbox(sections[1])
	end)
	self:After(sections[2].Delay, function()
		self:SpawnHitbox(sections[2])
		self:OpenFollowUpWindow()
	end)
end

function CrossSlash:OpenFollowUpWindow()
	local followUp = self.Config.FollowUp

	-- Entities have no key to press: they always follow up once the spam guard has passed
	if not self.Player then
		task.wait(followUp.SpamGuard)
		if self:IsActive() then
			self:FollowUpSlash()
		end
		return
	end
	local mashed = false

	local function isSkillPress(calledPlayer, skillNum)
		return calledPlayer == self.Player and skillNum == 2
	end

	local guard = skillReplicator.OnServerEvent:Connect(function(calledPlayer, skillNum)
		if isSkillPress(calledPlayer, skillNum) then
			mashed = true
		end
	end)
	task.wait(followUp.SpamGuard)
	guard:Disconnect()
	if mashed then return end

	local window
	window = skillReplicator.OnServerEvent:Connect(function(calledPlayer, skillNum)
		if isSkillPress(calledPlayer, skillNum) then
			window:Disconnect()
			self:FollowUpSlash()
		end
	end)
	task.delay(followUp.Window, function()
		window:Disconnect()
	end)
end

function CrossSlash:FollowUpSlash()
	local duration = self.Config.FollowUp.Duration
	self:Replicate(2)
	stateManager:AddState(self.Character, "UsingSkill", duration)
	stateManager:AddState(self.Character, "Fixed", duration)
	stateManager:AddState(self.Character, "IFrame", duration)

	if stateManager:CheckStun(self.Character) then return end
	self:SpawnHitbox(self.Config.Sections[3])
end

return CrossSlash
