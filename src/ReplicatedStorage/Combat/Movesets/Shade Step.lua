local module = {}
module.Remote = Instance.new("RemoteEvent")

local animation = Instance.new("Animation")
animation.AnimationId = "rbxassetid://114855771683287"
local track

local cloneAnimations = {
	[1] = game.ReplicatedStorage.VFX["Shade Step"].LeftDash,
	[2] = game.ReplicatedStorage.VFX["Shade Step"].RightDash,
}

function module.Preload(char)
	local animator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator")
	if animator then
		track = animator:LoadAnimation(animation)
		print("Preloaded")
	end
end

local function randomOffset()
	local angle = math.random() * 2 * math.pi
	local distance = math.random(4, 7)
	return Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
end

local function makeTransparent(model, transparency)
	for _, v in ipairs(model:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Transparency = transparency
			v.CollisionGroup = "AfterImage"
			v.CanCollide = false
			--v.Anchored = true
			v.CastShadow = false
		end
		if v.Name == "HumanoidRootPart" then
			v.Transparency = 1
		end
	end
end

local function cloneToWorld(char, target)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local clone = char:Clone()
	
	clone.PrimaryPart = clone:FindFirstChild("HumanoidRootPart")

	local offset = randomOffset()

	makeTransparent(clone, 0.5)  -- anchor parts BEFORE moving
	clone.Parent = workspace
	
	local anim = cloneAnimations[math.random(1, #cloneAnimations)]
	local track = clone:FindFirstChildOfClass("Humanoid"):LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action4
	track:Play()

	-- Now move the whole model at once
	local targetCFrame = target.CFrame * CFrame.new(offset) * CFrame.Angles(0, math.rad(math.random(-180, 180)), 0)
	clone:PivotTo(targetCFrame)
	
	task.spawn(function()
		for _, v in clone:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = true
				task.delay(0.1, function()
					v.Enabled = false
				end)
			end
		end
	end)

	-- Disable humanoid so it doesn't fall or animate on its own
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	return clone
end

local function fadeAndDestroy(clone, delay, duration)
	task.spawn(function()
		task.wait(delay)
		local steps = 20
		local interval = duration / steps
		for i = 1, steps do
			local t = i / steps
			for _, v in ipairs(clone:GetDescendants()) do
				if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
					v.Transparency = t
				end
			end
			task.wait(interval)
		end
		clone:Destroy()
	end)
end

local function fadeIn(clone, duration)
	task.spawn(function()
		local steps = 20
		local interval = duration / steps
		for i = 1, steps do
			local t = i / steps
			for _, v in ipairs(clone:GetDescendants()) do
				if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
					v.Transparency = 1 - t
				end
			end
		end
	end)
end

local function scatterImages(char, target)
	for i = 1, 40 do
		local clone = cloneToWorld(char, target)
		clone.Torso.CanCollide = false
		if clone then
			fadeAndDestroy(clone, 0.1, 0.2)
		end
		task.wait(0.05)
	end
end

-- ─── Blink (Shadow Marked target): one shadow afterimage + flashes, no storm ────

local shadowModel = game.ReplicatedStorage.VFX["Shade Step"].Shadow

-- Burst the shadow's Flash/Wind emitters once at a world position
local function flashAt(cframe)
	local fx = Instance.new("Part")
	fx.Anchored = true
	fx.CanCollide = false
	fx.CanQuery = false
	fx.Transparency = 1
	fx.Size = Vector3.new(2, 2, 1)
	fx.CFrame = cframe
	fx.Parent = workspace
	game.Debris:AddItem(fx, 1.5)

	for _, child in shadowModel.HumanoidRootPart:GetChildren() do
		local clone = child:Clone()
		clone.Parent = fx
	end
	for _, v in fx:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			local count = v:GetAttribute("EmitCount") or 0
			if count > 0 then
				v:Emit(count)
			else
				-- Emitters without an EmitCount are short pulses in the original effect
				v.Enabled = true
				task.delay(0.1, function() v.Enabled = false end)
			end
		end
	end
end

local function setVisible(char, visible, saved)
	for _, v in char:GetDescendants() do
		if (v:IsA("BasePart") and v.Name ~= "HumanoidRootPart") or v:IsA("Decal") then
			if visible then
				if saved[v] ~= nil then v.Transparency = saved[v] end
			else
				saved[v] = v.Transparency
				v.Transparency = 1
			end
		end
	end
end

local function blink(char, info)
	if typeof(info) ~= "table" or not info.From or not info.To then return end

	-- Single shadow afterimage left at the departure point, fading out
	local shadow = shadowModel:Clone()
	shadow.PrimaryPart = shadow:FindFirstChild("HumanoidRootPart")
	makeTransparent(shadow, 0.3)
	for _, v in shadow:GetDescendants() do
		if v:IsA("BasePart") then v.Anchored = v.Name == "HumanoidRootPart" end
		if v:IsA("ParticleEmitter") then v:Destroy() end -- the flash below covers the burst
	end
	local humanoid = shadow:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	shadow.Parent = workspace
	shadow:PivotTo(info.From)
	if humanoid then
		local dashTrack = humanoid:LoadAnimation(cloneAnimations[math.random(1, #cloneAnimations)])
		dashTrack.Priority = Enum.AnimationPriority.Action4
		dashTrack:Play()
	end
	fadeAndDestroy(shadow, 0.15, 0.35)

	flashAt(info.From)
	flashAt(info.To)

	local sound = game.SoundService:FindFirstChild("Teleport")
	if sound and char:FindFirstChild("HumanoidRootPart") then
		sound = sound:Clone()
		sound.Parent = char.HumanoidRootPart
		sound:Play()
		game.Debris:AddItem(sound, 2)
	end

	-- The caster's own client moves itself right away (the server teleports too)
	if char == game.Players.LocalPlayer.Character then
		char.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		char:PivotTo(info.To)
	end

	-- Blink: hidden for a moment, then reappear behind the target
	local saved = {}
	setVisible(char, false, saved)
	task.delay(0.12, function()
		setVisible(char, true, saved)
	end)
end

-- SkillReplicationClient calls this on CancelSkill; the blink is instant and the original storm
-- can't be interrupted, so there's nothing to stop
function module.Stop(char)
end

function module.Fire(char, variant, target)
	if variant == "Blink" then
		blink(char, target)
		return
	end
	print("Shade step module fired")
	local track = char.Humanoid:LoadAnimation(animation)
	local rootPart = target:FindFirstChild("HumanoidRootPart")
	
	local player = game.Players:GetPlayerFromCharacter(char)
	if player and player == game.Players.LocalPlayer then
		local connection = game.RunService.Heartbeat:Connect(function()
			char.HumanoidRootPart.CFrame = target.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3)
		end)
		task.delay(2, function()
			connection:Disconnect()
		end)
	end
	
	for _, part in char:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Transparency = 1
			task.delay(2, function()
				part.Transparency = 0
			end)
		end
	end

	scatterImages(game.ReplicatedStorage.VFX["Shade Step"].Shadow, rootPart)
end

return module