--// Services
local Players = game:GetService("Players")

--// Constants
local Player : Player = Players.LocalPlayer
local ragdollEvent = game.ReplicatedStorage.RemoteEvents.Combat.Ragdoll


--// Function's
ragdollEvent.OnClientEvent:Connect(function(Character)
	--// Instances
	local Torso: BasePart = Character:WaitForChild("Torso")
	local Humanoid: Humanoid = Character:FindFirstChildWhichIsA("Humanoid") or Character:WaitForChild("Humanoid")

	local IsRagdoll = Character:GetAttribute("Ragdoll")

	if IsRagdoll == true then
		task.wait(0.1)
		Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)

		Torso:ApplyImpulse(Torso.CFrame.LookVector * -100)
		
	elseif Humanoid:GetState() == Enum.HumanoidStateType.Ragdoll then
		print("Unragdolling")
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end)
	

--local KBEvent = game.ReplicatedStorage.RemoteEvents.Movement.KnockBack

--KBEvent.OnClientEvent:Connect(function(vector, target : Model)
--	print("Knockback")
--	local torso = target:WaitForChild("Torso")
--	torso:ApplyImpulse(vector)
--end)


