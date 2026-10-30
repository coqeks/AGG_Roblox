local UIS = game:GetService("UserInputService")
local Replicated = game:GetService("ReplicatedStorage")
local Char = script.Parent.Parent.Character
local Player = game.Players.LocalPlayer
local mouse = Player:GetMouse()
local SkillModuleFolder = Replicated:WaitForChild("Combat"):WaitForChild("Movesets")
local skillReplicator = Replicated.RemoteEvents.SkillReplicator

local moduleLoader = require(game.ReplicatedStorage.Loaders.ModuleLoader)
local skillLoader = require(game.ReplicatedStorage.Loaders.SkillLoader)

skillReplicator.OnClientEvent:Connect(function(effectChar, skill, variant, target)
	print("Replicating")
	print(skill)
	local SkillModule = skillLoader[skill]
	if not SkillModule then warn("Skill module not found") return end
	print(SkillModule)
	
	local cancelSkill = effectChar:GetAttributeChangedSignal("CancelSkill"):Once(function()
		SkillModule.Stop(effectChar)
	end)

	if variant == "Holding" then 
		SkillModule.Holding(effectChar)
		print("Holding")
	elseif variant == "Finisher" then
		SkillModule.Finisher(effectChar, target)
		print("Finisher")
	else
		print("Released")
		SkillModule.Fire(effectChar, variant, target)
	end
	task.delay(5, function()
		cancelSkill:Disconnect()
	end)
end)


