local StateService = {}

local playerStates = {}

export type  State = {
	HitStun: boolean,
	Stun: boolean,
	Ragdoll: boolean,
	DOT: {
		Burn: boolean,
		BrokenArm: boolean,
		BrokenLeg: boolean
	},
	IFrame: boolean,
	Blocking: boolean,
	PBFrame: boolean,
	Airborne: boolean,
	PDFrame: boolean,
	Dashing: boolean,
	UsingSkill: boolean,
	Slow: boolean,
	JumpLock: boolean,
	Sprinting: boolean,
	Cooldowns: {
		[any]: boolean
	},
	WeaponEquipped: boolean,
	KillStreak: number
}

function StateService.InitCharacter(char)
	print("Initializing states: ", char.Name)
	playerStates[char] = {
		HitStun = false, --// ONLY applied when a character is hit with an attack, stuns and plays hit animation
		
		Stun = false, --// Versatile stun, can be applied by whatever and does not always play hit anim
		
		Ragdoll = false, --// Ragdolls character, character is stunned (can't attack, move, block etc)
		
		DOT = {
			Burn = false,
			BrokenArm = false,
			BrokenLeg = false
		}, --// Any damage taken over time
		
		IFrame = false, --// Character can not be hit in this state
		
		Blocking = false, --// Character is blocking, can not be hit by blockable moves
		
		PBFrame = false, --// Perfect block frame, blocking something in this frame will stun attacker
		
		Airborne = false, --// Character is in the air
		
		PDFrame = false, --// Perfect dash frame, can not be hit in this frame
		
		Dashing = false,
		
		FlickerDashing = false,
		
		UsingSkill = false,
		
		Slow = false,
		
		JumpLock = false,
		
		Sprinting = false,
		
		Cooldowns = {
			M1 = false, 
			Dash = false, 
			Block = false,
			RunningAttack = false,
			Skill = false
		},
		
		Status = {
			DamageBuff = {},
			HealthBuff = {},
			SwingSpeedBuff = {},
			DamageDebuff = {},
			HealthDebuff = {},
			SpeedDebuff = {},
			HealthRegen = {},
			Burn = {}
		},
		
		Passives = {},
		
		KillStreak = 0,
		
		WeaponEquipped = false
	}
	local CDfolder = Instance.new("Folder", char)
	CDfolder.Name = "Cooldowns"
	local StatusFolder = Instance.new("Folder", char)
	StatusFolder.Name = "Status"
	local Passives = Instance.new("Folder", char)
	Passives.Name = "Passives"
end


function StateService:AddState(char : Model, stateName : string, duration : NumberValue, value: boolean)
	local states = playerStates[char]
	if not states then 
		print("states not found for: ", char.Name)
		return 
	end

	-- Create state container if it doesn't exist
	states._timers = states._timers or {}

	-- Generate unique token
	local token = tick()
	states._timers[stateName] = token

	-- Set value
	local stateValue = value ~= nil and value or true
	states[stateName] = stateValue
	char:SetAttribute(stateName, stateValue)

	--print("State Added:", stateName, "to", char)

	if duration then
		task.delay(duration, function()
			-- Only remove if this is STILL the latest application
			if states._timers[stateName] == token then
				self:RemoveState(char, stateName)
				states._timers[stateName] = nil
			end
		end)
	end
end

function  StateService:AddStatus(char : Model, name : string, duration : NumberValue, value : NumberValue)
	local states = playerStates[char]
	if not states then return end
	if not value then return end
	local Status = states.Status
	local StatusFolder = char:FindFirstChild("Status")

	local state = Instance.new("NumberValue", StatusFolder)
	state.Name = name
	state.Value = value
	
	table.insert(Status[name], value)
	local index = #Status[name]
	print(Status)
	task.delay(duration, function()
		state:Destroy()
		Status[name][index] = nil
	end)
end

function StateService:AddCooldown(char : Model, name : string, duration : NumberValue)
	local states = playerStates[char]
	if not states then return end
	local cooldowns = states.Cooldowns
	local CDFolder = char:FindFirstChild("Cooldowns")
	local CD = Instance.new("BoolValue", CDFolder)
	CD.Name = name
	CD.Value = true

	task.delay(duration, function()
		if CD then CD:Destroy() end
	end)
end

function StateService:AddPassive(char, name)
	local states = playerStates[char]
	if not states then return end
	states.Passives[name] = true
	local passiveFolder = char:FindFirstChild("Passives")
	if not passiveFolder then return end

	local passive = Instance.new("NumberValue", passiveFolder)
	passive.Name = name
	passive.Value = 1
	print("Passive Added:", name, "to", char)
end

function StateService:ClearPassives(char)
	local passiveFolder = char:FindFirstChild("Passives")
	if not passiveFolder then return end
	passiveFolder:ClearAllChildren()
end

function StateService:RemoveState(char, stateName)
	local states = playerStates[char]
	if not states then return end

	states[stateName] = false
	char:SetAttribute(stateName, false)
end

function StateService:RemoveStun(char)
	local states = playerStates[char]
	if not states then return end
	
	states["Stun"] = false
	char:SetAttribute("Stun", false)
	states["HitStun"] = false
	char:SetAttribute("HitStun", false)
	states["Ragdoll"] = false
	char:SetAttribute("Ragdoll", false)
	states["Slow"] = false
	char:SetAttribute("Slow", false)
end

function StateService:HasState(char, stateName)
	local states = playerStates[char]
	if not states then return false end
	if typeof(states[stateName]) ~= "boolean" then return states[stateName] end
	
	return states[stateName] == true
end

function StateService:CheckCooldown(char, name)
	local cooldown = char:FindFirstChild("Cooldowns"):FindFirstChild(name)
	if not cooldown then return false end
	if cooldown then
		return true
	else
		return false
	end
end

function StateService:CheckStun(char)
	local states = playerStates[char]
	if not states then return false end
	
	if states["Stun"] == true or states["HitStun"] == true or states["Ragdoll"] == true then
		return true
	end
	return false
end

function StateService:GetAll()
	return playerStates
end

function StateService:GetAllFromChar(char)
	return playerStates[char]
end

function StateService:GetAllFromPlr(plr)
	local char = plr.Character
	if not char then warn("[StateService] No character found") return end
	return playerStates[char]
end

function StateService:InstanceAll()
	local playerStates = self:GetAll()
	for char, states in pairs(playerStates) do
		for stateName, stateValue in pairs(states) do
			if stateName ~= "_timers" and typeof(stateValue) ~= "table" then
				char:SetAttribute(stateName, stateValue)
			end
		end
	end
end

function StateService:RemoveCharacter(char)
	playerStates[char] = nil
	print("Removed character from state manager:", char)
end


return StateService
