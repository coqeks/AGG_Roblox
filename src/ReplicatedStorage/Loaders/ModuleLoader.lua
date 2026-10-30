-- Client Loader
local Loader = {}

local modules = {}

for _, module in ipairs(game.ReplicatedStorage.Modules:GetChildren()) do
	if module:IsA("ModuleScript") then
		modules[module.Name] = require(module)
	end
end

-- Optional Init phase
for _, module in pairs(modules) do
	if type(module) == "table" and module.Init then
		module:Init()
	end
end

-- Optional Start phase (runs after Init)
--for _, module in pairs(modules) do
--	if type(module) == "table" and module.Start then
--		task.spawn(function()
--			module:Start()
--		end)
--	end
--end

return modules
