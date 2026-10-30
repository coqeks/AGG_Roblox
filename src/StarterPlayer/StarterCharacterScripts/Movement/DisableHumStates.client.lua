local char = script.Parent.Parent
local hum = char:WaitForChild("Humanoid")

game.RunService.Heartbeat:Connect(function()
	hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
end)