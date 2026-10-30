local RunService = game:GetService("RunService")

local Skill        = require(game.ServerScriptService.Combat.SkillClasses.Skill)
local Targeting    = require(game.ServerScriptService.Combat.SkillClasses.Targeting)
local stateManager = require(game.ServerScriptService.PlayerStates.StateManager)
local ShadowMark   = require(game.ServerScriptService.Combat.ShadowMark)

-- With a Shadow Marked target (from Dagger Throw): blink behind that target, consuming the mark.
-- Without one: the original Shade Step on the locked-on target (client-driven shadow storm).
local ShadeStep = Skill.extend(script.Name, {
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
	HyperArmor = false,
	-- Checked in CanUse instead, since a marked target doesn't need a lock-on target
	RequireTarget = false,

	Blink = {
		BehindDistance = 3,  -- studs behind the marked target
		MaxRange = 250,      -- marks further away than this can't be blinked to
		IFrame = 0.3,        -- invulnerable during the blink
		Duration = 0.35,     -- UsingSkill time
	}
})

-- The caster's Shadow Mark if it's close enough to blink to
function ShadeStep:UsableMark(char)
	local mark = ShadowMark.Get(char)
	if mark and mark:DistanceFrom(char) <= self.Config.Blink.MaxRange then
		return mark
	end
end

function ShadeStep:CanUse(caster, target)
	local char = Skill.CharacterOf(caster)
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return false, "No character"
	end
	if self:UsableMark(char) or Targeting.IsAliveCharacter(target) then
		return true
	end
	return false, "Shade Step: no Shadow Marked or locked-on target"
end

function ShadeStep:Run()
	local mark = self:UsableMark(self.Character)
	if mark then
		mark:Consume()
		self:BlinkBehind(mark.Target)
		return
	end

	-- Original Shade Step
	self:Replicate(1, self.Target)
	if not self.Player then
		self:FollowTargetForEntity()
	end
end

-- During the original Shade Step a player's own client keeps them in front of the target for 2s
-- (Movesets["Shade Step"]); entities have no client, so the server does it
function ShadeStep:FollowTargetForEntity()
	local target = self.Target
	if not Targeting.IsAliveCharacter(target) then return end
	local connection = RunService.Heartbeat:Connect(function()
		if target.Parent and self.Character.Parent then
			self.Root.CFrame = target.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3)
		end
	end)
	task.delay(2, function()
		connection:Disconnect()
	end)
end

-- Spot behind the target facing its back, pulled in if a wall is in the way
function ShadeStep:BlinkDestination(targetRoot)
	local behind = targetRoot.CFrame * CFrame.new(0, 0, self.Config.Blink.BehindDistance)
	local offset = behind.Position - targetRoot.Position
	local result = workspace:Raycast(targetRoot.Position, offset, Targeting.MapOnlyParams())
	local position = result and (result.Position - offset.Unit * 1) or behind.Position

	local lookAt = Vector3.new(targetRoot.Position.X, position.Y, targetRoot.Position.Z)
	if (lookAt - position).Magnitude < 0.05 then
		return CFrame.new(position) * targetRoot.CFrame.Rotation
	end
	return CFrame.lookAt(position, lookAt)
end

function ShadeStep:BlinkBehind(target)
	local blink = self.Config.Blink
	local fromCFrame = self.Root.CFrame
	local toCFrame = self:BlinkDestination(target.HumanoidRootPart)

	self:Replicate("Blink", {
		From = fromCFrame,
		To = toCFrame,
		Target = target,
	})
	stateManager:AddState(self.Character, "UsingSkill", blink.Duration)
	stateManager:AddState(self.Character, "IFrame", blink.IFrame)

	self.Root.AssemblyLinearVelocity = Vector3.zero
	self.Character:PivotTo(toCFrame)
end

return ShadeStep
