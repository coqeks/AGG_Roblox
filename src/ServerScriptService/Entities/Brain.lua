-- The AI that drives one Entity. Three states:
--   Idle   : wanders around its spawn and scans its Vision box. A player in view, or a player
--            hitting it, makes it aggressive (Chase).
--   Chase  : runs at the target (sprinting when far, dashing in to close gaps, jumping obstacles),
--            M1s in range, uses its skills, and blocks or dashes away when the target attacks.
--   Return : the target died, escaped its sight for LoseSightTime, or it was pulled past LeashRange:
--            walks home, heals to full and goes back to Idle. Getting hit on the way re-aggroes it.
--
-- Subclass it for a different temperament (override Decide*, React or TrySkill):
--   local Coward = setmetatable({}, { __index = Brain }); Coward.__index = Coward

local Vision    = require(game.ServerScriptService.Entities.Vision)
local Navigator = require(game.ServerScriptService.Entities.Navigator)

-- Reach and minimum distance per skill, for picking which skill fits the fight.
-- An entity config can override these: Skills = { { Name = "Cross Slash", Range = 10 } }
local SKILL_RANGES = {
	["Rapid Pierce"]      = { Range = 9 },
	["Cross Slash"]       = { Range = 8 },
	["Lightspeed Strike"] = { Range = 38, MinRange = 8 },
	["War Cry"]           = { Range = 25 },
	["Dagger Throw"]      = { Range = 45, MinRange = 6 },
	["Shade Step"]        = { Range = 60 },
}

local DODGE_DIRECTIONS = { "Back", "Left", "Right" }
local DEFENSE_WINDOW = 0.8 -- seconds a chosen block/dodge keeps being attempted

local Brain = {}
Brain.__index = Brain

Brain.TICK = 0.1

-- `perSecond` chance, rolled once per tick
local function rollPerSecond(perSecond)
	return math.random() < perSecond * Brain.TICK
end

local function flatDistance(a, b)
	local offset = a - b
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

function Brain.new(entity)
	local self = setmetatable({}, Brain)
	local config = entity.Config
	self.Entity = entity
	self.Config = config
	self.Behaviour = config.Behaviour or {}
	self.Vision = Vision.new(entity, config.Vision or {})
	self.Navigator = Navigator.new(entity)

	self.State = "Idle"
	self.Target = nil
	self.LastSeen = 0
	self.Skills = {}
	for _, skill in config.Skills or {} do
		local name = typeof(skill) == "table" and skill.Name or skill
		local defaults = SKILL_RANGES[name] or { Range = 10 }
		table.insert(self.Skills, {
			Name = name,
			Range = typeof(skill) == "table" and skill.Range or defaults.Range,
			MinRange = typeof(skill) == "table" and skill.MinRange or defaults.MinRange or 0,
		})
	end

	self._running = false
	self._nextScan = 0
	self._nextWander = os.clock() + math.random(2, 5)
	self._nextSkillThought = 0
	self._reactedToAttack = false
	self._returnStarted = 0

	-- Getting hit makes it aggressive toward whoever hit it, even from behind
	local lastHealth = entity.Humanoid.Health
	self._healthConnection = entity.Humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth then
			self:OnDamaged()
		end
		lastHealth = health
	end)
	return self
end

function Brain:Start()
	if self._running then return end
	self:SetState(self.State)
	self._running = true
	task.spawn(function()
		while self._running and self.Entity:IsAlive() do
			local ok, err = pcall(self.Step, self)
			if not ok then
				warn("[Brain] " .. self.Entity.Model.Name .. ": " .. tostring(err))
			end
			task.wait(Brain.TICK)
		end
	end)
end

function Brain:Stop()
	self._running = false
	if self._healthConnection then
		self._healthConnection:Disconnect()
	end
end

function Brain:Step()
	local entity = self.Entity
	entity:ClaimPhysics()
	if entity:IsStunned() then
		entity:FaceTowards(nil)
		return
	end

	if self.State == "Idle" then
		self:UpdateIdle()
	elseif self.State == "Chase" then
		self:UpdateChase()
	elseif self.State == "Return" then
		self:UpdateReturn()
	end
end

-- ─── Transitions ─────────────────────────────────────────────────────────────

-- The current state is mirrored to the model's AIState attribute (handy in the Properties panel)
function Brain:SetState(state)
	self.State = state
	self.Entity.Model:SetAttribute("AIState", state)
end

function Brain:Aggro(target)
	self.Target = target
	self:SetState("Chase")
	self.LastSeen = os.clock()
	self._reactedToAttack = false
	self._wanderGoal = nil
	self.Entity:EquipWeapon()
end

function Brain:GoHome()
	local entity = self.Entity
	self:SetState("Return")
	self.Target = nil
	self._returnStarted = os.clock()
	entity:FaceTowards(nil)
	entity:StopBlocking()
	entity:SetSprinting(true)
end

function Brain:OnDamaged()
	if self.State == "Chase" and Vision.IsTargetable(self.Target) then return end
	local attacker = self.Entity:GetLastAttacker()
	local char = attacker and attacker.Character
	if Vision.IsTargetable(char) then
		self:Aggro(char)
	end
end

-- ─── Idle ────────────────────────────────────────────────────────────────────

function Brain:UpdateIdle()
	local now = os.clock()
	if now >= self._nextScan then
		self._nextScan = now + 0.2
		local target = self.Vision:FindTarget()
		if target then
			self:Aggro(target)
			return
		end
	end

	local wanderRadius = self.Config.WanderRadius or 0
	if wanderRadius > 0 and now >= self._nextWander then
		self._nextWander = now + math.random(4, 8)
		local angle = math.random() * math.pi * 2
		local distance = math.random() * wanderRadius
		self._wanderGoal = self.Entity.SpawnCFrame.Position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	end

	if self._wanderGoal then
		if flatDistance(self.Entity.Root.Position, self._wanderGoal) < 2 then
			self._wanderGoal = nil
			self.Navigator:Stop()
		else
			self.Navigator:MoveTowards(self._wanderGoal)
		end
	end
end

-- ─── Chase / fight ───────────────────────────────────────────────────────────

function Brain:UpdateChase()
	local entity, config, target = self.Entity, self.Config, self.Target
	local now = os.clock()

	if not Vision.IsTargetable(target) then
		return self:GoHome()
	end
	if flatDistance(entity.Root.Position, entity.SpawnCFrame.Position) > (config.LeashRange or 120) then
		return self:GoHome()
	end

	local targetRoot = target.HumanoidRootPart
	local distance = (targetRoot.Position - entity.Root.Position).Magnitude
	if self.Vision:HasLineOfSight(target) then
		self.LastSeen = now
	elseif now - self.LastSeen > ((config.Vision and config.Vision.LoseSightTime) or 6) then
		return self:GoHome()
	end

	-- Face the target up close; the Humanoid turns it while running
	if distance < 15 then
		entity:FaceTowards(targetRoot.Position)
	else
		entity:FaceTowards(nil)
	end

	if self:React(target, distance) then return end
	if entity:IsBusy() or entity:IsBlocking() then return end
	if self:TrySkill(target, distance) then return end

	if distance > (config.AttackRange or 6) then
		self:DecideApproach(target, distance)
	else
		self:DecideMelee(target, distance)
	end
end

function Brain:DecideApproach(target, distance)
	local entity, behaviour = self.Entity, self.Behaviour
	local targetRoot = target.HumanoidRootPart

	entity:SetSprinting(distance > (self.Config.SprintDistance or 20))
	if distance > 14 and distance < 30 and rollPerSecond(behaviour.GapCloseChance or 0)
		and entity:IsFacing(targetRoot.Position, 25) then
		entity:Dash("Front")
	end
	if targetRoot.Position.Y - entity.Root.Position.Y > 4 then
		entity:Jump()
	end
	self.Navigator:MoveTowards(targetRoot.Position)
end

function Brain:DecideMelee(target, distance)
	local entity, behaviour = self.Entity, self.Behaviour
	entity:SetSprinting(false)
	self.Navigator:Stop()
	if entity:IsFacing(target.HumanoidRootPart.Position, 45) then
		entity:Attack()
	end
	if rollPerSecond(behaviour.JumpChance or 0) then
		entity:Jump()
	end
end

-- Blocks or dashes out when the target starts an attack in reach. Each attack is judged once; a
-- chosen defense is tried every tick from ReactionTime until it works or DEFENSE_WINDOW runs out
-- (the entity's own last M1 can still have Block/Dash on cooldown, as for a player). Returns true
-- while defending, so it doesn't start new attacks meanwhile.
function Brain:React(target, distance)
	local entity, behaviour = self.Entity, self.Behaviour
	local now = os.clock()
	local attacking = target:GetAttribute("Attacking") == true or target:GetAttribute("UsingSkill") == true

	if attacking and distance <= 14 then
		if not self._reactedToAttack then
			self._reactedToAttack = true
			local roll = math.random()
			local blockChance = behaviour.BlockChance or 0
			local dodgeChance = behaviour.DashChance or 0
			local readyAt = now + (behaviour.ReactionTime or 0.3) + math.random() * 0.15
			local kind = (roll < blockChance and "Block") or (roll < blockChance + dodgeChance and "Dash") or nil
			if kind then
				self._defense = { Kind = kind, ReadyAt = readyAt, Deadline = readyAt + DEFENSE_WINDOW }
			end
		end
	else
		self._reactedToAttack = false
	end

	local defense = self._defense
	if defense then
		if now > defense.Deadline then
			self._defense = nil
		elseif now >= defense.ReadyAt then
			local done
			if defense.Kind == "Block" then
				done = entity:Block(0.6 + math.random() * 0.6)
			else
				done = entity:Dash(DODGE_DIRECTIONS[math.random(#DODGE_DIRECTIONS)])
			end
			if done then
				self._defense = nil
			end
		end
	end
	return self._defense ~= nil or entity:IsBlocking()
end

-- Twice a second, maybe use a ready skill whose range fits the distance
function Brain:TrySkill(target, distance)
	local now = os.clock()
	if #self.Skills == 0 or now < self._nextSkillThought then return false end
	self._nextSkillThought = now + 0.5
	if math.random() > (self.Behaviour.SkillChance or 0) then return false end
	if not self.Entity:IsFacing(target.HumanoidRootPart.Position, 20) then return false end

	local options = {}
	for _, skill in self.Skills do
		if distance <= skill.Range and distance >= skill.MinRange and self.Entity:SkillReady(skill.Name) then
			table.insert(options, skill)
		end
	end
	if #options == 0 then return false end

	local skill = options[math.random(#options)]
	if self.Entity:UseSkill(skill.Name, target) then
		self.Navigator:Stop()
		return true
	end
	return false
end

-- ─── Return home ─────────────────────────────────────────────────────────────

function Brain:UpdateReturn()
	local entity = self.Entity
	local home = entity.SpawnCFrame.Position

	if flatDistance(entity.Root.Position, home) < 3 or os.clock() - self._returnStarted > 20 then
		if os.clock() - self._returnStarted > 20 then
			entity.Model:PivotTo(entity.SpawnCFrame) -- stuck on the way back
		end
		self.Navigator:Stop()
		entity:SetSprinting(false)
		entity:UnequipWeapon()
		entity:Heal()
		self:SetState("Idle")
		self._nextWander = os.clock() + math.random(2, 5)
		return
	end
	self.Navigator:MoveTowards(home)
end

return Brain
