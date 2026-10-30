local stateManager = require(game.ServerScriptService.PlayerStates.StateManager)

local evasiveEvent = game.ReplicatedStorage.RemoteEvents.Combat.Evasive
local weaveEvent = game.ReplicatedStorage.RemoteEvents.Effects.Weave
local evasiveEffect = game.ReplicatedStorage.RemoteEvents.Effects.Evasive

evasiveEvent.OnServerEvent:Connect(function(player)
	local char = player.Character
	if not char then return end
	
	if stateManager:CheckCooldown(char, "Evasive") then warn("Evasive cooldown") return end
	if stateManager:CheckStun(char) then
		print("Evasive")
		stateManager:RemoveStun(char)
		stateManager:AddState(char, "IFrame", 0.25)
		stateManager:AddState(char, "FlickerDashing", 0.25)
		stateManager:AddCooldown(char, "Evasive", 30)
		weaveEvent:FireAllClients(char)
		evasiveEffect:FireAllClients(char)
	end
end)