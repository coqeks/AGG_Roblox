local damageManager = require(game.ServerScriptService.Combat.DamageManager)
local stateManager = require(game.ServerScriptService.PlayerStates.StateManager)
local dataManager = require(game.ServerScriptService.PlayerData.Manager)

local leaveEvent = game.ReplicatedStorage.Bindables.LeaveProcessed

local Players = game:GetService("Players")

Players.PlayerRemoving:Connect(function(player)
	
	if damageManager.TaggedPlayers[player] ~= nil and next(damageManager.TaggedPlayers[player]) ~= nil then
		print("Combat Logged")
		dataManager.Wipe(player)
	else
		print("Safe logged")
	end
	leaveEvent:Fire(player)
	task.wait(2)
end)

game:BindToClose(function()
	task.wait(1)
end)