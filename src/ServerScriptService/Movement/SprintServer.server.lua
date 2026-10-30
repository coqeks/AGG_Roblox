local stateManager = require(game.ServerScriptService.PlayerStates.StateManager)
local sprintEvent = game.ReplicatedStorage.RemoteEvents.Movement.SprintEvent

sprintEvent.OnServerEvent:Connect(function(plr, char, action)
	if action == false then
		stateManager:RemoveState(char, "Sprinting")
	else
		stateManager:AddState(char, "Sprinting")
	end
end)

