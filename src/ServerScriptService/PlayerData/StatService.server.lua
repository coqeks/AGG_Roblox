local StatConfig = require(game.ServerScriptService.Config.StatConfig)
local Manager = require(game.ServerScriptService.PlayerData.Manager)
local StateManager = require(game.ServerScriptService.PlayerStates.StateManager)

local updateEvent = game.ReplicatedStorage.RemoteEvents.PlayerData.StatUpdate
local requestEvent = game.ReplicatedStorage.RemoteEvents.PlayerData.RequestStats
local updatePassives = game.ReplicatedStorage.RemoteEvents.GUI.UpdatePassive
local passiveCosmetic = game.ReplicatedStorage.RemoteEvents.Effects.PassiveCosmetic

local Players = game:GetService("Players")

local function setupPassive(char)
	print("Setting up passive")
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end

	local data = Manager.GetData(player)
	if not data then return end

	local passives = StatConfig.ReturnPassives(data.Stats)
	updatePassives:FireClient(player, passives)
	StateManager:ClearPassives(char)
	
	if not passives then warn("No passives") return end
	
	for name, _ in passives do
		StateManager:AddPassive(char, name)
	end
	task.wait(1)
	passiveCosmetic:FireAllClients(char)
end

updateEvent.OnServerEvent:Connect(function(player, statName)

	if statName == "Reset" then
		Manager.ResetStat(player)
		setupPassive(player.Character)
		return
	end
	
	Manager.AdjustStats(player, statName, 1)
	setupPassive(player.Character)
end)

requestEvent.OnServerEvent:Connect(function(player)
	local data = Manager.GetData(player)
	if not data then return end
	
	requestEvent:FireClient(player, data.Stats)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Passives")
		setupPassive(char)
	end)
end)

for _, player in Players:GetPlayers() do
	task.spawn(function()
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Passives")
			setupPassive(char)
		end)
	end)
end
