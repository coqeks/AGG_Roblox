local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local PlayerModule = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule"))
local Controls = PlayerModule:GetControls()

local controlEvent = ReplicatedStorage.Bindables.ControlsEvent

controlEvent.Event:Connect(function(enable)
	if enable then
		Controls:Enable()
	else
		Controls:Disable()
	end
end)