-- Client Loader
local Loader = {}

local modules = {}

for _, module in ipairs(game.ServerStorage.MovesetLogic:GetChildren()) do
	if module:IsA("ModuleScript") and module ~= script then
		modules[module.Name] = require(module)
	end
end

return modules
