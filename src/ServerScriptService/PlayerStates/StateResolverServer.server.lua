local Players = game:GetService("Players")
local stateManager = require(game.ServerScriptService.PlayerStates.StateManager)
local StatConfig = require(game.ServerScriptService.Config.StatConfig)
local Manager = require(game.ServerScriptService.PlayerData.Manager)
local damageIndicator = require(game.ReplicatedStorage.Modules.DamageIndicator)

local ragdollModule = require(game.ServerScriptService.Combat.RagdollModule)
local ragdollEvent = game.ReplicatedStorage.RemoteEvents.Combat.Ragdoll
local leaveEvent = game.ReplicatedStorage.Bindables.LeaveProcessed


-- =========================
-- CONFIG
-- =========================

local DEFAULT_SPEED = 12
local DEFAULT_JUMP = 7

-- Priority order:
-- 1. Hard CC (Stun / Ragdoll)
-- 2. HitStun
-- 3. Slow
-- 4. Blocking
-- 5. Default

-- =========================
-- Movement Resolver
-- =========================

local function overTimeEffect(char, duration, callback)
	for i = 1, duration do
		callback()
		task.wait(1)
	end
end

local function resolveMovement(char : Model, stateName)
	
	local plr = Players:GetPlayerFromCharacter(char)
	if not plr and not char:HasTag("Dummy") and not char:HasTag("Entity") then return end
	
	local hum = char:FindFirstChild("Humanoid")
	if not hum then return end

	local states = stateManager:GetAll()[char]
	if not states then return end
	
	local data = Manager.GetData(plr)
	if not data and not char:HasTag("Dummy") and not char:HasTag("Entity") then return end

	local healthMissing = hum.MaxHealth - hum.Health
	local newSpeed = 12 - (healthMissing / hum.MaxHealth) * 5
	if char:HasTag("Entity") then
		newSpeed = char:GetAttribute("BaseWalkSpeed") or DEFAULT_SPEED
	end
	local newJump = 7
	local JumpEnabled = true
	
	if data then
		newSpeed = StatConfig.GetSpeedMult(DEFAULT_SPEED, data.Stats)
	end
	
	if states.Sprinting and not states.Slow then
		newSpeed += 8
	end
	
	if states.FlickerDashing and not states.Slow then
		print("Flicker Dash")
		newSpeed = 55
	end
	
	if states.Ragdoll then
		ragdollModule:Ragdoll(char)
		ragdollEvent:FireAllClients(char)
	elseif states.Ragdoll == false then
		ragdollModule:unRagdoll(char)
		ragdollEvent:FireAllClients(char)
	end
	-- Priority Order
	if stateManager:CheckStun(char) then
		newSpeed = 0
		newJump = 0
		JumpEnabled = false
		stateManager:AddState(char, "CancelSkill", 1)
	elseif typeof(states.Slow) == "number" then
		newSpeed -= states.Slow
	elseif states.Blocking or states.Slow then
		newSpeed = 8
	end
	
	if states.Fixed then
		newSpeed = 0
		newJump = 0
	end

	if states.JumpLock or states.Blocking then
		newJump = 0
		JumpEnabled = false
	end

	if hum.WalkSpeed ~= newSpeed then
		hum.WalkSpeed = newSpeed
	end

	if hum.JumpHeight ~= newJump then
		hum.JumpHeight = newJump
	end
	
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, JumpEnabled)
end

local function resolveStatus(char, status)
	local hum = char:FindFirstChild("Humanoid")
	while status and status.Parent == char:FindFirstChild("Status") and status.Value ~= nil do
		task.wait(0.5)
		if not status then break end
		
		if status.Name == "HealthRegen" then
			hum.Health += status.Value
			print("Regening: ", status.Value)
		end
		task.wait(0.5)
	end
	return
end

-- =========================
-- State Hooking
-- =========================

local function hookStateSignals(char : Model)
	local trackedStates = {
		"Stun",
		"Ragdoll",
		"HitStun",
		"Slow",
		"Blocking",
		"JumpLock",
		"Sprinting",
		"Fixed",
		"FlickerDashing"
	}

	for _, stateName in ipairs(trackedStates) do
		char:GetAttributeChangedSignal(stateName):Connect(function()
			resolveMovement(char, stateName)
		end)
	end
	
	local statusFolder = char:FindFirstChild("Status")
	if statusFolder then
		statusFolder.ChildAdded:Connect(function(status)
			resolveStatus(char, status)
		end)
	end

	-- Initial resolve
	resolveMovement(char)
end

-- =========================
-- Character Setup
-- =========================

local function setupCharacter(char)	
	stateManager.InitCharacter(char)
	stateManager:InstanceAll()
	damageIndicator.new(char)
	hookStateSignals(char)
	
	stateManager:AddState(char, "IFrame", 5)
	
	local data = Manager.GetData(Players:GetPlayerFromCharacter(char))
	if data then
		char.Humanoid.MaxHealth = StatConfig.GetHealth(data.Stats) + data.Level * 2.5
		print("Health set: ", char.Humanoid.MaxHealth)
	end
	
	char.Humanoid.Died:Connect(function()
		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end
		if not char:HasTag("Killed") then
			task.wait(3)
			player:LoadCharacterAsync()
		end
	end)
end

workspace.Alive.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		print("Setting up: ", child)
		setupCharacter(child)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		char.Parent = workspace.Alive
	end)
end)

Manager.ProfileLoaded.Event:Connect(function(player, data)
	local char = player.Character or player.CharacterAdded:Wait()
	char.Humanoid.MaxHealth = StatConfig.GetHealth(data.Stats)
	char.Humanoid.Health = char.Humanoid.MaxHealth
	print("Health set: ", char.Humanoid.MaxHealth)
end)

-- Cleanup (important)
leaveEvent.Event:Connect(function(player)
	local char = player.Character
	if char then
		stateManager:RemoveCharacter(char)
	end
end)

for _, entity in workspace.Alive:GetChildren() do
	setupCharacter(entity)
end
