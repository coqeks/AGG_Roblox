local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")
local Manager = require(game.ServerScriptService.PlayerData.Manager)
local DamageManager = require(game.ServerScriptService.Combat.DamageManager)
local StateManager = require(game.ServerScriptService.PlayerStates.StateManager)
local killLogEvent = game.ReplicatedStorage.RemoteEvents.GUI.KillLog
local awakenEvent = game.ReplicatedStorage.RemoteEvents.Combat.Awaken

local function checkAwakeningReq(player)
	local profile = Manager.GetData(player)
	local character = player.Character
	local leaderstats = player:FindFirstChild("leaderstats")
	if not profile or not character or not leaderstats then
		return false
	end
	
	local cointoss = math.random(1,100)
	
	if cointoss <= 10 then
		return false
	end
	
	--// Kill req
	if profile.Level < 15 then
		print("nope")
		return false
	end
	
	local killStreak = character:GetAttribute("KillStreak")
	if typeof(killStreak) ~= "number" then killStreak = 0 end
	if killStreak < 10 or leaderstats.Streak.Value < 10 then
		print("nope")
		return false
	end
	
	return true
end

script.Event.Event:Connect(function(player, killer)
	
	if not player then return end
	local char = player.Character
	
	local profile = Manager.GetData(player)
	if not profile then return end
	
	-- Determine kill credit winner (adds +25 to last attacker, picks highest damage dealer)
	local killCreditAttacker = DamageManager:GetKillCreditAttacker(player.Character, killer)
	-- Kill credit can go to a Player or to a character Model (a PvE entity or a dummy)
	local killCreditChar
	if killCreditAttacker and killCreditAttacker:IsA("Player") then
		killCreditChar = killCreditAttacker.Character
	else
		killCreditChar = killCreditAttacker or killer
	end

	-- Clear the full target cache on death
	DamageManager.CachedDamage[player.Character] = nil
	
	if checkAwakeningReq(player) and not StateManager:HasState(char, "Awakened") and not StateManager:HasState(char, "Cooked") then
		killLogEvent:FireClient(player, killer.Name, char:GetAttribute("KillStreak"), profile.Level * 75)
		awakenEvent:FireAllClients(player, 1)
		StateManager:AddState(char, "Awakened", 120)
		StateManager:AddState(char, "IFrame", 15)
		StateManager:AddState(char, "Ragdoll", 14)
		task.delay(10, function()
			StateManager:AddStatus(char, "HealthRegen", 10, 5)
		end)
		Manager.UnlockSkill(player, profile.WeaponClass, 4)
		if not BadgeService:UserHasBadgeAsync(player.UserId, 201499725643459) then
			BadgeService:AwardBadgeAsync(player.UserId, 201499725643459)
		end
	elseif not player.Character:HasTag("Killed") then
		killLogEvent:FireClient(player, killer.Name, char:GetAttribute("KillStreak"), profile.Level * 75)
		
		player.Character:AddTag("Killed")
		StateManager:AddState(player.Character, "Ragdoll", nil, true)

		print("Kill credited to: ", killCreditAttacker)
		if killCreditAttacker ~= player and killCreditAttacker:IsA("Player") then
			Manager.AdjustKills(killCreditAttacker, player)
		end
		
		if killCreditChar then
			local currentStreak = killCreditChar:GetAttribute("KillStreak") or 0
			StateManager:AddState(killCreditChar, "KillStreak", nil, currentStreak + 5)
		end
		player.leaderstats.Streak.Value = 0
		Manager.Wipe(player)
		task.wait(5)
		player.Character:Destroy()
		player:LoadCharacterAsync()
		StateManager:AddState(player.Character, "IFrame", 3)
	end
end)

