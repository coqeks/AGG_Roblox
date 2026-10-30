-- One PvE entity: its character model plus everything it can physically do (move, jump, dash, M1,
-- block, use skills). It makes no decisions; a Brain (Entities.Brain) drives it.
--
-- Entities live in workspace.Alive with the tag "Entity", so the state system, DamageManager,
-- hitboxes and skill classes treat them like any other character. The server owns their physics,
-- so dashes and knockback on them are simulated here instead of on a client.
--
--   local entity = Entity.new("Bandit", EntityConfigs.Bandit, spawnCFrame)
--   entity:Attack()  entity:Block(0.8)  entity:Dash("Back")  entity:UseSkill("Cross Slash", target)
--   entity.Died:Connect(function(killerPlayer) ... end)

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local stateManager  = require(game.ServerScriptService.PlayerStates.StateManager)
local damageManager = require(game.ServerScriptService.Combat.DamageManager)
local dataManager   = require(game.ServerScriptService.PlayerData.Manager)
local weaponConfig  = require(game.ServerScriptService.Config.WeaponConfig)
local Knockback     = require(game.ServerScriptService.Combat.Knockback)
local HitboxClass   = require(game.ReplicatedStorage.Combat.HitboxClass)
local HitboxType    = require(game.ReplicatedStorage.Combat.HitboxClass.Types)
local Signal        = require(game.ReplicatedStorage.Combat.HitboxClass.Signal)
local DashCurve     = require(game.ReplicatedStorage.Modules.DashCurve)
local skillLoader   = require(ServerStorage.MovesetLogic.Loader)

local dashEffect       = game.ReplicatedStorage.RemoteEvents.Effects.Dash
local combatAnimations = game.ReplicatedStorage.Animations.Combat
local dashAnimations   = game.StarterPlayer.StarterCharacterScripts.Movement.DashClient
local entityModels     = ServerStorage.Entities.Models

-- Same animations as the player Animate script
local MOVEMENT_ANIMATIONS = {
	Idle = "rbxassetid://180435571",
	Walk = "rbxassetid://180426354",
	Run  = "rbxassetid://108326784918330",
	Jump = "rbxassetid://125750702",
	Fall = "rbxassetid://180436148",
}
local DASH_ANIMATIONS = { Front = "ForwardDash", Back = "BackwardDash", Left = "LeftDash", Right = "RightDash" }

-- Same numbers as players (CombatValidation, DashServer)
local COMBO_RESET = 3
local DASH_TIME = DashCurve.TIME
local DASH_CD = DashCurve.COOLDOWN
-- DamageManager leaves dead NPCs at 0.1 HP (stored as a float, so it reads back as 0.1000000015)
local DEAD_HEALTH = 0.15

local Entity = {}
Entity.__index = Entity

function Entity.new(typeName, config, spawnCFrame)
	local template = entityModels:FindFirstChild(config.Model)
	assert(template, "No entity model ServerStorage.Entities.Models." .. tostring(config.Model))

	local model = template:Clone()
	model.Name = config.DisplayName or typeName

	local self = setmetatable({}, Entity)
	self.Type = typeName
	self.Config = config
	self.Model = model
	self.Humanoid = model:FindFirstChildOfClass("Humanoid")
	self.Root = model:FindFirstChild("HumanoidRootPart")
	self.Animator = self.Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", self.Humanoid)
	self.SpawnCFrame = spawnCFrame
	self.Weapon = config.Weapon and weaponConfig.Preset(config.Weapon)
	self.Combo = 1
	self.LastAttack = 0
	self.Dead = false
	self.Died = Signal.new() -- (killer: Player?)

	self._tracks = {}
	self._connections = {}

	local humanoid = self.Humanoid
	humanoid.MaxHealth = config.Health
	humanoid.Health = config.Health
	humanoid.WalkSpeed = config.WalkSpeed
	humanoid.UseJumpPower = false
	humanoid.BreakJointsOnDeath = false

	-- Read by StateResolverServer (speed), DamageManager (crits) and the Brain/other systems
	model:AddTag("Entity")
	model:SetAttribute("EntityType", typeName)
	model:SetAttribute("BaseWalkSpeed", config.WalkSpeed)
	model:SetAttribute("CritChance", config.CritChance or 5)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Player"
		end
	end

	-- Turns the entity toward its target while fighting (see FaceTowards)
	self._align = Instance.new("AlignOrientation")
	self._align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	self._align.Attachment0 = self.Root:FindFirstChild("RootAttachment")
	self._align.Responsiveness = 30
	self._align.MaxTorque = math.huge
	self._align.Enabled = false
	self._align.Parent = self.Root

	model:PivotTo(spawnCFrame)
	model.Parent = workspace.Alive
	self:ClaimPhysics()

	-- StateResolverServer sets up states/Cooldowns when the model enters workspace.Alive
	model:WaitForChild("Cooldowns", 5)

	self:_attachWeapon("Torso", "Strap")
	self:_hookAnimations()
	self:_hookDeath()
	return self
end

-- ─── Status ──────────────────────────────────────────────────────────────────

function Entity:IsAlive()
	return not self.Dead and self.Model.Parent ~= nil
end

-- Stunned, mid-skill or mid-dash: can't start another action
function Entity:IsBusy()
	local model = self.Model
	return stateManager:CheckStun(model) == true
		or stateManager:HasState(model, "UsingSkill") == true
		or stateManager:HasState(model, "Dashing") == true
end

function Entity:IsStunned()
	return stateManager:CheckStun(self.Model) == true
end

function Entity:IsBlocking()
	return stateManager:HasState(self.Model, "Blocking") == true
end

function Entity:Heal()
	self.Humanoid.Health = self.Humanoid.MaxHealth
end

-- The player who hit this entity most recently (from DamageManager's damage cache), if any
function Entity:GetLastAttacker()
	local latest, latestToken
	for attacker, data in damageManager.CachedDamage[self.Model] or {} do
		if typeof(attacker) == "Instance" and attacker:IsA("Player") and attacker.Parent
			and (not latestToken or (data.Token or 0) > latestToken) then
			latest, latestToken = attacker, data.Token or 0
		end
	end
	return latest
end

-- The player who dealt the most damage (kill credit), if any
function Entity:GetTopDamager()
	local top, topDamage = nil, 0
	for attacker, data in damageManager.CachedDamage[self.Model] or {} do
		if typeof(attacker) == "Instance" and attacker:IsA("Player") and attacker.Parent
			and (data.Damage or 0) > topDamage then
			top, topDamage = attacker, data.Damage
		end
	end
	return top
end

-- The server simulates entities (players' clients don't). Changing the assembly, e.g. welding a
-- weapon or ragdolling, resets ownership to automatic, so this is re-applied after those and each Brain tick.
function Entity:ClaimPhysics()
	local root = self.Root
	if root:IsDescendantOf(workspace) and root:CanSetNetworkOwnership() and root:GetNetworkOwner() ~= nil then
		root:SetNetworkOwner(nil)
	end
end

-- ─── Movement ────────────────────────────────────────────────────────────────

function Entity:MoveTo(position)
	self.Humanoid:MoveTo(position)
end

function Entity:StopMoving()
	self.Humanoid:MoveTo(self.Root.Position)
end

function Entity:SetSprinting(sprinting)
	local isSprinting = stateManager:HasState(self.Model, "Sprinting") == true
	if sprinting and not isSprinting then
		stateManager:AddState(self.Model, "Sprinting")
	elseif not sprinting and isSprinting then
		stateManager:RemoveState(self.Model, "Sprinting")
	end
end

-- Keeps the entity turned toward `position` (yaw only). nil hands turning back to the Humanoid.
function Entity:FaceTowards(position)
	if not position then
		self._align.Enabled = false
		self.Humanoid.AutoRotate = true
		return
	end
	local flat = position - self.Root.Position
	flat = Vector3.new(flat.X, 0, flat.Z)
	if flat.Magnitude < 0.1 then return end
	self._align.CFrame = CFrame.lookAt(Vector3.zero, flat)
	self._align.Enabled = true
	self.Humanoid.AutoRotate = false
end

-- True if the entity's facing is within `maxAngle` degrees of `position`
function Entity:IsFacing(position, maxAngle)
	local flat = position - self.Root.Position
	flat = Vector3.new(flat.X, 0, flat.Z)
	if flat.Magnitude < 0.1 then return true end
	local look = self.Root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z).Unit
	return look:Dot(flat.Unit) >= math.cos(math.rad(maxAngle))
end

function Entity:Jump()
	local model, humanoid = self.Model, self.Humanoid
	if not self:IsAlive() or self:IsStunned() or self:IsBlocking()
		or stateManager:HasState(model, "JumpLock") == true
		or humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end
	humanoid.Jump = true
	return true
end

function Entity:CanDash()
	local model = self.Model
	return self:IsAlive() and not self:IsBusy() and not self:IsBlocking()
		and not stateManager:CheckCooldown(model, "Dash")
		and stateManager:HasState(model, "Slow") ~= true
end

-- direction: "Front" | "Back" | "Left" | "Right" (relative to where the entity faces)
function Entity:Dash(direction)
	if not self:CanDash() then return false end
	local model, root = self.Model, self.Root

	stateManager:AddCooldown(model, "Dash", DASH_CD)
	stateManager:AddState(model, "Dashing", DASH_TIME - 0.25)
	stateManager:AddState(model, "JumpLock", DASH_TIME)
	stateManager:AddState(model, "IFrame", 0.1)

	local power = DashCurve.Power(direction, stateManager:HasState(model, "Amputate_Leg") == true)

	local animation = dashAnimations:FindFirstChild(DASH_ANIMATIONS[direction])
	if animation then
		self:PlayAnimation(animation, nil, nil, 1.2)
	end
	dashEffect:FireAllClients(model, direction)

	-- Same velocity curve as player dashes (ReplicatedStorage.Modules.DashCurve)
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "DashVelocity"
	velocity.Attachment0 = root:FindFirstChild("RootAttachment")
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = Vector3.new(math.huge, 0, math.huge)
	velocity.Parent = root

	local start = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local alpha = (os.clock() - start) / DASH_TIME
		if alpha >= 1 or not velocity.Parent then
			connection:Disconnect()
			velocity:Destroy()
			return
		end
		local cf = root.CFrame
		local dashDirection = ({
			Front = cf.LookVector, Back = -cf.LookVector,
			Right = cf.RightVector, Left = -cf.RightVector,
		})[direction] or cf.LookVector

		velocity.VectorVelocity = dashDirection * DashCurve.Speed(alpha, power, self.Humanoid.WalkSpeed)
	end)
	return true
end

-- ─── Weapon and M1 ───────────────────────────────────────────────────────────

function Entity:_attachWeapon(partName, jointName)
	local weaponModel = self.Config.Weapon and ServerStorage.WeaponModels:FindFirstChild(self.Config.Weapon)
	local part = self.Model:FindFirstChild(partName)
	if not weaponModel or not part or not weaponModel:FindFirstChild(jointName) then return end

	if self._handle then self._handle:Destroy() end
	if self._grip then self._grip:Destroy() end

	local handle = weaponModel:Clone()
	handle.Anchored = false
	handle.Name = "Handle"
	handle.Parent = self.Model

	local grip = Instance.new("Motor6D")
	grip.Name = "Grip"
	grip.Part0 = part
	grip.Part1 = handle
	grip.C0 = handle[jointName].C0
	grip.C1 = handle[jointName].C1
	grip.Parent = part

	self._handle, self._grip = handle, grip
	self:ClaimPhysics()
end

function Entity:IsWeaponEquipped()
	return self.Model:GetAttribute("WeaponEquipped") ~= nil and self.Model:GetAttribute("WeaponEquipped") ~= false
end

-- Weapon in hand (sets WeaponEquipped like a player's equip, which BlockService/effects read)
function Entity:EquipWeapon()
	if not self.Weapon or self:IsWeaponEquipped() then return end
	stateManager:AddState(self.Model, "WeaponEquipped", nil, self.Config.Weapon)
	self:_attachWeapon("Right Arm", "Grip")
end

function Entity:UnequipWeapon()
	if not self:IsWeaponEquipped() then return end
	stateManager:RemoveState(self.Model, "WeaponEquipped")
	self:_attachWeapon("Torso", "Strap")
end

function Entity:CanAttack()
	local model = self.Model
	return self.Weapon ~= nil and self:IsAlive() and not self:IsBusy() and not self:IsBlocking()
		and not stateManager:CheckCooldown(model, "M1")
end

-- One M1 of the weapon's combo, with the same timing, states and knockback as a player's
-- (CombatValidation). Hits are detected on the server.
function Entity:Attack()
	if not self:CanAttack() then return false end
	local model, weapon = self.Model, self.Weapon

	local now = os.clock()
	if now - self.LastAttack > COMBO_RESET then
		self.Combo = 1
	end
	self.LastAttack = now

	local hitNumber = self.Combo
	local lastHit = hitNumber >= weapon.MaxCombo
	self.Combo = lastHit and 1 or hitNumber + 1

	local endlag, hitDelay = weapon.EndLag, weapon.HitDelay
	stateManager:AddCooldown(model, "M1", lastHit and 1.25 + endlag or endlag + hitDelay)
	stateManager:AddCooldown(model, "Block", endlag + hitDelay + 0.25)
	stateManager:AddCooldown(model, "Skill", endlag + hitDelay)
	stateManager:AddCooldown(model, "Dash", 0.5)
	stateManager:RemoveState(model, "Sprinting")
	stateManager:AddState(model, "Slow", 0.5, 2)
	stateManager:AddState(model, "JumpLock", 0.7)
	stateManager:AddState(model, "Attacking", hitDelay + 0.1)
	if lastHit then
		stateManager:AddState(model, "Slow", 1, 10)
	end

	local classAnimations = combatAnimations:FindFirstChild(weapon.WeaponClass)
	local animation = classAnimations and classAnimations:FindFirstChild(tostring(hitNumber))
	if animation then
		self:PlayAnimation(animation)
	end
	self:_flashWeaponTrails()

	task.delay(hitDelay, function()
		if not self:IsAlive() or (self:IsStunned() and not lastHit) then return end
		self:_swing(lastHit)
	end)
	return true
end

function Entity:_swing(lastHit)
	local model, weapon = self.Model, self.Weapon
	local states = { HitStun = 0.8, Slow = 0.8 }
	if lastHit then
		states.Ragdoll = 1.25
	end

	local hitbox = HitboxClass.new({
		SizeOrPart = weapon.Size,
		Debug = false,
		Debris = 0.1,
		Blacklist = { model },
		DotProductRequirement = 0,
	} :: HitboxType.HitboxParams)
	hitbox:WeldTo(self.Root, CFrame.new(0, 0, -weapon.Size.Z / 2))

	hitbox.HitSomeone:Connect(function(hitList)
		if self:IsStunned() and not lastHit then return end
		for _, target in hitList do
			if target:HasTag("Entity") then continue end
			local landed = damageManager:TakeDamage(target, model, {
				Damage = weapon.Damage * (self.Config.DamageMultiplier or 1),
				DamageType = weapon.Type,
				States = states,
				IgnoreBlock = false,
				BlockBreak = false,
				Crittable = true,
				HitRagdoll = false,
			})
			local targetRoot = target:FindFirstChild("HumanoidRootPart")
			if landed and targetRoot then
				local direction = (targetRoot.Position - self.Root.Position).Unit
				if lastHit then
					Knockback.Apply(target, self.Root.CFrame.LookVector, 50, 0.05)
				else
					Knockback.Apply(target, direction, 15, 0.1)
				end
				Knockback.Apply(model, direction, 13, 0.1)
			end
		end
		hitbox:Destroy()
	end)
	hitbox:Start()
end

function Entity:_flashWeaponTrails()
	if not self._handle then return end
	for _, effect in self._handle:GetDescendants() do
		if effect:IsA("Trail") or effect:IsA("ParticleEmitter") then
			task.delay(0.3, function()
				effect.Enabled = true
				task.delay(0.2, function()
					effect.Enabled = false
				end)
			end)
		end
	end
end

-- ─── Block ───────────────────────────────────────────────────────────────────

function Entity:CanBlock()
	local model = self.Model
	return self:IsAlive() and not self:IsBusy() and not self:IsBlocking()
		and not stateManager:CheckCooldown(model, "Block")
end

-- Blocks for `duration` seconds (or until StopBlocking). The first 0.2s is a perfect block, like players.
function Entity:Block(duration)
	if not self:CanBlock() then return false end
	stateManager:AddState(self.Model, "Blocking")
	stateManager:AddState(self.Model, "PBFrame", 0.2)

	local token = {}
	self._blockToken = token
	task.delay(duration, function()
		if self._blockToken == token then
			self:StopBlocking()
		end
	end)
	return true
end

function Entity:StopBlocking()
	self._blockToken = nil
	if self:IsBlocking() then
		stateManager:RemoveState(self.Model, "Blocking")
		stateManager:AddCooldown(self.Model, "Block", 0.2)
	end
end

-- ─── Skills ──────────────────────────────────────────────────────────────────

function Entity:SkillReady(name)
	local model = self.Model
	return skillLoader[name] ~= nil
		and not stateManager:CheckCooldown(model, name)
		and not stateManager:CheckCooldown(model, "Skill")
end

-- Casts a MovesetLogic skill (the same skill classes players use). Returns true if it was cast.
function Entity:UseSkill(name, target)
	local skill = skillLoader[name]
	if not skill or not self:IsAlive() or self:IsBusy() or self:IsBlocking() or not self:SkillReady(name) then
		return false
	end
	if skill.Config.RequireTarget and not target then return false end
	if not skill:CanUse(self.Model, target) then return false end

	stateManager:AddCooldown(self.Model, name, skill.Config.CD)
	stateManager:RemoveState(self.Model, "Sprinting")
	skill:Cast(self.Model, target)
	return true
end

-- ─── Animation ───────────────────────────────────────────────────────────────

-- `animation` is an Animation instance or an asset id string; tracks are cached
function Entity:LoadAnimation(animation)
	local id = typeof(animation) == "string" and animation or animation.AnimationId
	local track = self._tracks[id]
	if not track then
		local source = animation
		if typeof(animation) == "string" then
			source = Instance.new("Animation")
			source.AnimationId = animation
		end
		track = self.Animator:LoadAnimation(source)
		self._tracks[id] = track
	end
	return track
end

function Entity:PlayAnimation(animation, fadeTime, weight, speed)
	local track = self:LoadAnimation(animation)
	track:Play(fadeTime, weight, speed)
	return track
end

-- Idle/walk/run/jump/fall from the Humanoid, and the block pose from the Blocking state
function Entity:_hookAnimations()
	local humanoid, model = self.Humanoid, self.Model
	local tracks = {}
	for name, id in MOVEMENT_ANIMATIONS do
		tracks[name] = self:LoadAnimation(id)
	end
	for _, name in { "Idle", "Walk", "Run", "Fall" } do
		tracks[name].Looped = true
	end
	tracks.Idle.Priority = Enum.AnimationPriority.Idle
	tracks.Walk.Priority = Enum.AnimationPriority.Movement
	tracks.Run.Priority = Enum.AnimationPriority.Movement

	local current
	local function setMovementTrack(track, speed)
		if current ~= track then
			if current then current:Stop(0.2) end
			current = track
			track:Play(0.2)
		end
		if speed then
			track:AdjustSpeed(speed)
		end
	end

	local lastSpeed = 0
	local function updateMovement()
		if lastSpeed > 0.5 then
			if model:GetAttribute("Sprinting") == true then
				setMovementTrack(tracks.Run, 1)
			else
				setMovementTrack(tracks.Walk, lastSpeed / 14)
			end
		else
			setMovementTrack(tracks.Idle, 1)
		end
	end

	table.insert(self._connections, humanoid.Running:Connect(function(speed)
		lastSpeed = speed
		updateMovement()
	end))
	table.insert(self._connections, model:GetAttributeChangedSignal("Sprinting"):Connect(updateMovement))
	table.insert(self._connections, humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			tracks.Jump:Play(0.1)
		elseif new == Enum.HumanoidStateType.Freefall then
			tracks.Fall:Play(0.2)
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			tracks.Fall:Stop(0.2)
		end
	end))

	table.insert(self._connections, model:GetAttributeChangedSignal("Blocking"):Connect(function()
		local classAnimations = self.Weapon and combatAnimations:FindFirstChild(self.Weapon.WeaponClass)
		local blockAnimation = classAnimations and classAnimations:FindFirstChild("Blocking")
		if not blockAnimation then return end
		local track = self:LoadAnimation(blockAnimation)
		if model:GetAttribute("Blocking") == true then
			track.Looped = true
			track:Play(0.1)
		else
			track:Stop(0.1)
		end
	end))

	updateMovement()
end

-- ─── Death and cleanup ───────────────────────────────────────────────────────

-- DamageManager doesn't kill NPCs outright: it sets the Dead state and leaves 0.1 HP
function Entity:_hookDeath()
	local humanoid = self.Humanoid
	local function check()
		if humanoid.Health <= DEAD_HEALTH or humanoid:GetState() == Enum.HumanoidStateType.Dead then
			self:_die(true)
		end
	end
	table.insert(self._connections, humanoid.HealthChanged:Connect(check))
	table.insert(self._connections, humanoid.Died:Connect(check))
	-- Fell out of the map or was removed: dies without rewards
	table.insert(self._connections, self.Model.AncestryChanged:Connect(function()
		if not self.Model:IsDescendantOf(workspace) then
			self:_die(false)
		end
	end))
end

function Entity:_die(giveRewards)
	if self.Dead then return end
	self.Dead = true
	self:FaceTowards(nil)
	self:StopBlocking()

	local killer = giveRewards and self:GetTopDamager()
	if killer then
		self:_reward(killer)
	end
	self.Died:Fire(killer)
end

function Entity:_reward(player)
	local rewards = self.Config.Rewards or {}
	if rewards.Exp then
		dataManager.AdjustCombatExp(player, rewards.Exp)
	end
	if rewards.Gold then
		dataManager.AdjustGold(player, rewards.Gold)
	end
	local data = dataManager.GetData(player)
	if data then
		data.BeastKills = (data.BeastKills or 0) + 1
	end
end

function Entity:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
	damageManager.CachedDamage[self.Model] = nil
	stateManager:RemoveCharacter(self.Model)
	self.Died:DisconnectAll()
	self.Model:Destroy()
end

return Entity
