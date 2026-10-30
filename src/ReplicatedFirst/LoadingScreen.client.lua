local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create a basic loading screen
local screenGui = script.ScreenGui

screenGui.Parent = playerGui
screenGui.Enabled = true
screenGui.Frame.TextLabel.BackgroundTransparency = 0

if not game:IsLoaded() then
	game.Loaded:Wait()
end

if game:IsLoaded() or player:IsLoaded() then
	
	task.wait(2)
	
	TweenService:Create(screenGui.Frame.TextLabel, TweenInfo.new(5), {BackgroundTransparency = 1, TextTransparency = 1}):Play()

	task.wait(5)

	screenGui.Enabled = false
end