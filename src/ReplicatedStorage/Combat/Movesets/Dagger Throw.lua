local module = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local meshplugin = require(game.ReplicatedStorage.Modules.Part_Icles)
meshplugin:Activate()
local Rocks = require(game.ReplicatedStorage.Modules.RocksModule)

local animation = Instance.new("Animation")
animation.AnimationId = "rbxassetid://136014621274607"
local track

local vfxPath = game.ReplicatedStorage.VFX["Dagger Throw"]
local shadowRoot = game.ReplicatedStorage.VFX["Shade Step"].Shadow.HumanoidRootPart

-- Air variant animation. Set the "AirAnimationId" attribute on ReplicatedStorage.VFX["Dagger Throw"]
-- once AirThrowKeyframes is published; until then Studio previews the keyframes directly and live
-- servers fall back to the ground throw sped up.
local airAnimation = Instance.new("Animation")
local airAnimSpeed = 1
do
	local publishedId = vfxPath:GetAttribute("AirAnimationId")
	local keyframes = vfxPath:FindFirstChild("AirThrowKeyframes")
	if publishedId and publishedId ~= "" then
		airAnimation.AnimationId = publishedId
	elseif RunService:IsStudio() and keyframes then
		local ok, tempId = pcall(function()
			return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(keyframes)
		end)
		airAnimation.AnimationId = ok and tempId or animation.AnimationId
		airAnimSpeed = ok and 1 or 1.6
	else
		airAnimation.AnimationId = animation.AnimationId
		airAnimSpeed = 1.6
	end
end

-- [char] = { track, vfx, meshvfx } for the cast currently playing; Stop clears it
local activeCasts = {}

function module.Preload(char)
	local animator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator")
	if animator then
		track = animator:LoadAnimation(animation)
		print("Preloaded")
	end
end

local function emitParticles(parent)
	for _, v in parent:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount") or 1)
		end
	end
end

local function throwDagger(hrp)
	local clone = vfxPath.ThrowingDagger:Clone()
	clone.Parent = game.Workspace
	clone.CFrame = hrp.CFrame * CFrame.new(0, 0, -3)
	clone.Anchored = true
	clone.CanCollide = false
	
	local sound1 = Instance.new("Sound", hrp)
	sound1.SoundId = "rbxassetid://87246955627321"
	
	sound1:Play()
	
	game.Debris:AddItem(sound1, 1)
	
	local direction = hrp.CFrame.LookVector

	game.Debris:AddItem(clone, 2)
	
	local connection
	connection = game.RunService.Heartbeat:Connect(function(dt)
		if not clone.Parent then
			connection:Disconnect()
			return
		end
		clone.CFrame = clone.CFrame + direction * 100 * dt
	end)
end

local function cleanup(cast)
	if cast.vfx then cast.vfx:Destroy() end
	if cast.meshvfx then cast.meshvfx:Destroy() end
	if cast.hover then cast.hover:Destroy() end
end

-- Called by SkillReplicationClient when the caster gets CancelSkill (stunned): stops the remaining throws
function module.Stop(char)
	local cast = activeCasts[char]
	if not cast then return end
	activeCasts[char] = nil
	if cast.track then cast.track:Stop() end
	cleanup(cast)
end

-- ─── Air variant: dagger fan into the ground ────────────────────────────────

local function groundIgnoreParams(extra)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { workspace.Alive, workspace:FindFirstChild("Projectiles"), workspace:FindFirstChild("Debris") }
	for _, v in extra or {} do table.insert(ignore, v) end
	params.FilterDescendantsInstances = ignore
	return params
end

-- One visual dagger: flies origin -> point at `speed`, sticks into the ground, then fades
local function fanDagger(origin, point, speed)
	local dagger = vfxPath.ThrowingDagger:Clone()
	dagger.Anchored = true
	dagger.CanCollide = false
	dagger.CanQuery = false
	dagger.CFrame = CFrame.lookAt(origin, point)
	dagger.Parent = workspace

	local travel = (point - origin).Magnitude / speed
	local landCFrame = CFrame.lookAt(point, point + (point - origin).Unit) * CFrame.new(0, 0, -0.6)
	local tween = TweenService:Create(dagger, TweenInfo.new(travel, Enum.EasingStyle.Linear), { CFrame = landCFrame })
	tween:Play()
	tween.Completed:Once(function()
		for _, v in dagger:GetDescendants() do
			if v:IsA("Trail") then v.Enabled = false end
		end
		task.delay(1.2, function()
			for _, v in dagger:GetDescendants() do
				if v:IsA("BasePart") then
					TweenService:Create(v, TweenInfo.new(0.4), { Transparency = 1 }):Play()
				end
			end
		end)
	end)
	Debris:AddItem(dagger, travel + 1.8)
end

-- Ground impact at the AOE centre: rock ring, shockwave mesh, dark dust and flash
local function impact(position, normal, radius)
	local fx = Instance.new("Part")
	fx.Anchored = true
	fx.CanCollide = false
	fx.CanQuery = false
	fx.Transparency = 1
	fx.Size = Vector3.one
	fx.CFrame = CFrame.new(position) * CFrame.new(0, 0.5, 0)
	fx.Parent = workspace
	Debris:AddItem(fx, 2)

	-- Shadow "wind" dust + flashes from the Shade Step shadow
	for _, emitter in shadowRoot.Ground:GetChildren() do
		local clone = emitter:Clone()
		clone.Parent = fx
		clone:Emit((emitter:GetAttribute("EmitCount") or 2) * 2)
	end
	for _, emitter in shadowRoot:GetChildren() do
		if emitter:IsA("ParticleEmitter") then
			local clone = emitter:Clone()
			clone.Parent = fx
			clone:Emit(math.max(emitter:GetAttribute("EmitCount") or 0, 2))
		end
	end

	local shock = vfxPath.Shock:Clone()
	shock.CFrame = CFrame.new(position, position + normal) * CFrame.Angles(math.rad(-90), 0, 0)
	meshplugin:AbsoluteEmit(shock)
	Debris:AddItem(shock, 2)

	pcall(Rocks.Ground, position, normal, radius * 0.75, Vector3.new(1.3, 1.3, 1.3),
		{ workspace.Alive, workspace:FindFirstChild("Projectiles"), workspace:FindFirstChild("Debris") }, 10, false, 2.5)

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://87246955627321"
	sound.PlaybackSpeed = 0.6
	sound.Volume = 1.5
	sound.Parent = fx
	sound:Play()
end

local function airThrow(char, info)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or typeof(info) ~= "table" then return end

	local cast = {}
	activeCasts[char] = cast

	-- The caster's own client briefly hangs in the air for the throw (it owns its physics)
	if char == (Players.LocalPlayer and Players.LocalPlayer.Character) then
		local attachment = Instance.new("Attachment")
		attachment.Name = "DaggerSpreadHover"
		attachment.Parent = hrp
		local hover = Instance.new("LinearVelocity")
		hover.Attachment0 = attachment
		hover.MaxForce = math.huge
		hover.RelativeTo = Enum.ActuatorRelativeTo.World
		hover.VectorVelocity = Vector3.new(0, 4, 0)
		hover.Parent = attachment
		cast.hover = attachment
		Debris:AddItem(attachment, info.Delay + 0.25)
	end

	local animTrack = humanoid.Animator:LoadAnimation(airAnimation)
	animTrack.Priority = Enum.AnimationPriority.Action2
	animTrack:Play(0.05, 1, airAnimSpeed)
	cast.track = animTrack

	local vfx = vfxPath.Attachment:Clone()
	vfx.Parent = hrp
	cast.vfx = vfx

	task.wait(info.Delay)
	if activeCasts[char] ~= cast then return end

	emitParticles(vfx)
	local meshvfx = vfxPath.Shock:Clone()
	meshvfx.CFrame = vfx.WorldCFrame * CFrame.Angles(math.rad(90), 0, 0)
	meshplugin:AbsoluteEmit(meshvfx)
	cast.meshvfx = meshvfx

	local throwSound = Instance.new("Sound", hrp)
	throwSound.SoundId = "rbxassetid://87246955627321"
	throwSound.PlaybackSpeed = 1.15
	throwSound:Play()
	Debris:AddItem(throwSound, 1)

	-- Fan of daggers across the impact area, perpendicular to the throw direction
	local origin = hrp.Position + Vector3.new(0, 0.5, 0)
	local flat = (info.Position - origin) * Vector3.new(1, 0, 1)
	flat = flat.Magnitude > 0.1 and flat.Unit or hrp.CFrame.LookVector
	local right = flat:Cross(Vector3.yAxis)
	local count = math.max(info.Count or 7, 2)
	local params = groundIgnoreParams()
	for i = 1, count do
		local t = (i - 1) / (count - 1) - 0.5
		local spot = info.Position + right * (t * info.Radius * 1.5) + flat * ((math.random() - 0.5) * 4)
		local ground = workspace:Raycast(spot + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
		fanDagger(origin, ground and ground.Position or spot, info.Speed)
	end

	local centreTravel = (info.Position - origin).Magnitude / info.Speed
	task.delay(centreTravel, impact, info.Position, info.Normal or Vector3.yAxis, info.Radius)

	task.wait(0.3)
	if activeCasts[char] == cast then
		activeCasts[char] = nil
	end
	cleanup(cast)
end

-- ─── Shadow Marked visuals (any character with the ShadowMarked attribute) ──

local MARK_HIGHLIGHT = "ShadowMarkHighlight"

local function updateMark(model)
	local marked = model:GetAttribute("ShadowMarked") == true
	local highlight = model:FindFirstChild(MARK_HIGHLIGHT)
	if marked and not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = MARK_HIGHLIGHT
		highlight.FillColor = Color3.fromRGB(25, 0, 40)
		highlight.FillTransparency = 0.55
		highlight.OutlineColor = Color3.fromRGB(150, 70, 255)
		highlight.OutlineTransparency = 0.1
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model

		-- Dark pulse from the shadow's heart when the mark lands
		local torso = model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart")
		local heart = game.ReplicatedStorage.VFX["Shade Step"].Shadow.Torso:FindFirstChild("Heart")
		if torso and heart then
			local pulse = heart:Clone()
			pulse.Parent = torso
			emitParticles(pulse)
			Debris:AddItem(pulse, 1.5)
		end
	elseif not marked and highlight then
		highlight:Destroy()
	end
end

local function watchCharacter(model)
	if not model:IsA("Model") then return end
	model:GetAttributeChangedSignal("ShadowMarked"):Connect(function()
		updateMark(model)
	end)
	updateMark(model)
end

workspace.Alive.ChildAdded:Connect(watchCharacter)
for _, model in workspace.Alive:GetChildren() do
	watchCharacter(model)
end

-- ─── Entry point ────────────────────────────────────────────────────────────

function module.Fire(char, variant, info)
	if variant == "Air" then
		airThrow(char, info)
		return
	end
	
	local hrp = char.HumanoidRootPart
	if not hrp then return end
	
	local vfx = vfxPath.Attachment:Clone()
	vfx.Parent = hrp
	
	local meshvfx = vfxPath.Shock:Clone()
	
	local track = char.Humanoid.Animator:LoadAnimation(animation)
	track:Play(0.01)
	
	local cast = { track = track, vfx = vfx, meshvfx = meshvfx }
	activeCasts[char] = cast
	
	-- Throw times match the server section delays (0.5, 0.75, 1.0)
	for _, waitTime in {0.5, 0.25, 0.25} do
		task.wait(waitTime)
		if activeCasts[char] ~= cast then return end -- stopped by a stun
		emitParticles(vfx)
		meshvfx.CFrame = vfx.WorldCFrame * CFrame.Angles(math.rad(90), 0, 0)
		meshplugin:AbsoluteEmit(meshvfx)
		throwDagger(hrp)
	end
	
	task.wait(0.25)
	if activeCasts[char] == cast then
		activeCasts[char] = nil
	end
	cleanup(cast)
end

return module
