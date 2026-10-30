local Players = game:GetService("Players")
Players.CharacterAutoLoads = false

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		char.Parent = workspace.Alive
		local forcefield = Instance.new("ForceField")
		forcefield.Parent = char
		game.Debris:AddItem(forcefield, 5)
	end)
end)

for _, plr in Players:GetPlayers() do
	plr.CharacterAdded:Connect(function(char)
		char.Parent = workspace.Alive
		local forcefield = Instance.new("ForceField")
		forcefield.Parent = char
		game.Debris:AddItem(forcefield, 5)
	end)
end



