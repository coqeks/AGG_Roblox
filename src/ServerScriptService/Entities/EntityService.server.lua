-- Spawns PvE entities at every part in workspace.EntitySpawns that has an EntityType attribute
-- (a key of Entities.EntityConfigs) and respawns each one RespawnTime seconds after it dies.
-- Spawn parts added while the game runs are picked up too.

local Entity        = require(game.ServerScriptService.Entities.Entity)
local Brain         = require(game.ServerScriptService.Entities.Brain)
local EntityConfigs = require(game.ServerScriptService.Entities.EntityConfigs)

local spawnFolder = workspace:WaitForChild("EntitySpawns")

local function spawnAt(spawnPart)
	local typeName = spawnPart:GetAttribute("EntityType")
	local config = EntityConfigs[typeName]
	if not config then
		warn("[EntityService] " .. spawnPart:GetFullName() .. ": unknown EntityType " .. tostring(typeName))
		return
	end

	local spawnCFrame = spawnPart.CFrame * CFrame.new(0, spawnPart.Size.Y / 2 + 3, 0)
	local entity = Entity.new(typeName, config, spawnCFrame)
	local brain = Brain.new(entity)
	brain:Start()

	entity.Died:Once(function()
		brain:Stop()
		task.delay(config.CorpseTime or 5, function()
			entity:Destroy()
		end)
		task.delay(config.RespawnTime or 20, function()
			if spawnPart.Parent then
				spawnAt(spawnPart)
			end
		end)
	end)
end

local function onSpawnAdded(spawnPart)
	if spawnPart:IsA("BasePart") and spawnPart:GetAttribute("EntityType") then
		task.spawn(spawnAt, spawnPart)
	end
end

spawnFolder.ChildAdded:Connect(onSpawnAdded)
for _, spawnPart in spawnFolder:GetChildren() do
	onSpawnAdded(spawnPart)
end
