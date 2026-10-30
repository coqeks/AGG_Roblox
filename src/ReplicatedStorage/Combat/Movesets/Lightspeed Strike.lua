local module = {}
local animation = Instance.new("Animation")
animation.AnimationId = "rbxassetid://74838843286840"
local track
local meshplugin = require(game.ReplicatedStorage.Modules.Part_Icles)
meshplugin:Activate()
local fxPath = game.ReplicatedStorage.VFX["Lightspeed Strike"].VFXRoot
local Debris = game:GetService("Debris")

local DASH_DISTANCE = 40
local CHAR_RADIUS   = 2   -- rough half-width, used to offset the landing point
local RAY_PARAMS    = RaycastParams.new()
RAY_PARAMS.FilterType = Enum.RaycastFilterType.Exclude

function module.Preload(char)
	local animator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChildOfClass("Animator")
	if animator then
		track = animator:LoadAnimation(animation)
		print("Preloaded")
	end
end

local function emitParticles(parent)
	for _, v in parent:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end
end

local function enableParticles(parent, dur)
	for _, v in parent:GetDescendants() do
		if v:IsA("ParticleEmitter") and v.Name ~= "Dust" then
			v.Enabled = true
			task.delay(dur, function()
				v.Enabled = false
			end)
		end
	end
end

-- Returns the CFrame the character should land on after a forward dash.
-- Casts a ray from HRP forward; if something is in the way it stops
-- CHAR_RADIUS studs short of the hit so the character doesn't clip into it.
local function getSafeDashCFrame(HRP, char, distance)
	RAY_PARAMS.FilterDescendantsInstances = { game.Workspace.Alive }

	local origin    = HRP.CFrame.Position
	local direction = HRP.CFrame.LookVector * distance

	local result = workspace:Raycast(origin, direction, RAY_PARAMS)

	if result then
		-- Pull back slightly so the character doesn't overlap the surface
		local safePos = result.Position - HRP.CFrame.LookVector * CHAR_RADIUS
		return CFrame.new(safePos) * (HRP.CFrame - HRP.CFrame.Position)
	else
		-- Nothing in the way; use the full distance
		return HRP.CFrame * CFrame.new(0, 0, -distance)
	end
end

function module.Stop(char)
	print("Stopping")
	if track then
		track:Stop()
	end
	if char.HumanoidRootPart:FindFirstChild("Lightspeed Strike") then
		char.HumanoidRootPart:FindFirstChild("Lightspeed Strike"):Destroy()
	end
	char.Humanoid.AutoRotate = true
end

function module.Fire(char, variant)
	local HRP      = char.HumanoidRootPart
	local humanoid = char:FindFirstChild("Humanoid")
	local fxFolder = Instance.new("Folder", HRP); Debris:AddItem(fxFolder, 3)
	fxFolder.Name = "Lightspeed Strike"
	
	track = char.Humanoid.Animator:LoadAnimation(animation)
	track:Play(0.01)

	local cut = Instance.new("Sound", fxFolder)
	cut.SoundId = "rbxassetid://109746689805973"
	cut.Volume = 1.5

	local cut2 = Instance.new("Sound", fxFolder)
	cut2.SoundId = "rbxassetid://84752147673512"
	Debris:AddItem(cut, 2)
	Debris:AddItem(cut2, 3)

	local beamAttach = fxPath.BeamAttach:Clone()
	beamAttach.Parent = fxFolder
	Debris:AddItem(beamAttach, 3)

	local beams = fxPath.Beams:Clone()
	beams.Parent = fxFolder
	Debris:AddItem(beams, 3)

	local mid   = fxPath.Mid:Clone();   Debris:AddItem(mid,   2)
	local wind  = fxPath.Wind:Clone();  Debris:AddItem(wind,  2)
	local flash = fxPath.Flash:Clone(); Debris:AddItem(flash, 2)
	local ground = fxPath.Ground:Clone(); Debris:AddItem(ground, 2)
	local eye   = fxPath.Eye:Clone();   Debris:AddItem(eye,   2)

	eye.Parent    = fxFolder
	ground.Parent = fxFolder
	mid.Parent    = fxFolder
	wind.Parent   = fxFolder
	flash.Parent  = fxFolder
	flash.Weld.Part1 = HRP

	cut:Play()
	enableParticles(ground, 0.5)
	eye.ParticleEmitter:Emit(1)
	if variant == 2 then
		task.wait(0.25)
		track.TimePosition = 0.75
	else
		task.wait(0.75)
	end
	
	if char:GetAttribute("CancelSkill") then return end

	cut2:Play()
	humanoid.AutoRotate = false

	emitParticles(mid)

	-- ✅ Raycast before teleporting
	local safeCFrame 
	if variant == 2 then
		safeCFrame = getSafeDashCFrame(HRP, char, 20)
	else
		safeCFrame = getSafeDashCFrame(HRP, char, DASH_DISTANCE)
	end
	HRP.CFrame = safeCFrame

	task.wait(0.1)
	ground.Dust:Emit(30)
	emitParticles(wind)
	meshplugin:AbsoluteEmit(beams.GroundBeamL)
	meshplugin:AbsoluteEmit(beams.GroundBeamR)

	for _, pe in flash:GetChildren() do
		pe.Enabled = true
		task.delay(0.25, function()
			pe.Enabled = false
		end)
	end
	
	track:AdjustSpeed(0.25)

	task.wait(0.6)
	humanoid.AutoRotate = true
end

function module.Finisher(char, victim)
	print("Lightspeed finisher")

	local head = victim:FindFirstChild("Head")
	if not head then return end

	local flyingHead = head:Clone()
	head.Transparency = 1

	flyingHead.Parent = workspace
	flyingHead.CanCollide = false
	flyingHead.Anchored = false

	-- Clean physics state
	flyingHead.AssemblyLinearVelocity = Vector3.zero
	flyingHead.AssemblyAngularVelocity = Vector3.zero

	-- Attachment for force
	local att = Instance.new("Attachment")
	att.Parent = flyingHead

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.VectorVelocity = Vector3.new(0, 50, 0) -- consistent upward speed
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = flyingHead
	Debris:AddItem(lv, 0.1)

	Debris:AddItem(flyingHead, 2)
end

return module