-- Client Loader
local Loader = {}

local modules = {}

for _, module in ipairs(game.ReplicatedStorage.Combat.Movesets:GetChildren()) do
	if module:IsA("ModuleScript") then
		modules[module.Name] = require(module)
		
		modules[module.Name].Preload(game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait())
		
	end
end

return modules
