-- "Shadow Marked" status: applied by Dagger Throw hits, consumed by Shade Step (teleport behind the target).
-- Each caster has at most one active mark (a new one replaces the old). The target gets the
-- state/attribute "ShadowMarked" (clients show it as a dark highlight) for the mark's duration.
--
--   ShadowMark.new(casterChar, target, duration?)  -- mark (replaces the caster's previous mark)
--   ShadowMark.Get(casterChar)                    -- the caster's active mark, or nil
--   mark.Target, mark:IsActive(), mark:DistanceFrom(char), mark:Consume()

local stateManager = require(game.ServerScriptService.PlayerStates.StateManager)

local ShadowMark = {}
ShadowMark.__index = ShadowMark

ShadowMark.DURATION = 8

local activeMarks = {} -- [casterChar] = ShadowMark

local function isValidTarget(target)
	if not target or target.Parent ~= workspace.Alive then return false end
	if target:HasTag("Killed") then return false end
	local hum = target:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and target:FindFirstChild("HumanoidRootPart") ~= nil
end

function ShadowMark.new(casterChar, target, duration)
	duration = duration or ShadowMark.DURATION
	local self = setmetatable({
		Caster = casterChar,
		Target = target,
		Expires = os.clock() + duration,
	}, ShadowMark)
	activeMarks[casterChar] = self
	stateManager:AddState(target, "ShadowMarked", duration)
	return self
end

-- The caster's mark if it hasn't expired, been replaced or consumed, and the target is still alive
function ShadowMark.Get(casterChar)
	local mark = activeMarks[casterChar]
	if mark and not mark:IsActive() then
		activeMarks[casterChar] = nil
		return nil
	end
	return mark
end

function ShadowMark:IsActive()
	return activeMarks[self.Caster] == self and os.clock() <= self.Expires and isValidTarget(self.Target)
end

function ShadowMark:DistanceFrom(char)
	return (self.Target.HumanoidRootPart.Position - char.HumanoidRootPart.Position).Magnitude
end

-- Removes the mark and the target's ShadowMarked state
function ShadowMark:Consume()
	if activeMarks[self.Caster] == self then
		activeMarks[self.Caster] = nil
	end
	stateManager:RemoveState(self.Target, "ShadowMarked")
end

-- Forget casters whose character is gone
workspace.Alive.ChildRemoved:Connect(function(child)
	activeMarks[child] = nil
end)

return ShadowMark
