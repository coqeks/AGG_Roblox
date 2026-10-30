local Plr = game.Players.LocalPlayer

local HitBoxMod = require(game.ReplicatedStorage.Combat.HBDetection)
local HitBoxConfig 
local requestConfig = game.ReplicatedStorage.RemoteEvents.Combat.RequestHBConfig
local attackRemote = game.ReplicatedStorage.RemoteEvents.Combat.Attack

local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Char = Plr.Character or Plr.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")
local Cooldowns = Char:WaitForChild("Cooldowns")
local m1Button = Plr.PlayerGui:FindFirstChild("Mobile"):FindFirstChild("Attack").Attack

local configAnimEvent = game.ReplicatedStorage.Bindables.ConfigAnim

Char:SetAttribute("Combo", 1)


local playingCombatAnim = {}
local lastM1 = tick()


------------------------------------------------
-- Functions
------------------------------------------------

------------------------------------------------
-- Rhythmic Tendency
------------------------------------------------
local function getPlaybackSpeed()
	local status = Char:FindFirstChild("Status")
	if not status then return 1 end

	local rtStacks = 0
	for _, child in status:GetChildren() do
		if child.Name == "Rhythmic Tendency" then
			rtStacks += 1
		end
	end

	-- 5% faster per stack, matching server reduction
	return 1 + (rtStacks * 0.025)
end

local function configAnim(name : string)
	------------------------------------------------
	-- Fetches animation from replicated storage to 'HitBoxConfig' metadata
	------------------------------------------------
	local animPath = game.ReplicatedStorage.Animations.Combat:WaitForChild(name)
	local animate = Char:WaitForChild("Animate")
	local numberOfAnims = #animPath:GetChildren() - 3
	for i = 1, numberOfAnims do
		HitBoxConfig.Animations[i] = animPath:WaitForChild(i):Clone() --// M1 chains
		Hum.Animator:LoadAnimation(HitBoxConfig.Animations[i])
	end
	HitBoxConfig.Animations["RunningAttack"] = animPath:WaitForChild("RunningAttack"):Clone() --// Dash attack
	configAnimEvent:Fire(name)
	print("Animations configured")
end

local function stopAnim(hum)
	------------------------------------------------
	-- Stops all playing animations
	------------------------------------------------
	for _, anim in ipairs(playingCombatAnim) do
		anim:Stop()
	end
end

local function stopAllAnim(hum)
	for _, anim in ipairs(hum:GetPlayingAnimationTracks()) do
		anim:Stop()
	end
end

local function detectAirborne()
	------------------------------------------------
	-- Detects if local player is airborne
	------------------------------------------------
	if not Char or not Char:FindFirstChild("HumanoidRootPart") then
		return 
	end
	
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {Char}
	params.FilterType = Enum.RaycastFilterType.Blacklist

	local result = workspace:Raycast(
		Char.HumanoidRootPart.Position,
		Vector3.new(0, -5, 0),
		params
	)
	return result
end

local function runAttackVFX(Char)
	local hrp = Char.HumanoidRootPart
	if not hrp then return end
	
	local fx = script.FrontDash:Clone()
	fx.Parent = Char
	fx.CFrame = hrp.CFrame
	local weld = Instance.new("Weld")
	weld.Part0 = hrp
	weld.Part1 = fx
	weld.Parent = fx
	
	fx.Dust.ParticleEmitter.Enabled = true
	fx.VFX.Wind:Emit(5)
	
	task.delay(0.3, function()
		fx.Dust.ParticleEmitter.Enabled = false
	end)
	
	game.Debris:AddItem(fx, 1)
end

local function checkStunClient(char)
	if char:GetAttribute("HitStun") or char:GetAttribute("Blocking") or char:GetAttribute("UsingSkill") ~= false or char:GetAttribute("Dashing") or char:GetAttribute("Stun") then
		return true
	else
		return false
	end
end

local function m1Handler()
	if Char:GetAttribute("WeaponEquipped") == false 
		or checkStunClient(Char) == true
		or Cooldowns:FindFirstChild("M1") then return end
	
	-- check if config is loaded
	if not HitBoxConfig or not HitBoxConfig.Animations then
		warn("HitBoxConfig not ready")
		return
	elseif Char.Humanoid:FindFirstChild("Animator") == nil then
		warn("Animator not ready")
		return
	end

	if next(playingCombatAnim) ~= nil then
		stopAnim(Hum)
	end

	local attackAnim

	if Char:GetAttribute("Sprinting") == true and not Cooldowns:FindFirstChild("RunningAttack") then
		attackRemote:FireServer("DashAttack")
		runAttackVFX(Char)
		attackAnim = Hum.Animator:LoadAnimation(HitBoxConfig.Animations["RunningAttack"])
	else
		attackRemote:FireServer("M1")
		attackAnim = Hum.Animator:LoadAnimation(HitBoxConfig.Animations[Char:GetAttribute("Combo")])
		attackAnim.Priority = Enum.AnimationPriority.Action
	end

	local playbackSpeed = getPlaybackSpeed()
	attackAnim:Play(0, nil, playbackSpeed)
	table.insert(playingCombatAnim, attackAnim)

	-- remove anim from table
	attackAnim.Stopped:Connect(function()
		for i, v in ipairs(playingCombatAnim) do
			if v == attackAnim then
				table.remove(playingCombatAnim, i)
				break
			end
		end
	end)
	--
end

------------------------------------------------
-- Connections
------------------------------------------------

RunService.Heartbeat:Connect(function()
	if detectAirborne() == nil then
		Char:SetAttribute("Airborne", true)
	else
		Char:SetAttribute("Airborne", false)
	end
end)

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		m1Handler()	
	end
	if input.KeyCode == Enum.KeyCode.Space then
		Char:SetAttribute("SpaceHold", true)
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then
		task.wait(0.2)
		Char:SetAttribute("SpaceHold", false)
	end
end)

m1Button.TouchTap:Connect(function()
	m1Handler()
end)


Char:GetAttributeChangedSignal("WeaponEquipped"):Connect(function()
	local weapon = Char:GetAttribute("WeaponEquipped")
	if weapon ~= false then
		requestConfig:FireServer(weapon)
	else
		configAnimEvent:Fire("Default")
	end
end)

Char:GetAttributeChangedSignal("UsingSkill"):Connect(function()
	if Char:GetAttribute("UsingSkill") == true then
		stopAnim(Hum)
	end
end)

local timer
attackRemote.OnClientEvent:Connect(function(combo)
	--print("Received combo")
	if combo == "DashLanded" then
		for _, track in ipairs(playingCombatAnim) do
			print(track)
			if track.Name == "RunningAttack" then
				track.TimePosition = 0.65
			end
		end
		return
	end
	Char:SetAttribute("Combo", combo)
	local token = tick()
	timer = token
	task.delay(3, function()
		if timer ~= token then return end
		Char:SetAttribute("Combo", 1)
	end)
end)

requestConfig.OnClientEvent:Connect(function(config)
	print("Config loaded:", config)
	HitBoxConfig = config
	configAnim(HitBoxConfig.WeaponClass)
end)

