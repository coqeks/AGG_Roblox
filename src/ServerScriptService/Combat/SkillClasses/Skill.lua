-- Base class for server skill logic. Each ServerStorage.MovesetLogic.<Skill Name> module is a
-- subclass made with Skill.extend(name, config) that overrides Run (and optionally CanUse / OnHit).
--
-- SkillService2 (players) and Entities.Entity (PvE) call Class:CanUse(caster, target) before spending
-- the cooldown, then Class:Cast(caster, target), which makes one instance per use (a "cast") and calls
-- :Run(). The caster is a Player or an entity's character Model; self.Player is nil for entities.
-- A cast holds the caster, target and cancel state, and provides the shared section pipeline:
-- timed sections, hitboxes welded to the caster (client-detected for players, server-detected for
-- entities), damage, knockback and finishers.
--
-- Section fields (in Config.Sections or any table passed to SpawnHitbox / ApplyHit):
--   Damage, DamageType ("Slash" by default), States, BlockBreak (also ignores block), Crittable,
--   HitRagdoll, Knockback, Finisher, Size, Offset, Lifetime, DT (hit debounce), Delay, Debug,
--   SelfStateOnHit = { [state] = duration } (applied to the caster whenever the hitbox hits)

local damageManager = require(game.ServerScriptService.Combat.DamageManager)
local stateManager  = require(game.ServerScriptService.PlayerStates.StateManager)
local HitboxClass   = require(game.ReplicatedStorage.Combat.HitboxClass)
local HitboxType    = require(game.ReplicatedStorage.Combat.HitboxClass.Types)

local Knockback     = require(game.ServerScriptService.Combat.Knockback)
local skillReplicator = game.ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("SkillReplicator")

local Skill = {}
Skill.__index = Skill

-- ─── Class level ─────────────────────────────────────────────────────────────

-- Makes a skill class. `name` must match the client Movesets module (it's sent with SkillReplicator).
function Skill.extend(name, config)
	local class = setmetatable({}, Skill)
	class.__index = class
	class.Name = name
	class.Config = config
	return class
end

-- The character behind a caster: a Player's Character, or the Model itself for an entity
function Skill.CharacterOf(caster)
	if typeof(caster) ~= "Instance" then return nil end
	if caster:IsA("Player") then
		return caster.Character
	end
	return caster
end

-- Override for preconditions checked before the cooldown is spent. Returns ok, reason.
function Skill:CanUse(caster, target)
	return true
end

-- Entry point: makes a cast of this class and runs it
function Skill:Cast(caster, target)
	local cast = Skill.new(self, caster, target)
	if cast then
		cast:Run()
	end
	return cast
end

-- A cast of `class` by `caster` (a Player or an entity Model), or nil if there's no character
function Skill.new(class, caster, target)
	local char = Skill.CharacterOf(caster)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local self = setmetatable({}, class)
	self.Player = caster:IsA("Player") and caster or nil -- nil for entities
	self.Attacker = self.Player or char                  -- who DamageManager credits
	self.Character = char
	self.Root = root
	self.Target = target
	self.Cancelled = false
	return self
end

-- ─── Cast lifecycle (override Run) ───────────────────────────────────────────

function Skill:Run()
	error(self.Name .. " doesn't implement Run")
end

-- Tells clients to play `variant`, applies UsingSkill (Config.Duration unless given) and the caster's
-- self states (Config.SelfState unless given), and starts listening for a stun cancel.
function Skill:Begin(variant, payload, duration, selfStates)
	self:Replicate(variant, payload)
	stateManager:AddState(self.Character, "UsingSkill", duration or self.Config.Duration)
	for state, stateDuration in selfStates or self.Config.SelfState or {} do
		stateManager:AddState(self.Character, state, stateDuration)
	end
	self:ListenForCancel()
end

-- Stuns add CancelSkill (StateResolverServer), which cancels the sections that haven't started yet.
-- Skills with Config.HyperArmor ignore it.
function Skill:ListenForCancel()
	if self._listening or self.Config.HyperArmor then return end
	self._listening = true
	self.Character:GetAttributeChangedSignal("CancelSkill"):Once(function()
		self.Cancelled = true
	end)
end

function Skill:IsActive()
	return not self.Cancelled and self.Character.Parent ~= nil
end

-- Runs `fn` after `delay` seconds unless the cast was cancelled or the caster is gone
function Skill:After(delay, fn)
	task.delay(delay, function()
		if self:IsActive() then
			fn()
		end
	end)
end

-- SkillReplicator:FireAllClients(char, skillName, variant, payload)
function Skill:Replicate(variant, payload)
	skillReplicator:FireAllClients(self.Character, self.Name, variant, payload)
end

-- ─── Sections, hitboxes and hits ─────────────────────────────────────────────

-- Spawns a hitbox for each section (Config.Sections unless given) at its Delay
function Skill:RunSections(sections)
	for _, section in sections or self.Config.Sections do
		self:After(section.Delay, function()
			self:SpawnHitbox(section)
		end)
	end
end

function Skill:BuildDamageParams(section)
	local crittable = section.Crittable or false
	local passives = self.Character:FindFirstChild("Passives")
	if passives and passives:FindFirstChild("Enlightened") then
		crittable = true
	end
	return {
		Damage      = section.Damage,
		DamageType  = section.DamageType or "Slash",
		States      = section.States,
		BlockBreak  = section.BlockBreak,
		IgnoreBlock = section.BlockBreak,
		Crittable   = crittable,
		HitRagdoll  = section.HitRagdoll or false,
	}
end

-- A hitbox welded to the caster's HumanoidRootPart for one section: detected by the caster's client
-- for players, by the server for entities. Hits are ignored while the caster is stunned.
function Skill:SpawnHitbox(section)
	local char = self.Character
	local hitbox = HitboxClass.new({
		SizeOrPart         = section.Size,
		Blacklist          = { char },
		Debris             = section.Lifetime,
		Debug              = section.Debug or false,
		UseClient          = self.Player, -- nil for entities = server-side detection
		DebounceTime       = section.DT,
		VelocityPrediction = true,
	} :: HitboxType.HitboxParams)
	hitbox:WeldTo(self.Root, section.Offset)

	local damageParams = self:BuildDamageParams(section)

	-- Defer so the weld resolves before the hitbox begins ticking
	task.defer(function()
		hitbox:Start()
		hitbox.HitSomeone:Connect(function(hitList)
			if stateManager:CheckStun(char) then return end

			if section.SelfStateOnHit then
				for state, duration in section.SelfStateOnHit do
					stateManager:AddState(char, state, duration)
				end
			end
			for _, hit in hitList do
				self:ApplyHit(hit, section, damageParams)
			end
		end)
	end)
	return hitbox
end

-- Damage, knockback (along `direction`, default the caster's look direction), the OnHit hook,
-- then the finisher if the hit killed. Returns landed, killed.
function Skill:ApplyHit(target, section, damageParams, direction)
	-- Entities don't hurt each other
	if not self.Player and target:HasTag("Entity") then
		return false, false
	end

	local landed, killed = damageManager:TakeDamage(target, self.Attacker, damageParams or self:BuildDamageParams(section))

	if section.Knockback then
		Knockback.Apply(target, direction or self.Root.CFrame.LookVector, section.Knockback, 0.1)
	end

	self:OnHit(target, section, landed, killed)

	if landed and killed and section.Finisher then
		stateManager:AddState(target, "Cooked", nil)
		self:Replicate("Finisher", target)
	end
	return landed, killed
end

-- Override to react to each hit (landed = not blocked/dodged)
function Skill:OnHit(target, section, landed, killed)
end

return Skill
