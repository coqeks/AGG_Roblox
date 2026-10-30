local player = game.Players.LocalPlayer
local updatePassive = game.ReplicatedStorage.RemoteEvents.Effects.PassiveCosmetic

local connections = {
	added = {},
	removed = {}
}

local function setCosmetic(character : Model)
	local passives = character:WaitForChild("Passives")
	local status = character:WaitForChild("Status")
	
	local passiveCosmetic = character:FindFirstChild("PassiveCosmetic")
	if not passiveCosmetic then 
		passiveCosmetic = Instance.new("Folder", character)
		passiveCosmetic.Name = "PassiveCosmetic"
	end
	passiveCosmetic:ClearAllChildren()

	if passives:FindFirstChild("Enlightened") then
		local fx = game.ReplicatedStorage.VFX["Enlightened Eyes"].VFXHead:Clone()
		fx.Parent = passiveCosmetic
		fx.Weld.Part1 = character:WaitForChild("Head")
	end
	
	if connections.added.character then connections.added.character:Disconnect() end
	connections.added.character = status.ChildAdded:Connect(function(child)
		if child.Name == "Rhythmic Tendency" then
			local rtStacks = 0
			for _, child in status:GetChildren() do
				if child.Name == "Rhythmic Tendency" then
					rtStacks += 1
				end
			end
			if rtStacks >= 3 then
				local fx = game.ReplicatedStorage.VFX["Rhythmic Tendency"].RTAura:Clone()
				local fx2 = fx:Clone()
				fx.Parent = character:FindFirstChild("Right Arm")
				fx2.Parent = character:FindFirstChild("Left Arm")
			end
		end
	end)
	
	if connections.removed.character then connections.removed.character:Disconnect() end
	connections.removed.character = status.ChildRemoved:Connect(function(child)
		if child.Name == "Rhythmic Tendency" then
			local fx = character:FindFirstChild("Right Arm"):FindFirstChild("RTAura")
			local fx2 = character:FindFirstChild("Left Arm"):FindFirstChild("RTAura")
			if fx then
				fx:Destroy()
			end
			if fx2 then
				fx2:Destroy()
			end
		end
	end)
	
end

updatePassive.OnClientEvent:Connect(setCosmetic)