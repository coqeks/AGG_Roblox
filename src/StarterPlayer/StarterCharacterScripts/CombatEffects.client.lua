local hitEffect = game.ReplicatedStorage.RemoteEvents.Effects.HitEffect
local blockEffect = game.ReplicatedStorage.RemoteEvents.Effects.BlockEffect
local weaveEffect = game.ReplicatedStorage.RemoteEvents.Effects.Weave
local evasiveEffect = game.ReplicatedStorage.RemoteEvents.Effects.Evasive
local amputateEffect = game.ReplicatedStorage.RemoteEvents.Effects.Amputate
local dashEffect = game.ReplicatedStorage.RemoteEvents.Effects.Dash
local requestConfig = game.ReplicatedStorage.RemoteEvents.Combat.RequestHBConfig
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local blockedAnim = Instance.new("Animation")
blockedAnim.Name = "Blocked"
blockedAnim.AnimationId = "rbxassetid://77204121949120"

local Char = script.Parent

if Char then
	local hum = Char:WaitForChild("Humanoid")
	local weaveAnims = {script:WaitForChild("Weave"):WaitForChild("Weave1"):Clone(), script:WaitForChild("Weave"):WaitForChild("Weave2"):Clone()}
	for _, anim in ipairs(weaveAnims) do
		anim.Parent = hum
		local preload = hum.Animator:LoadAnimation(anim)
	end
end

-- Utilities
local function stopAllAnim(hum)
	for _, anim in ipairs(hum:GetPlayingAnimationTracks()) do
		anim:Stop()
	end
end

local function  playHitAnim(Char)
	local hum = Char:WaitForChild("Humanoid")
	if not hum then return end
	local anims = {
		game.ReplicatedStorage.Animations.Combat.SharedAnim.HitAnim.LeftHit,
		game.ReplicatedStorage.Animations.Combat.SharedAnim.HitAnim.MidHit,
		game.ReplicatedStorage.Animations.Combat.SharedAnim.HitAnim.RightHit,
	}
	stopAllAnim(hum)
	local random = math.random(1,3)
	local anim = hum:LoadAnimation(anims[random])
	anim:Play()
	anim:AdjustSpeed(1.5)
end


-- Event connections
hitEffect.OnClientEvent:Connect(function(char, effectType, isCrit)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local vfx = script:FindFirstChild(effectType).VFX:Clone()
	if not vfx then return end
	Debris:AddItem(vfx, 1)
	
	local sound = script:FindFirstChild(effectType).Sound:Clone()
	Debris:AddItem(sound, 1)
	
	local critSound = script:FindFirstChild(effectType).CritSound:Clone()
	Debris:AddItem(critSound, 1)
	
	vfx.Parent = hrp
	sound.Parent = hrp
	critSound.Parent = hrp
	
	for _, pe in vfx:GetDescendants() do
		
		if pe:GetAttribute("Crit") and isCrit == false then
			continue
		end
		
		if pe:IsA("ParticleEmitter") then
			pe:Emit(pe:GetAttribute("EmitCount"))
		end
		
	end
	
	if isCrit then
		critSound:Play()
	end
	
	sound:Play()
	playHitAnim(char)
	
end)

blockEffect.OnClientEvent:Connect(function(char, weaponConfig)
	
	print("Block effect received")
	
	local hum = char:WaitForChild("Humanoid")
	if not hum then return end
	
	local blockedAnim = game.ReplicatedStorage.Animations.Combat[weaponConfig.WeaponClass].Blocked
	
	local anim = hum:LoadAnimation(blockedAnim)
	anim:Play()
	
	local vfx = script.Block[weaponConfig.Type].VFX:Clone()
	Debris:AddItem(vfx, 1)
	
	local sound = script.Block[weaponConfig.Type].Sound:Clone()
	Debris:AddItem(sound, 1)
	
	vfx.Parent = char:WaitForChild("HumanoidRootPart")
	sound.Parent = char:WaitForChild("HumanoidRootPart")
	
	for _, pe in vfx:GetDescendants() do
		if pe:IsA("ParticleEmitter") then
			pe:Emit(pe:GetAttribute("EmitCount"))
		end
	end
	
	sound:Play()
end)

weaveEffect.OnClientEvent:Connect(function(char)
	local hum = char:WaitForChild("Humanoid")
	if not hum then return end
	
	local weaveAnims = {script.Weave.Weave1:Clone(), script.Weave.Weave2:Clone()}
	local random = math.random(1,2)
	local anim = hum:LoadAnimation(weaveAnims[random])
	anim:Play()
	
	local vfx = game.ReplicatedStorage.VFX.AfterImage:Clone(); Debris:AddItem(vfx, 2)
	vfx.Parent = workspace
	vfx.CFrame = char.HumanoidRootPart.CFrame
	for _, part in vfx:GetChildren() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(1), {Transparency = 1}):Play()
		end
	end
	for _, pe in vfx:GetChildren() do
		if pe:IsA("ParticleEmitter") then
			pe:Emit(5)
		end
	end
end)

evasiveEffect.OnClientEvent:Connect(function(char)
	local vfx = game.ReplicatedStorage.VFX.Evasive:Clone()
	Debris:AddItem(vfx, 1.5)
	vfx.Parent = char.HumanoidRootPart
	vfx.Sound:Play()
	vfx.ParticleEmitter:Emit(20)
end)

amputateEffect.OnClientEvent:Connect(function(char, part)
	print(part)
	local torso = char:WaitForChild("Torso")
	if part == "Left Arm" then
		local LArm = char:FindFirstChild("Left Arm")
		LArm.CanCollide = true
		torso:FindFirstChild("Left Shoulder").Part1 = nil
		task.delay(10, function()
			torso:FindFirstChild("Left Shoulder").Part1 = char:FindFirstChild("Left Arm")
			LArm.CanCollide = false
		end)
		LArm:ApplyImpulse(Vector3.new(0, 100, 0))
		
		local fx = game.ReplicatedStorage.VFX.Amputate.LArm:Clone() ; Debris:AddItem(fx, 1)
		fx.Parent = torso
		fx.ParticleEmitter:Emit(1)
	elseif part == "Right Leg" then
		local RLeg = char:FindFirstChild("Right Leg")
		RLeg.CanCollide = true
		torso:FindFirstChild("Right Hip").Enabled = false
		task.delay(10, function()
			torso:FindFirstChild("Right Hip").Enabled = true
			RLeg.CanCollide = false
		end)
		RLeg:ApplyImpulse(Vector3.new(0, 100, 0))
		
		local fx = game.ReplicatedStorage.VFX.Amputate.RLeg:Clone() ; Debris:AddItem(fx, 1)
		fx.Parent = torso
		fx.ParticleEmitter:Emit(1)
	end
end)