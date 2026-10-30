local module = {}

local animation = Instance.new("Animation")
animation.AnimationId = "rbxassetid://120486927277640"
local track

function module.Preload(char)
	local animator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator")
	if animator then
		track = animator:LoadAnimation(animation)
		print("Preloaded")
	end
end

function module.Stop(char)
	local fxFolder = char.HumanoidRootPart:FindFirstChild("Rapid Pierce")
	if fxFolder then
		fxFolder:Destroy()
	end
	if track then
		track:Stop()
	end
end

function module.Fire(char)

	local HRP = char.HumanoidRootPart
	local fxPath = game.ReplicatedStorage.VFX["Rapid Pierce"]
	local fxFolder = Instance.new("Folder", HRP)
	fxFolder.Name = "Rapid Pierce"

	track = HRP.Parent.Humanoid:FindFirstChild("Animator"):LoadAnimation(animation)

	local sound = fxPath.Sound:Clone()
	sound.Parent= HRP
	
	for _, attachment in fxPath:GetChildren() do
		if attachment:IsA("Attachment") then
			local clone = attachment:Clone()
			clone.Parent = fxFolder
		end
	end

	local homePos = Vector3.new(0.8,0,-3)
	local xSize = 2.3
	local ySize = 2
	local zSize = 1
	local playing = true
	local repeatCount = 0

	track:Play(0.01)
	sound:Play()

	local function emitChild(parent)
		for _, v in parent:GetDescendants() do
			if v.Name == "Air" then
				v:Emit(2)
				continue
			end
			if v:IsA("ParticleEmitter") then
				v:Emit(1)
			end
		end
	end

	local function emit()
		local attachment = fxFolder.Impact:Clone()
		if not fxFolder then return end
		attachment.Parent = HRP
		attachment.Position = homePos + Vector3.new(math.random(-xSize,xSize),math.random(-ySize,ySize),math.random(-zSize,zSize))
		local color = ColorSequence.new(Color3.fromRGB(185, math.random(200,245), 255))
		for _, pe in attachment.Thrust:GetChildren() do
			if pe.Name == "Air" then
				continue
			end
			pe.Color = color
		end
		emitChild(attachment)
		game.Debris:AddItem(attachment,0.5)
	end

	track:GetMarkerReachedSignal("Start"):Once(function()
		print("Start")

		for _, pe in fxFolder.Dust:GetChildren() do
			if pe:IsA("ParticleEmitter") then
				pe.Enabled = true
			end
		end
		
		task.delay(1, function()
			playing = false
		end)

		while playing == true do
			task.wait(0.05)
			emit()
			task.wait(0.01)
			emit()
		end

	end)

	track:GetMarkerReachedSignal("End"):Once(function()
		task.wait(1.5)
		fxFolder:Destroy()
	end)

	track:GetMarkerReachedSignal("Slash"):Once(function()
		for _, pe in fxFolder.Dust:GetChildren() do
			if pe:IsA("ParticleEmitter") then
				pe.Enabled = false
			end
		end
		
		for _, pe in fxFolder.Slash:GetChildren() do
			if pe:IsA("ParticleEmitter") then
				pe:Emit(1)
			end
		end
		for _, pe in fxFolder.SlashDust:GetChildren() do
			if pe:IsA("ParticleEmitter") then
				pe:Emit(50)
			end
		end
	end)
end

function module.Finisher(char, victim)
	local rightLeg = victim:FindFirstChild("Right Leg"):Clone(); rightLeg.Parent = workspace; game.Debris:AddItem(rightLeg, 2)
	local leftLeg = victim:FindFirstChild("Left Leg"):Clone(); leftLeg.Parent = workspace; game.Debris:AddItem(leftLeg, 2)
	rightLeg.CanCollide = false
	leftLeg.CanCollide = false
	victim:FindFirstChild("Right Leg").Transparency = 1
	victim:FindFirstChild("Left Leg").Transparency = 1
end

return module
