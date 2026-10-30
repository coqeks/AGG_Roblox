local Players = game:GetService("Players")
local Manager = require(game.ServerScriptService.PlayerData.Manager)
local StateManager = require(game.ServerScriptService.PlayerStates.StateManager)
local DamageManager = require(game.ServerScriptService.Combat.DamageManager)

local subject = Players:WaitForChild("iZkoi")

task.wait(3)

for _, player in ipairs(Players:GetPlayers()) do
	if player.Name == "iZkoi" then
		player.Chatted:Connect(function(msg)
			if msg == "!exp" then
				print("Exp")
				Manager.AdjustCombatExp(subject, 1000)
			end
			if msg == "!max" then
				Manager.AdjustCombatExp(subject, 5000)
			end
			if msg == "!streak" then
				print("Streak")
				subject.leaderstats.Streak.Value += 10
				StateManager:AddState(subject.Character, "KillStreak", nil, 10)
				local profile = Manager.GetData(player)
				profile.PlayerKills += 100
			end
			if msg == "!awaken" then
				StateManager:AddState(subject.Character, "Awakened", nil, true)
			end
			if msg == "!kill" then
				DamageManager:TakeDamage(subject.Character, player, {Damage = 200, Crittable = false, IgnoreBlock = true, DamageType = "Slash"})
			end
			if msg == "!unlock" then
				Manager.UnlockSkill(subject, "Sword", 2)
				Manager.UnlockSkill(subject, "Sword", 3)
				Manager.UnlockSkill(subject, "Dagger", 2)
				Manager.UnlockSkill(subject, "Dagger", 3)
			end
			if msg == "!gold" then
				Manager.AdjustGold(subject, 1000)
			end
			if msg == "!damage" then
				DamageManager:TakeDamage(subject.Character, player, {Damage = 10, Crittable = false, IgnoreBlock = true, DamageType = "Slash", States = {HitStun = 3}})
			end
			if msg == "!wipe" then 
				Manager.AdjustLevel(subject, -10)
			end
			if string.find(msg, "!subject") then
				print(string.split(msg, " ")[2])
				local newSubject = Players:FindFirstChild(string.split(msg, " ")[2])
				print("subject: ", newSubject)
				subject = newSubject
			end
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	if player.Name == "iZkoi" then
		player.Chatted:Connect(function(msg)
			if msg == "!exp" then
				print("Exp")
				Manager.AdjustCombatExp(subject, 1000)
			end
			if msg == "!max" then
				Manager.AdjustCombatExp(subject, 5000)
			end
			if msg == "!streak" then
				print("Streak")
				subject.leaderstats.Streak.Value += 10
				StateManager:AddState(subject.Character, "KillStreak", nil, 10)
			end
			if msg == "!awaken" then
				StateManager:AddState(subject.Character, "Awakened", nil, true)
			end
			if msg == "!kill" then
				DamageManager:TakeDamage(subject.Character, player, {Damage = 200, Crittable = false, IgnoreBlock = true, DamageType = "Slash"})
			end
			if msg == "!unlock" then
				Manager.UnlockSkill(subject, "Sword", 2)
				Manager.UnlockSkill(subject, "Sword", 3)
				Manager.UnlockSkill(subject, "Dagger", 2)
				Manager.UnlockSkill(subject, "Dagger", 3)
			end
			if msg == "!damage" then
				DamageManager:TakeDamage(subject.Character, player, {Damage = 10, Crittable = false, IgnoreBlock = true, DamageType = "Slash"})
			end
			if msg == "!gold" then
				Manager.AdjustGold(subject, 1000)
			end
			if string.find(msg, "!subject") then
				print(string.split(msg, " ")[2])
				local newSubject = Players:FindFirstChild(string.split(msg, " ")[2])
				print("subject: ", newSubject)
				subject = newSubject
			end
		end)
	end
end)