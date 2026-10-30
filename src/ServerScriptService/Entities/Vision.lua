-- An entity's sight: a box region in front of it (Range deep, Width wide, Height tall) plus a
-- line-of-sight raycast, so players behind it or behind walls aren't seen.
--
--   local vision = Vision.new(entity, { Range = 60, Width = 40, Height = 20 })
--   vision:FindTarget()        -- nearest visible player character, or nil
--   vision:HasLineOfSight(char)

local Players = game:GetService("Players")

local Targeting = require(game.ServerScriptService.Combat.SkillClasses.Targeting)

local Vision = {}
Vision.__index = Vision

function Vision.new(entity, config)
	local self = setmetatable({}, Vision)
	self.Entity = entity
	self.Range = config.Range or 60
	self.Width = config.Width or 40
	self.Height = config.Height or 20

	self._overlap = OverlapParams.new()
	self._overlap.FilterType = Enum.RaycastFilterType.Include

	if config.Debug then
		self:_showRegion()
	end
	return self
end

-- Player characters that can be targeted: in workspace.Alive, alive, not already killed
function Vision.GetTargetablePlayers()
	local characters = {}
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if Vision.IsTargetable(char) then
			table.insert(characters, char)
		end
	end
	return characters
end

function Vision.IsTargetable(char)
	if not char or char.Parent ~= workspace.Alive or char:HasTag("Killed") then return false end
	if not Players:GetPlayerFromCharacter(char) then return false end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	-- DamageManager leaves killed players at 0.1 HP (a float, read back as 0.1000000015)
	return humanoid ~= nil and humanoid.Health > 0.15 and char:FindFirstChild("HumanoidRootPart") ~= nil
end

-- The vision box: centred Range/2 ahead of the entity
function Vision:GetRegion()
	local root = self.Entity.Root
	return root.CFrame * CFrame.new(0, 0, -self.Range / 2), Vector3.new(self.Width, self.Height, self.Range)
end

function Vision:HasLineOfSight(char)
	local root = self.Entity.Root
	local targetRoot = char:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return false end
	local eye = root.Position + Vector3.new(0, 1.5, 0)
	return workspace:Raycast(eye, targetRoot.Position - eye, Targeting.MapOnlyParams()) == nil
end

-- The nearest player character inside the vision box with a clear line of sight
function Vision:FindTarget()
	local candidates = Vision.GetTargetablePlayers()
	if #candidates == 0 then return nil end

	local cframe, size = self:GetRegion()
	self._overlap.FilterDescendantsInstances = candidates

	local seen = {}
	local nearest, nearestDistance = nil, math.huge
	for _, part in workspace:GetPartBoundsInBox(cframe, size, self._overlap) do
		local char = Targeting.FindCharacter(part)
		if char and not seen[char] then
			seen[char] = true
			local distance = (char.HumanoidRootPart.Position - self.Entity.Root.Position).Magnitude
			if distance < nearestDistance and self:HasLineOfSight(char) then
				nearest, nearestDistance = char, distance
			end
		end
	end
	return nearest
end

-- Tuning aid: a see-through box welded in front of the entity showing the vision region
function Vision:_showRegion()
	local cframe, size = self:GetRegion()
	local box = Instance.new("Part")
	box.Name = "VisionRegion"
	box.Size = size
	box.CFrame = cframe
	box.Transparency = 0.85
	box.Color = Color3.fromRGB(255, 80, 80)
	box.Material = Enum.Material.ForceField
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Massless = true
	box.Parent = self.Entity.Model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = self.Entity.Root
	weld.Part1 = box
	weld.Parent = box
end

return Vision
