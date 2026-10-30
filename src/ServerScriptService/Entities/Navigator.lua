-- Walks an entity toward a point: straight there when nothing is in the way, otherwise along a
-- PathfindingService path (recomputed when the goal moves or the path goes stale). Jumps at path
-- jump waypoints and over low obstacles.
--
--   local navigator = Navigator.new(entity)
--   navigator:MoveTowards(position)  -- call every Brain tick
--   navigator:Stop()

local PathfindingService = game:GetService("PathfindingService")

local Targeting = require(game.ServerScriptService.Combat.SkillClasses.Targeting)

local REPATH_TIME = 1      -- seconds between path recomputes while the goal moves
local REPATH_DISTANCE = 6  -- goal moved this far since the last path = recompute
local WAYPOINT_REACHED = 3 -- studs

local Navigator = {}
Navigator.__index = Navigator

function Navigator.new(entity)
	local self = setmetatable({}, Navigator)
	self.Entity = entity
	self.Path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 4,
	})
	self._waypoints = nil
	self._index = 0
	self._goal = nil
	self._computedAt = 0
	return self
end

function Navigator:MoveTowards(goal)
	local entity = self.Entity
	if self:_isDirect(goal) then
		self._waypoints = nil
		entity:MoveTo(goal)
		self:_jumpIfBlocked()
		return
	end

	local now = os.clock()
	local stale = not self._waypoints
		or now - self._computedAt > REPATH_TIME * 3
		or ((goal - self._goal).Magnitude > REPATH_DISTANCE and now - self._computedAt > REPATH_TIME)
	if stale then
		self:_compute(goal)
	end

	local waypoint = self._waypoints and self._waypoints[self._index]
	if not waypoint then
		-- No path (or it's finished): head straight for the goal and hope for the best
		entity:MoveTo(goal)
		self:_jumpIfBlocked()
		return
	end

	local offset = waypoint.Position - entity.Root.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude < WAYPOINT_REACHED then
		self._index += 1
		waypoint = self._waypoints[self._index]
		if not waypoint then return end
	end
	if waypoint.Action == Enum.PathWaypointAction.Jump then
		entity:Jump()
	end
	entity:MoveTo(waypoint.Position)
end

function Navigator:Stop()
	self._waypoints = nil
	self.Entity:StopMoving()
end

-- Clear line from the entity to the goal at waist height, and not much higher or lower
function Navigator:_isDirect(goal)
	local root = self.Entity.Root
	local offset = goal - root.Position
	if math.abs(offset.Y) > 6 then return false end
	return workspace:Raycast(root.Position, offset, Targeting.MapOnlyParams()) == nil
end

function Navigator:_compute(goal)
	self._goal = goal
	self._computedAt = os.clock()
	local ok = pcall(function()
		self.Path:ComputeAsync(self.Entity.Root.Position, goal)
	end)
	if ok and self.Path.Status == Enum.PathStatus.Success then
		self._waypoints = self.Path:GetWaypoints()
		self._index = 2 -- the first waypoint is where the entity already stands
	else
		self._waypoints = nil
	end
end

-- Something knee-high in front but nothing at head height: jump over it
function Navigator:_jumpIfBlocked()
	local root = self.Entity.Root
	local humanoid = self.Entity.Humanoid
	if humanoid.MoveDirection.Magnitude < 0.1 then return end
	local ahead = humanoid.MoveDirection.Unit * 3
	local params = Targeting.MapOnlyParams()
	local knee = workspace:Raycast(root.Position - Vector3.new(0, 1.5, 0), ahead, params)
	local head = workspace:Raycast(root.Position + Vector3.new(0, 1.5, 0), ahead, params)
	if knee and not head then
		self.Entity:Jump()
	end
end

return Navigator
