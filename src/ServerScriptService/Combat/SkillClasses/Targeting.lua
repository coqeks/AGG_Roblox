-- Shared lookups for skill code: which workspace.Alive character a part belongs to, who can be hit,
-- and which raycasts only see map geometry.

local aliveFolder = workspace:WaitForChild("Alive")
local projectileFolder = workspace:WaitForChild("Projectiles")

local Targeting = {}

-- The workspace.Alive character that `part` belongs to, if any
function Targeting.FindCharacter(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model and model.Parent ~= aliveFolder do
		model = model:FindFirstAncestorOfClass("Model")
	end
	if model and model:FindFirstChildOfClass("Humanoid") then
		return model
	end
end

-- True for a character Model in workspace.Alive (e.g. a client-sent lock-on target)
function Targeting.IsAliveCharacter(target)
	return typeof(target) == "Instance" and target:IsA("Model") and target.Parent == aliveFolder
		and target:FindFirstChild("HumanoidRootPart") ~= nil
end

-- Every workspace.Alive character except `exclude` (for Include-filtered queries)
function Targeting.OthersInAlive(exclude)
	local targets = {}
	for _, model in aliveFolder:GetChildren() do
		if model ~= exclude then
			table.insert(targets, model)
		end
	end
	return targets
end

-- Each character (other than `exclude`) with a part within `radius` of `position`, listed once
function Targeting.CharactersInRadius(position, radius, exclude)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = Targeting.OthersInAlive(exclude)

	local found, seen = {}, {}
	for _, part in workspace:GetPartBoundsInRadius(position, radius, params) do
		local character = Targeting.FindCharacter(part)
		if character and not seen[character] then
			seen[character] = true
			table.insert(found, character)
		end
	end
	return found
end

-- Raycast params that only hit map geometry (ignores characters, projectiles and debris)
function Targeting.MapOnlyParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { aliveFolder, projectileFolder }
	if workspace:FindFirstChild("Debris") then
		table.insert(ignore, workspace.Debris)
	end
	params.FilterDescendantsInstances = ignore
	return params
end

return Targeting
