local PhysicsService = game:GetService("PhysicsService")

PhysicsService:RegisterCollisionGroup("Player")
PhysicsService:RegisterCollisionGroup("AfterImage")

PhysicsService:CollisionGroupSetCollidable("Player", "AfterImage", false)

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CollisionGroup = "Player"
			end
		end
	end)
end)

for _, model in workspace:WaitForChild("Alive"):GetDescendants() do
	if model:IsA("Model") then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CollisionGroup = "Player"
			end
		end
	end
end