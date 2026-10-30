-- SkillHandler.lua
-- Refactored: validation extracted, damage params built once per section,
-- projectile logic consolidated, HitSomeone connected once with guard.

local skillReplicator = game.ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("SkillReplicator")
local getSkills       = game.ReplicatedStorage.RemoteEvents.PlayerData.GetSkills
local skillCooldown   = game.ReplicatedStorage.RemoteEvents.GUI.SkillCD
local knockBack       = game.ReplicatedStorage.RemoteEvents.Movement.KnockBack

local stateManager  = require(game.ServerScriptService.PlayerStates.StateManager)
local dataManager   = require(game.ServerScriptService.PlayerData.Manager)
local weaponConfig  = require(game.ServerScriptService.Config.WeaponConfig)
local damageManager = require(game.ServerScriptService.Combat.DamageManager)
local adminConfig   = require(game.ServerScriptService.Config.AdminConfig)

-- Skill classes (subclasses of Combat.SkillClasses.Skill), keyed by skill name
local skillLoader = require(game.ServerStorage.MovesetLogic.Loader)

local RunService = game:GetService("RunService")

local UsableSkills = {
	["Sword"] = {
		[1] = "Rapid Pierce",
		[2] = "Cross Slash",
		[3] = "Lightspeed Strike",
		[4] = "War Cry"
	},
	["Dagger"] = {
		[1] = "Dagger Throw",
		[2] = "Shade Step",
		[3] = "Lethality"
	},
	["GreatSword"] = {
		[1] = "Rising Blade",
		[2] = "Lion's Claw",
		[3] = "Berserk"
	},
	["Spear"] = {
		[1] = "Piercing Strike",
		[2] = "Whirlwind",
		[3] = "Serpent Storm"
	}
}


-- ─── Skill validation ────────────────────────────────────────────────────────

--- Returns (weaponClass, skill, config) or (nil, reason) on failure.
-- Keeps the OnServerEvent handler readable by moving all guard clauses here.
local function validateSkillUse(player, char, skillNum)
	local weaponClass = weaponConfig.FindWeaponClass(char:GetAttribute("WeaponEquipped"))
	if not weaponClass then
		return nil, "No weapon type found"
	end

	local skill = UsableSkills[weaponClass][skillNum]
	local skillModule = skillLoader[skill]
	if not skillModule then
		return nil, "No module for: " .. tostring(skill)
	end
	local config = skillLoader[skill].Config
	if not config then
		return nil, "No config for: " .. tostring(skill)
	end

	if stateManager:CheckCooldown(char, skill)    then return nil, "Skill on cooldown: " .. skill end
	if stateManager:CheckCooldown(char, "Skill")  then return nil, "Global cooldown active" end
	if stateManager:HasState(char, "UsingSkill")  then return nil, "Already using a skill" end
	if stateManager:HasState(char, "Dashing")     then return nil, "Dashing" end
	if stateManager:CheckStun(char)               then return nil, "Stunned" end
	if not dataManager.CheckSkill(player, skillNum) then
		return nil, "Player does not have skill: " .. tostring(skill)
	end

	return skillModule, skill, config
end

-- ─── Main event handler ──────────────────────────────────────────────────────

skillReplicator.OnServerEvent:Connect(function(player: Player, skillNum: number, target)
	local char = player.Character
	if not char then return end
	
	print("Skill Replicator Event Fired")
	print(target)

	local skillModule, skill, config = validateSkillUse(player, char, skillNum)
	if not skillModule then
		return warn(skill) -- 'skill' holds the error string on failure
	end
	print("Skill Module Found: ", skillModule)
	
	if config.RequireTarget then
		if not target or not target:IsA("Model") then
			return warn("Target missing or invalid")
		end
	end

	-- Per-skill check that runs before the cooldown is spent (Skill:CanUse, overridden per skill)
	local ok, reason = skillModule:CanUse(player, target)
	if not ok then
		return warn(reason or ("Can't use " .. skill))
	end

	-- Apply cooldown (shortened by 5s while awakened; dev flag forces 3s)
	local cd = math.max(config.CD - (char:GetAttribute("Awakened") and 5 or 0), 0)
	if adminConfig.GetFlag("ShortSkillCooldowns") then
		cd = 3
	end
	stateManager:AddCooldown(char, skill, cd)
	--stateManager:AddState(char, "UsingSkill", config.Duration)
	stateManager:RemoveState(char, "Sprinting")

	skillModule:Cast(player, target)
	skillCooldown:FireClient(player, skillNum, cd)
	dataManager.AdjustCombatExp(player, 25)
end)

-- ─── Skill list query ────────────────────────────────────────────────────────

getSkills.OnServerEvent:Connect(function(player: Player)
	dataManager.PushSkillList(player)
end)