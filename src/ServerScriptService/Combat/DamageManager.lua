local DamageManager = {}
local stateManager = require(game.ServerScriptService.PlayerStates.StateManager)
local dataManager = require(game.ServerScriptService.PlayerData.Manager)
local statConfig = require(game.ServerScriptService.Config.StatConfig)
local weaponConfig = require(game.ServerScriptService.Config.WeaponConfig)

local blockEvent = game.ReplicatedStorage.Bindables.BlockedHit
local hitEvent = game.ReplicatedStorage.RemoteEvents.Effects.HitEffect
local blockEffect = game.ReplicatedStorage.RemoteEvents.Effects.BlockEffect
local weaveEvent = game.ReplicatedStorage.RemoteEvents.Effects.Weave

local deathEvent = game.ServerScriptService.Combat.DeathService.Event
local tagEvent = game.ReplicatedStorage.RemoteEvents.GUI.CombatTag

DamageManager.CachedDamage = {}
DamageManager.TaggedPlayers = {}
DamageManager.Damage = Instance.new("BindableEvent")

local DamageTypes = {
	Slash = "Slash",
	Blunt = "Blunt",
	Pierce = "Pierce"
}

export type Params = {
	Damage : number,
	DamageType : {"Slash" | "Blunt" | "Pierce"},
	Knockback : number,
	States : {any},
	IgnoreBlock : boolean,
	BlockBreak : boolean,
	Crittable : boolean,
	TrueStun : boolean,
	HitRagdoll : boolean,
}

local EXECUTE_THRESHOLD = 0.08 -- Execution passive: hits that leave the target under 8% max HP kill

local function hasPassive(char : Model, name : string)
	local passives = char and char:FindFirstChild("Passives")
	return passives ~= nil and passives:FindFirstChild(name) ~= nil
end

local function rollCrit(chance : number)
	if not chance then return false end
	local rolled = math.random(1, 100)
	return rolled <= chance
end

local function dotCheck(char, hitter)
	print("calculating dot")
	local hrp = char:FindFirstChild("HumanoidRootPart")          -- defender
	local attackerHrp = hitter:FindFirstChild("HumanoidRootPart") -- attacker
	if not hrp or not attackerHrp then return false end

	-- Direction from defender to attacker
	local direction = (attackerHrp.Position - hrp.Position).Unit
	-- Defender's look vector
	local look = hrp.CFrame.LookVector

	-- If dot > 0, attacker is roughly in front of the defender
	local dot = look:Dot(direction)
	return dot > 0
end

function DamageManager:GetKillCreditAttacker(target : Model, lastAttacker)
	local targetCache = DamageManager.CachedDamage[target]
	if not targetCache then return lastAttacker end

	-- Add 25 bonus damage to the last attacker's cache before evaluating
	if targetCache[lastAttacker] then
		targetCache[lastAttacker].Damage = (targetCache[lastAttacker].Damage or 0) + 25
	else
		targetCache[lastAttacker] = { Damage = 25, Token = tick() }
	end

	-- Find attacker with highest cached damage
	local topAttacker = lastAttacker
	local topDamage = 0

	for attacker, data in pairs(targetCache) do
		if data.Damage and data.Damage > topDamage then
			topDamage = data.Damage
			topAttacker = attacker
		end
	end

	return topAttacker
end

function DamageManager:TakeDamage(
	target : Model,
	attacker : Player,
	DamageParams : Params
	--Returns hit: boolean, killed: boolean
)
	
	local damage = DamageParams.Damage
	local damageType = DamageParams.DamageType
	local appliedStates = DamageParams.States
	local ignoreBlock = DamageParams.IgnoreBlock
	local blockBreak = DamageParams.BlockBreak
	local crittable = DamageParams.Crittable
	local trueStun = DamageParams.TrueStun ~= false -- defaults to true
	local hitRagdoll = DamageParams.HitRagdoll or false

	if not target or not attacker then return end

	local attackerChar
	if attacker:IsA("Player") then
		attackerChar = attacker.Character
	else
		attackerChar = attacker
	end

	if not attackerChar then return end

	local attackerData = dataManager.GetData(attacker) or nil
	if not attackerData and not attacker:HasTag("Dummy") and not attacker:HasTag("Entity") then warn("No Attacker Data") return end

	-- State check
	if stateManager:HasState(target, "IFrame") or stateManager:HasState(target, "PDFrame") then
		return false
	end
	
	if stateManager:HasState(target, "PBFrame") and not ignoreBlock and dotCheck(target, attackerChar) then
		print("PBFrame")
		stateManager:AddState(attackerChar, "Stun", 0.15)
		blockEvent:Fire(target, attackerChar, damage)
		return false
	end
	
	if stateManager:HasState(target, "Blocking") and not ignoreBlock and dotCheck(target, attackerChar) then
		blockEvent:Fire(target, attackerChar, damage)
		local health = target:FindFirstChild("Humanoid").Health - damage / 3
		if stateManager:HasState(target, "Amputate_Arm") then
			health = target:FindFirstChild("Humanoid").Health - damage / 2
		end
		target:FindFirstChild("Humanoid").Health = math.max(health, 1)
		return false
	end
	
	if stateManager:HasState(target, "Ragdoll") and hitRagdoll == false then
		print("Cant hit ragdoll")
		return false 
	end
	
	if hasPassive(target, "Godspeed") then
		local dodgeRoll = math.random(1, 100)
		if dodgeRoll <= 10 then
			print("Weaved")
			weaveEvent:FireAllClients(target)
			return false
		end
	end

	-- Crit logic
	local isCrit = false

	if crittable and not hasPassive(target, "Unwavering Resolve") then
		-- Entities (PvE) have no profile; they carry a CritChance attribute instead
		local critChance = attackerData and statConfig.GetCritChance(attackerData.Stats)
			or attackerChar:GetAttribute("CritChance") or 5
		
		if stateManager:HasState(attackerChar, "Awakened") then
			critChance += 30
			damage *= 1.2
		end
		
		isCrit = rollCrit(critChance)
	end

	if isCrit then
		damage *= 1.5
		print("Critical Hit")
	end
	if stateManager:HasState(target, "Fear") then
		print("Feared")
		damage *= 1.1
	end
	if stateManager:HasState(attackerChar, "Fear") then
		damage *= 0.9
	end

	local targetHum = target:FindFirstChild("Humanoid")
	if not targetHum then return end

	-- Apply states if any
	if appliedStates then
		for state, duration in pairs(appliedStates) do
			if typeof(duration) == "table" then
				print("Duration: ", duration[1], "value: ", duration[2])
				stateManager:AddState(target, state, duration[1], duration[2])
			else
				stateManager:AddState(target, state, duration)
			end
		end
	end

	-- Fire effect event
	if DamageTypes[damageType] ~= nil then
		hitEvent:FireAllClients(target, damageType, isCrit)
	end
	
	local targetPlr = game.Players:GetPlayerFromCharacter(target)
	
	-- Update cached damage
	local token = tick()

	if not DamageManager.CachedDamage[target] then
		DamageManager.CachedDamage[target] = {}
	end
	if not DamageManager.CachedDamage[target][attacker] then
		DamageManager.CachedDamage[target][attacker] = {}
	end

	DamageManager.CachedDamage[target][attacker].Token = token
	if DamageManager.CachedDamage[target][attacker].Damage then
		DamageManager.CachedDamage[target][attacker].Damage += damage
	else
		DamageManager.CachedDamage[target][attacker].Damage = damage
	end
	
	if not DamageManager.TaggedPlayers[targetPlr] and targetPlr then
		DamageManager.TaggedPlayers[targetPlr] = {}
	end
	if targetPlr and not DamageManager.TaggedPlayers[targetPlr][attacker] then
		DamageManager.TaggedPlayers[targetPlr][attacker] =  token
	end
	
	

	--print("Cached Damage: ", DamageManager.CachedDamage[target][attacker].Damage)

	task.delay(15, function()
		if DamageManager.CachedDamage[target] and DamageManager.CachedDamage[target][attacker] then
			if DamageManager.CachedDamage[target][attacker].Token == token then
				DamageManager.CachedDamage[target][attacker] = nil
				print("Cache cleared for: ", target)
			end
		end
		local tags = targetPlr and DamageManager.TaggedPlayers[targetPlr]
		if tags and tags[attacker] == token then
			tags[attacker] = nil
			print("Tag from: ", attacker, " cleared for: ", targetPlr)
		end
	end)
	
	local health = targetHum.Health - damage
	stateManager:RemoveState(target, "Blocking")
	stateManager:AddCooldown(target, "Block", 1)
	stateManager:AddState(target, "CombatTagged", 15)
	
	if hasPassive(attackerChar, "Execution") and health > 0 and health <= targetHum.MaxHealth * EXECUTE_THRESHOLD then
		health = 0
	end
	
	if hasPassive(attackerChar, "Precise Strike") then
		local part 
		if isCrit and rollCrit(50) then
			if rollCrit(50) then
				part = "Left Arm"
				stateManager:AddState(target, "Amputate_Arm", 10)
			else
				part = "Right Leg"
				stateManager:AddState(target, "Amputate_Leg", 10)
			end
			print("Precise Strike")
			game.ReplicatedStorage.RemoteEvents.Effects.Amputate:FireAllClients(target, part)
		end
	end

	if health <= 0  and not target:HasTag("Killed") then
		local targetPlr = game.Players:GetPlayerFromCharacter(target)
		if not targetPlr then
			targetHum:ChangeState(Enum.HumanoidStateType.Dead)
			stateManager:AddState(target, "Ragdoll", 5, true)
		end
		deathEvent:Fire(targetPlr, attacker)
		targetHum.Health = 0.1
		return true, true
	else 
		targetHum.Health = health
	end

	return true, false
end

return DamageManager