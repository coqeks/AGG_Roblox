local module = {}

local animation = Instance.new("Animation")
animation.AnimationId = "rbxassetid://98463927344097"
local track

function module.Preload(char)
	local animator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator")
	if animator then
		track = animator:LoadAnimation(animation)
	end
end

local function emitParticles(parent)
	for _, v in parent:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end
end

function module.Stop(char)
	if track then
		track:Stop()
	end
	local fxFolder = char.HumanoidRootPart:FindFirstChild("Cross Slash")
	if fxFolder then
		fxFolder:Destroy()
	end
end

function module.Fire(char, variant)
	local vfxPath = game.ReplicatedStorage.VFX["Cross Slash"].VFXRoot
	local hrp = char.HumanoidRootPart
	if not hrp then return end
	local fxFolder = Instance.new("Folder", hrp)
	fxFolder.Name = "Cross Slash"
	
	local track = char.Humanoid.Animator:LoadAnimation(animation)
	track:Play(0.01)
	
	local sound1 = Instance.new("Sound", fxFolder)
	sound1.SoundId = "rbxassetid://137628815514180"
	
	local sound2 = Instance.new("Sound", fxFolder)
	sound2.SoundId = "rbxassetid://134312441080953"
	
	for _, v in vfxPath:GetChildren() do
		if v:IsA("Attachment") then
			local clone = v:Clone()
			clone.Parent = fxFolder
		end
	end
	
	if variant == 2 then
		track.TimePosition = 0.8
		emitParticles(fxFolder.Cross)
		emitParticles(fxFolder.Impact1)
		emitParticles(fxFolder.Impact2)
		sound2:Play()
		task.wait(1)
		fxFolder:Destroy()
		return
	end
	
	track:GetMarkerReachedSignal("RSlash"):Once(function()
		emitParticles(fxFolder.Slash1)
		emitParticles(fxFolder.Impact1)
	
		sound1:Play()
	end)
	
	track:GetMarkerReachedSignal("LSlash"):Once(function()
		emitParticles(fxFolder.Slash2)
		emitParticles(fxFolder.Impact2)
		
		sound1:Play()
	end)
	
	--track:GetMarkerReachedSignal("Cross"):Connect(function()
	--	emitParticles(vfxFolder.Cross)
	--	emitParticles(vfxFolder.Impact1)
	--	emitParticles(vfxFolder.Impact2)
	--	sound2:Play()
	--	task.wait(1)
	--	vfxFolder:Destroy()
	--end)
end

return module
