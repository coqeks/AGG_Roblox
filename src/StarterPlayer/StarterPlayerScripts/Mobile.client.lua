local player = game.Players.LocalPlayer
local UIS = game:GetService("UserInputService")

if UIS.TouchEnabled then
	player:FindFirstChild("PlayerGui"):WaitForChild("Mobile").Enabled = true
end