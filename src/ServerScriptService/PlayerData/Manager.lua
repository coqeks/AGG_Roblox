--
--// Anything data related happens mostly here.
--


local Manager = {}

Manager.Profiles = {}
Manager.ProfileLoaded = Instance.new("BindableEvent")

local BadgeService = game:GetService("BadgeService")

local Remotes = game.ReplicatedStorage.RemoteEvents
local statConfig = require(game.ServerScriptService.Config.StatConfig)
local skillConfig = require(game.ServerScriptService.Config.SkillConfigs)
local adminConfig = require(game.ServerScriptService.Config.AdminConfig)
local updateCombatData = game.ReplicatedStorage.Bindables.CombatData
local updateSkillGui = game.ReplicatedStorage.RemoteEvents.PlayerData.GetSkills
local updateCurrency = game.ReplicatedStorage.RemoteEvents.GUI.UpdateCurrency
local notification = game.ReplicatedStorage.RemoteEvents.GUI.Notification

local function CheckSkillReq(player)
	local profile = Manager.Profiles[player]
	if not profile then return end
	
	local weaponClass = profile.Data.WeaponClass
	if profile.Data.Level >= 3 and profile.Data.WeaponMastery[weaponClass] >= 25 and not profile.Data.UnlockedSkills[weaponClass][1] then
		Manager.UnlockSkill(player, weaponClass, 1)
	end
	if profile.Data.Level >= 6 and profile.Data.WeaponMastery[weaponClass] >= 50 and not profile.Data.UnlockedSkills[weaponClass][2] then
		Manager.UnlockSkill(player, weaponClass, 2)
	end
	if profile.Data.Level >= 10 and profile.Data.WeaponMastery[weaponClass] >= 100 and not profile.Data.UnlockedSkills[weaponClass][3] then
		Manager.UnlockSkill(player, weaponClass, 3)
	end
	if profile.Data.Level >= 15 and BadgeService:UserHasBadgeAsync(player.UserId, 201499725643459) and not profile.Data.UnlockedSkills[weaponClass][4] then
		Manager.UnlockSkill(player, weaponClass, 4)
	end
end

local function checkBadgeReq(player)
	local profile = Manager.Profiles[player]
	if not profile then return end
	
	if profile.Data.Level >= 5 
		and profile.Data.PlayerKills >= 50 
		and not BadgeService:UserHasBadgeAsync(player.UserId, 4109035036498468) then
		BadgeService:AwardBadgeAsync(player.UserId, 4109035036498468)
	end
	if profile.Data.Level >= 10 
		and profile.Data.PlayerKills >= 250 
		and not BadgeService:UserHasBadgeAsync(player.UserId, 619131546789014) then
		BadgeService:AwardBadgeAsync(player.UserId, 619131546789014)
	end
	if profile.Data.Level >= 20
		and profile.Data.PlayerKills >= 1000 
		and not BadgeService:UserHasBadgeAsync(player.UserId, 4274889259251169) then
		BadgeService:AwardBadgeAsync(player.UserId, 4274889259251169)
	end
end

function Manager.GetData(player: Player)
	local profile = Manager.Profiles[player]
	if not profile then return nil end
	return profile.Data
end

function Manager.Wipe(player: Player)
	local profile = Manager.Profiles[player]
	if not profile then return end
	
	profile.Data.CombatExp = profile.Data.Level * 75
	profile.Data.Level = 1
	profile.Data.Stats["Available"] = 1
	
	for class, skills in profile.Data.UnlockedSkills do
		for index, skill in skills do
			profile.Data.UnlockedSkills[class][index] = false
		end
	end
	
	for class, mastery in profile.Data.WeaponMastery do
		profile.Data.WeaponMastery[class] = profile.Data.WeaponMastery[class] * 0.1
	end
	
	for statName, stat in profile.Data.Stats do
		if statName ~= "Available" then
			profile.Data.Stats[statName] = 0
		end
	end
	Manager.UpdateGUI(player)
	updateCurrency:FireClient(player, "Level", profile.Data.Level)
end

function Manager.AdjustKills(player: Player, victim: Player)
	local profile = Manager.Profiles[player]
	if not profile then return end
	profile.Data.PlayerKills += 1
	player.leaderstats.Kills.Value = profile.Data.PlayerKills
	player.leaderstats.Streak.Value += 5
	
	local victimProfile = Manager.Profiles[victim]
	if not victimProfile then return end
	Manager.AdjustCombatExp(player, 50 * victimProfile.Data.Level)
	Manager.AdjustGold(player, 10 * victimProfile.Data.Level)
	checkBadgeReq(player)
end

function Manager.AdjustCombatExp(player: Player, amount : number)
	local profile = Manager.Profiles[player]
	if not profile then return end
	
	local multiplier = statConfig.GetExpMult(profile.Data.Stats)
	
	profile.Data.CombatExp += math.round(amount * multiplier * 10) / 10
	profile.Data.WeaponMastery[profile.Data.WeaponClass] += math.round(amount * 10) / 100
	local expReq = statConfig.GetExpRequirement(profile.Data.Level)
	if profile.Data.CombatExp >= expReq and profile.Data.Level < 20 then
		profile.Data.CombatExp -= expReq
		Manager.AdjustLevel(player, 1)
	end
	
	CheckSkillReq(player)
	Manager.UpdateGUI(player)
end

function Manager.AdjustLevel(player: Player, amount : number)
	local profile = Manager.Profiles[player]
	if not profile then return end
	
	profile.Data.Level += amount
	profile.Data.Stats["Available"] += amount
	print("Level up!: ", profile.Data.Level)
	notification:FireClient(player, "LevelUp")
	
	CheckSkillReq(player)
	checkBadgeReq(player)
	Manager.AdjustGold(player, 100)
	updateCurrency:FireClient(player, "Level", profile.Data.Level)
end

function Manager.AdjustGold(player: Player, amount : number)
	local profile = Manager.Profiles[player]
	if not profile then return end
	
	profile.Data.Gold += amount
	updateCurrency:FireClient(player, "Gold", profile.Data.Gold)
end

function Manager.AdjustStats(player: Player, statName : string, amount : number)
	local profile = Manager.Profiles[player]
	if not profile then return end
	
	if profile.Data.Stats["Total"] == 20 then
		warn("Max stats reached")
		return
	end
	
	local expReq = statConfig.GetExpRequirement(profile.Data.Stats["Total"] + profile.Data.Stats["Available"])
	
	if profile.Data.Stats["Available"] > 0 then
		profile.Data.Stats[statName] += amount
		profile.Data.Stats["Total"] += amount
		profile.Data.Stats["Available"] -= amount
		print("1 SP allocated to: ", statName)
	else
		warn("Not enough EXP or available points")
		return
	end
		
	player.Character.Humanoid.MaxHealth = statConfig.GetHealth(profile.Data.Stats) + profile.Data.Level * 2.5
	
	Manager.UpdateGUI(player, "rbxassetid://127199850989931")	
	updateCombatData:Fire(player, nil)
end

function Manager.ResetStat(player: Player)
	local profile = Manager.Profiles[player]
	if not profile then return end
	
	profile.Data.Stats["Available"] = profile.Data.Stats["Total"] + profile.Data.Stats["Available"]
	profile.Data.Stats["Total"] = 0
	profile.Data.Stats["STR"] = 0
	profile.Data.Stats["AGI"] = 0
	profile.Data.Stats["DEF"] = 0
	profile.Data.Stats["INT"] = 0
	
	Manager.UpdateGUI(player)

	print("Stats reset", profile.Data.Stats)
end

function Manager.UpdateGUI(player: Player, sound : string)
	local profile = Manager.Profiles[player]
	if not profile then return end
	
	Remotes.GUI.UpdateStats:FireClient(
		player, profile.Data.Stats, 
		math.round(profile.Data.CombatExp * 10) / 10, 
		statConfig.GetExpRequirement(profile.Data.Stats["Total"] + profile.Data.Stats["Available"]),
		sound, profile.Data.WeaponMastery[profile.Data.WeaponClass]
	)
end

function Manager.UnlockSkill(player: Player, skillTree : string, skillNum : number)
	local profile = Manager.Profiles[player]
	if not profile then return end
	if profile.Data.UnlockedSkills[skillTree][skillNum] == nil then return end
	
	profile.Data.UnlockedSkills[skillTree][skillNum] = true
	
	Manager.PushSkillList(player)
end

-- [slot] = skill name for every usable skill of the current weapon class
function Manager.GetUnlockedSkillList(player: Player)
	local profile = Manager.Profiles[player]
	if not profile then return end
	
	local weaponClass = profile.Data.WeaponClass
	local unlockedList = {}
	for index in profile.Data.UnlockedSkills[weaponClass] or {} do
		if Manager.CheckSkill(player, index) then
			unlockedList[index] = skillConfig.Skills[weaponClass] and skillConfig.Skills[weaponClass][index]
		end
	end
	return unlockedList
end

function Manager.PushSkillList(player: Player)
	local unlockedList = Manager.GetUnlockedSkillList(player)
	if unlockedList then
		updateSkillGui:FireClient(player, unlockedList)
	end
end

function Manager.UnlockWeaponClass(player: Player, WeaponClass : string)
	local profile = Manager.Profiles[player]
	if not profile then return end
	
	profile.Data.UnlockedWeaponClass[WeaponClass] = true
	
end

function Manager.CheckSkill(player: Player, skillNum : number)
	local profile = Manager.Profiles[player]
	if not profile then return end
	--local skillName = skillConfig.Skills[profile.Data.WeaponClass][skillNum]
	--if not skillName then return end
	--local skill = tostring(skillNum) .. "_" .. skillName
	--print(skill)
	local classSkills = profile.Data.UnlockedSkills[profile.Data.WeaponClass]
	if not classSkills or classSkills[skillNum] == nil then return end
	
	-- Dev flag: skills 1-3 usable without being unlocked (profile data untouched)
	if adminConfig.GetFlag("FreeSkillUnlocks") and typeof(skillNum) == "number" and skillNum <= 3 then
		return true
	end
	
	return classSkills[skillNum]
end

local function GetAllData(player: Player)
	local profile = Manager.Profiles[player]
	if not profile then return end
	return profile.Data
end

return Manager
