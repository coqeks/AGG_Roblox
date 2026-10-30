-- A server-simulated, straight-line projectile that hits characters in workspace.Alive.
-- It is an invisible anchored part in workspace.Projectiles, moved every Heartbeat. Hits come from a
-- spherecast along each frame's step, so a server hitch can't make it skip through a target (a
-- per-frame overlap check missed hits whenever the server hitched), plus an overlap check at spawn.
-- It hits the first character on its path, fires Hit(target, projectile) and destroys itself.
--
--   local dagger = Projectile.new({ Owner = char, Origin = cframe, Speed = 100, Radius = 1.25, Lifetime = 2 })
--   dagger.Hit:Connect(function(target) ... end)
--   dagger:Launch()

local RunService = game:GetService("RunService")

local Signal    = require(game.ReplicatedStorage.Combat.HitboxClass.Signal)
local Targeting = require(game.ServerScriptService.Combat.SkillClasses.Targeting)

local projectileFolder = workspace:WaitForChild("Projectiles")

local Projectile = {}
Projectile.__index = Projectile

-- params: Owner (Model, never hit), Origin (CFrame), Direction (unit Vector3, defaults to Origin.LookVector),
-- Speed (studs/s), Radius (studs), Lifetime (seconds), Name (optional part name)
function Projectile.new(params)
	local self = setmetatable({}, Projectile)
	self.Owner = params.Owner
	self.Direction = params.Direction or params.Origin.LookVector
	self.Speed = params.Speed
	self.Radius = params.Radius
	self.Lifetime = params.Lifetime
	self.Hit = Signal.new()
	self.Destroyed = false

	local part = Instance.new("Part")
	part.Name = params.Name or "Projectile"
	part.Size = Vector3.one
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CFrame = params.Origin
	part.Parent = projectileFolder
	self.Part = part

	self._castParams = RaycastParams.new()
	self._castParams.FilterType = Enum.RaycastFilterType.Include

	return self
end

function Projectile:Launch()
	-- Someone already inside the projectile at spawn (spherecasts ignore starting overlaps)
	local inside = Targeting.CharactersInRadius(self.Part.Position, self.Radius, self.Owner)[1]
	if inside then
		self:_impact(inside)
		return self
	end

	self._heartbeat = RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)
	task.delay(self.Lifetime, function()
		self:Destroy()
	end)
	return self
end

function Projectile:_step(dt)
	local step = self.Direction * self.Speed * dt
	self._castParams.FilterDescendantsInstances = Targeting.OthersInAlive(self.Owner)
	local result = workspace:Spherecast(self.Part.Position, self.Radius, step, self._castParams)
	local target = result and Targeting.FindCharacter(result.Instance)
	if target then
		self:_impact(target)
		return
	end
	self.Part.CFrame += step
end

function Projectile:_impact(target)
	if self.Destroyed then return end
	if self._heartbeat then
		self._heartbeat:Disconnect()
	end
	self.Hit:Fire(target, self)
	self:Destroy()
end

function Projectile:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	if self._heartbeat then
		self._heartbeat:Disconnect()
	end
	self.Part:Destroy()
	self.Hit:DisconnectAll()
end

return Projectile
