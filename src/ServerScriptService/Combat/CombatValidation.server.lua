local AttackRemote = game.ReplicatedStorage.RemoteEvents.Combat.Attack
local dashEvent = game.ReplicatedStorage.RemoteEvents.Movement.DashEvent
local killMomentum = game.ReplicatedStorage.RemoteEvents.Movement.KillDashEvent
local knockBack = game.ReplicatedStorage.RemoteEvents.Movement.KnockBack

local HitBoxMod = require(game.ReplicatedStorage.Combat.HBDetection)
local HitBoxConfig = require(game.ServerScriptService.Config.WeaponConfig)
local bindable = game.ReplicatedStorage.Bindables.CombatData
local blockEvent = game.ReplicatedStorage.Bindables.BlockedHit
local stateManager = require(game.ServerScriptService.PlayerStates.StateManager)
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Manager = require(game.ServerScriptService.PlayerData.Manager)
local StatConfig = require(game.ServerScriptService.Config.StatConfig)
local DamageManager = require(game.ServerScriptService.Combat.DamageManager)
local Knockback = require(game.ServerScriptService.Combat.Knockback)

local HitboxClass = require(game.ReplicatedStorage.Combat.HitboxClass)
local HitboxType = require(game.ReplicatedStorage.Combat.HitboxClass.Types)

local playerCombatData = {}

stateManager.InitCharacter(game.Workspace.Alive.AttackDummy)

-- =========================
-- Values
-- =========================

local CRIT_CHANCE = 5 --percent
local CRIT_DAMAGE = 1.5 --multiplier
local RESET_TIME = 3 --seconds before m1 chain reset


-- =========================
-- Utilities
-- =========================

local function rhythmicTendency(char)
	local status = char:FindFirstChild("Status")
	local rtStacks = 0
	for _, child in status:GetChildren() do
		if child.Name == "Rhythmic Tendency" then
			rtStacks += 1
		end
	end

	return rtStacks
end

local function hitHandler(hitList, plr, data, states)
	local char = plr.Character
	for _, target in ipairs(hitList) do
		-- Distance sanity check
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			if (targetRoot.Position - char.HumanoidRootPart.Position).Magnitude > 20 then
				continue -- suspicious
			end
		end
		
		Knockback.StopMomentum(target)
		
		local DamageParams = {
			Damage = data.Damage,
			DamageType = data.DamageType,
			States = states,
			IgnoreBlock = false,
			BlockBreak = false,
			Crittable = true,
			HitRagdoll = false
		} ::  DamageManager.Params
		
		if char:FindFirstChild("Passives"):FindFirstChild("Powerful Blow") and data.Combo == 1 then
			DamageParams.Damage *= 1.5
			DamageParams.IgnoreBlock = true
		end

		local targetHum = target:FindFirstChild("Humanoid")
		if targetHum and DamageManager:TakeDamage(target, plr, DamageParams) then
			local direction = (target.HumanoidRootPart.Position - char.HumanoidRootPart.Position).Unit
			if data.Combo == 1 then
				target.HumanoidRootPart.CFrame = CFrame.lookAt(target.HumanoidRootPart.Position, char.HumanoidRootPart.Position)
				Knockback.Apply(target, char.HumanoidRootPart.CFrame.LookVector, 50, 0.05)
				Knockback.Apply(char, direction, 13, 0.1)
			else
				Knockback.Apply(target, direction, 15, 0.1)
				Knockback.Apply(char, direction, 13, 0.1)
			end
			
			if char:FindFirstChild("Passives"):FindFirstChild("Rhythmic Tendency") then
				local rtStacks = rhythmicTendency(char)
				if rtStacks < 5 then
					local stack = Instance.new("BoolValue")
					stack.Name = "Rhythmic Tendency"
					stack.Parent = char:FindFirstChild("Status")
					Debris:AddItem(stack, 6)
					rtStacks += 1
				end
			end
		end
	end
end

-- =========================
-- Connection 
-- =========================

AttackRemote.OnServerEvent:Connect(function(player, attackType)
	
	local char = player.Character
	if not char then return end

	local hum = char:FindFirstChild("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end

	-- Setup player data
	if not playerCombatData[player] then
		print("Combat data not found")
		return 
	end

	local data = playerCombatData[player]
	local now = tick()
	local cancel = false
	
	------------------------------------------------
	-- Status Logic
	------------------------------------------------
	local effectiveEndlag   = data.Endlag
	local effectiveHitDelay = data.HitDelay

	local status = char:FindFirstChild("Status")
	if status then
		local rtStacks = rhythmicTendency(char)
		if rtStacks > 0 then
			local reduction = 1 - (rtStacks * 0.025)
			effectiveEndlag   = data.Endlag   * reduction
			effectiveHitDelay = data.HitDelay * reduction
		end
	end
	
	------------------------------------------------
	-- 1️⃣ Cooldown validation
	------------------------------------------------
	local cooldown = effectiveEndlag

	if now - data.LastM1 < cooldown then
		print("Too fast!")
		return -- reject spam
	end
	if now - data.LastM1 > RESET_TIME then
		data.Combo = 1
	end

	data.LastM1 = now

	------------------------------------------------
	-- 2️⃣ Airborne / stun validation
	------------------------------------------------
	if stateManager:CheckStun(char) 
		or stateManager:CheckCooldown(char, "M1") 
		or stateManager:HasState(char, "Dashing") 
		or stateManager:HasState(char, "Blocking") 
		or stateManager:HasState(char, "UsingSkill") then 
		return
	end
	
	char:GetAttributeChangedSignal("HitStun"):Once(function()
		if char:HasTag("HitStun") then
			cancel = true
		end
	end)

	------------------------------------------------
	-- 4️⃣ Handle combo
	------------------------------------------------
	local lastHit
	data.Combo += 1
	if data.Combo > data.MaxCombo then
		data.Combo = 1
		lastHit = true
		stateManager:AddCooldown(char,"M1", 1.25 + effectiveEndlag)
	else
		stateManager:AddCooldown(char, "M1", effectiveEndlag + effectiveHitDelay)
	end

	AttackRemote:FireClient(player, data.Combo)
	
	------------------------------------------------
	-- Trail enabling
	------------------------------------------------

	local weapon = char:FindFirstChild("Handle")
	for _, part in weapon:GetDescendants() do
		if part:IsA("Trail") or part:IsA("ParticleEmitter") then
			task.delay(0.3, function()
				part.Enabled = true
				task.delay(0.2, function()
					part.Enabled = false
				end)
			end)
		end
	end

	if attackType == "M1" then 
		
		stateManager:AddCooldown(char, "Block", effectiveEndlag + effectiveHitDelay + 0.25)
		stateManager:AddCooldown(char, "Skill", effectiveEndlag + effectiveHitDelay)
		stateManager:RemoveState(char, "Sprinting")
		stateManager:AddState(char, "Slow", 0.5, 2)
		stateManager:AddState(char, "JumpLock", 0.7)
		-- Marks the swing so PvE entities (Entities.Brain) can react to it
		stateManager:AddState(char, "Attacking", effectiveHitDelay + 0.1)
		
		------------------------------------------------
		-- 3️⃣ Create REAL server hitbox
		------------------------------------------------

		local size = data.Size
		local states = {
			["HitStun"] = 0.8,
			["Slow"] = 0.8
		}
		
		if lastHit then
			states["Ragdoll"] = 1.25
			stateManager:AddState(char, "Slow", 1, 10)
		end
		
		if lastHit and char:FindFirstChild("Passives"):FindFirstChild("Powerful Blow") then
			local fx = game.ReplicatedStorage.VFX["Powerful Blow"]["Powerful Blow"]:Clone(); Debris:AddItem(fx, 1)
			fx.Parent = char:FindFirstChild("Right Arm")
			for _, v in fx:GetChildren() do
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		
		stateManager:AddCooldown(char, "Dash", 0.5)

		task.wait(effectiveHitDelay)
		
		Manager.AdjustCombatExp(player, 5)
		
		------------------------------------------------
		-- Second stun check for hitter
		------------------------------------------------
		if stateManager:CheckStun(char) == true 
			and not char:FindFirstChild("Passives"):FindFirstChild("Bastion") 
			and not lastHit 
			and not cancel then 
			return
		end
		
		local cframe = root.CFrame * CFrame.new(0,0,-size.Z/2)
		
		local hitboxParams = {
			SizeOrPart = data.Size,
			Debug = false,
			Debris = 0.1,
			Blacklist = {char},
			UseClient = player,
			DotProductRequirement = 0
		} :: HitboxType.HitboxParams

		local hitbox, connected = HitboxClass.new(hitboxParams)
		hitbox:WeldTo(root,CFrame.new(0,0,-size.Z/2))
		
		hitbox.HitSomeone:Connect(function(hit)
			if stateManager:CheckStun(char) 
				and not char:FindFirstChild("Passives"):FindFirstChild("Bastion") and not lastHit then return end
			
			Manager.AdjustCombatExp(player, 4)
			hitHandler(hit, player, data, states)
			hitbox:Destroy()
		end)
		
		hitbox:Start()

	elseif attackType == "DashAttack" then 
		
		if stateManager:CheckCooldown(char, "RunningAttack") then return end
		stateManager:AddCooldown(char, "RunningAttack", 5)
		stateManager:AddState(char, "Attacking", 0.6)
		stateManager:AddCooldown(char, "Skill", 1)
		stateManager:RemoveState(char, "Sprinting")
		
		data.LastM1 = now
		
		dashEvent:FireClient(player, player, "Front", 0.5, 60)
		
		task.wait(0.1)
		
		Manager.AdjustCombatExp(player, 1)
		
		stateManager:AddState(char, "Slow", 0.9, 10)
		stateManager:AddCooldown(char, "M1", data.Endlag + data.HitDelay)
		
		if cancel then return end
		------------------------------------------------
		-- Server hitbox + effects
		------------------------------------------------
		
		local states = {
			["HitStun"] = 1,
			["Slow"] = 1.5
		}
		
		local hitboxParams = {
			SizeOrPart = Vector3.new(5,5,6),
			Debug = false,
			Debris = 0.55,
			Blacklist = {char},
			VelocityPrediction = true,
			UseClient = player
		} :: HitboxType.HitboxParams

		local hitbox, connected = HitboxClass.new(hitboxParams)
		hitbox:WeldTo(root, CFrame.new(0,0,-3.5))
		
		hitbox.HitSomeone:Connect(function(hit)
			if stateManager:CheckStun(char) then return end
			
			AttackRemote:FireClient(player, "DashLanded")
			killMomentum:FireClient(player, char)
			
			stateManager:AddState(char, "Slow", 0.3, 8)
			stateManager:AddCooldown(char, "M1", data.Endlag)
			
			hitHandler(hit, player, data, states)
			hitbox:Destroy()
			Manager.AdjustCombatExp(player, 4)
		end)
		
		task.delay(0.25, function()
			hitbox:Start()
		end)
	end
end)

bindable.Event:Connect(function(player, config)
	
	if config == nil and playerCombatData[player] then
		warn("No config, updating based on stats")
		local data = playerCombatData[player]
		local statData = Manager.GetData(player)
		if not statData then warn("No stat data") return end

		data.Damage = StatConfig.GetDmgMult(data.BaseValues.Damage, statData.Stats)
		data.Endlag = StatConfig.GetSwingSpeedMult(data.BaseValues.EndLag, statData.Stats)
		data.HitDelay = StatConfig.GetSwingSpeedMult(data.BaseValues.HitDelay, statData.Stats)
		data.CritChance = StatConfig.GetCritChance(statData.Stats)
		print(data.Damage)
		return
	end
	
	if config == nil and not playerCombatData[player] then return end
	
	local lastCombo = 1
	local lastM1 = 0

	if playerCombatData[player] then
		local old = playerCombatData[player]

		if tick() - old.LastM1 <= RESET_TIME then
			lastCombo = old.Combo
			lastM1 = old.LastM1
		end
	end

	playerCombatData[player] = {
		LastM1 = lastM1,
		Combo = lastCombo,
		Size = config.Size,
		Damage = config.Damage,
		Endlag = config.EndLag,
		HitDelay = config.HitDelay,
		MaxCombo = config.MaxCombo,
		CritChance = CRIT_CHANCE,
		DamageType = config.Type,
		BaseValues = config
	}
	
	local data = playerCombatData[player]
	local statData = Manager.GetData(player)
	if not statData then warn("No stat data") return end

	data.Damage = StatConfig.GetDmgMult(config.Damage, statData.Stats)
	data.Endlag = StatConfig.GetSwingSpeedMult(config.EndLag, statData.Stats)
	data.CritChance = StatConfig.GetCritChance(statData.Stats)

	print("Endlag: ", data.Endlag)
	print("Crit Chance: ", data.CritChance)
	print("Config received")
end)

