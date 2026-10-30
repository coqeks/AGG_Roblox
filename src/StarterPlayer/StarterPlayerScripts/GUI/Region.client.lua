local locationEvent = game.ReplicatedStorage.RemoteEvents.GUI:FindFirstChild("LocationData")
local Topbar = require(game.ReplicatedStorage.Modules.Icon)

locationEvent.OnClientEvent:Connect(function(data)
	print(data[1], data[2])
	
	
end)