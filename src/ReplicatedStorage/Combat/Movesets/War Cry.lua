local module = {}

local cameraShaker = require(game.ReplicatedStorage.Modules.CameraShaker)

local animation = Instance.new("Animation")
animation.AnimationId = "rbxassetid://140157145310793"
local track

function module.Preload(char)
	local animator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator")
	if animator then
		track = animator:LoadAnimation(animation)
		print("Preloaded")
	end
end

local function emit(parent)
	for _, v in parent:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount") or 1)
		end
	end
end

local function enable(parent)
	for _, v in parent:GetChildren() do
		if v:IsA("ParticleEmitter") then
			v.Enabled = true
			task.delay(v:GetAttribute("EmitDuration") or 0.8, function()
				v.Enabled = false
			end)
		end
	end
end

function module.Fire(char)
	local HRP = char.HumanoidRootPart
	local hum = char.Humanoid
	
	track = hum.Animator:LoadAnimation(animation)
	track:Play(0.01)
	
	local sound = Instance.new("Sound", HRP); game.Debris:AddItem(sound, 5)
	sound.SoundId = "rbxassetid://86129148379750"
	sound.Volume = 1.5
	
	local camera = workspace.CurrentCamera
	local camShake = cameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
		camera.CFrame = camera.CFrame * shakeCFrame
	end)
	camShake:Start()
	
	local vfx = game.ReplicatedStorage.VFX["War Cry"].VFXRoot:Clone(); game.Debris:AddItem(vfx, 3)
	vfx.Parent = HRP
	vfx.CFrame = HRP.CFrame
	vfx.Anchored = false
	vfx.Weld.Part1 = HRP
	
	local cc = game.ReplicatedStorage.VFX["War Cry"].WarCry:Clone(); game.Debris:AddItem(vfx, 3)
	cc.Parent = game.Lighting
	game.TweenService:Create(cc, TweenInfo.new(0.5), {TintColor = Color3.fromRGB(79, 79, 79)}):Play()
	sound:Play()
	
	task.wait(0.5)
	camShake:ShakeOnce(2, 5, 0.2, 1)
	emit(vfx.Thunder)
	emit(vfx.Radiate)
	enable(vfx)
	enable(vfx.Ground)
	task.wait(1)
	game.TweenService:Create(cc, TweenInfo.new(0.5), {TintColor = Color3.fromRGB(255,255,255), Saturation = 0, Contrast = 0, Brightness = 0}):Play()
	game.TweenService:Create(sound, TweenInfo.new(1), {Volume = 0}):Play()
	camShake:Stop()
end

return module
