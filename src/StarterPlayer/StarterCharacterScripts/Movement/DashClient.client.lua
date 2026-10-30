local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local DashRemote = ReplicatedStorage.RemoteEvents.Movement.DashEvent
local DashEffect = ReplicatedStorage.RemoteEvents.Effects.Dash
local KillDashRemote = ReplicatedStorage.RemoteEvents.Movement.KillDashEvent
local KnockBackRemote = ReplicatedStorage.RemoteEvents.Movement.KnockBack
local evasiveRemote = ReplicatedStorage.RemoteEvents.Combat.Evasive
local DashCurve = require(ReplicatedStorage.Modules.DashCurve)

local mobileGui = player:WaitForChild("PlayerGui"):WaitForChild("Mobile")

local activeDash -- {velocity, connection} of the local character's current dash

local function cancelDash()
	if not activeDash then return end
	activeDash.connection:Disconnect()
	activeDash.velocity:Destroy()
	activeDash = nil
end

-- Moves the local character along DashCurve. Called straight from input (predicted, so the dash
-- starts on the key press instead of a server round trip later) and by the server for DashAttack.
-- Other players' characters are moved by their own clients, so their dashes are ignored here.
local function applyDash(plr, relativeDir, dashTime, dashPower)
	if plr ~= player then return end
	local char = plr.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	local humanoid = char:WaitForChild("Humanoid")

	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment then return end
	
	cancelDash()
	
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = Vector3.new(math.huge, 0, math.huge)
	lv.Parent = root
	lv.Name = "DashVelocity"
	
	if not relativeDir then
		relativeDir = "Front"
	end

	local startTime = os.clock()
	local dash = {velocity = lv}

	dash.connection = game:GetService("RunService").RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= dashTime or not lv.Parent then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
			humanoid.AutoRotate = true
			dash.connection:Disconnect()
			lv:Destroy()
			if activeDash == dash then activeDash = nil end
			return
		end
		
		-- Recalculate direction every frame (STEERING)
		local look = root.CFrame.LookVector
		local right = root.CFrame.RightVector

		local dashDir
		if relativeDir == "Back" then
			dashDir = -look
		elseif relativeDir == "Right" then
			dashDir = right
		elseif relativeDir == "Left" then
			dashDir = -right
		else
			dashDir = look
		end
		
		lv.VectorVelocity = dashDir.Unit * DashCurve.Speed(elapsed / dashTime, dashPower, humanoid.WalkSpeed)
	end)
	activeDash = dash
end

local function killMomentum(char)
	local root = char:WaitForChild("HumanoidRootPart")
	for _, v in char:GetDescendants() do
		if v:IsA("LinearVelocity") then
			v:Destroy()
		end
	end
	root.AssemblyLinearVelocity = Vector3.zero
end

local function getDirection(char)
	local root = char:WaitForChild("HumanoidRootPart")

	local forward = 0
	local right = 0
	
	local direction

	if UIS:IsKeyDown(Enum.KeyCode.W) then forward += 1 direction = "Front"
	elseif UIS:IsKeyDown(Enum.KeyCode.S) then forward -= 1 direction = "Back"
	elseif UIS:IsKeyDown(Enum.KeyCode.D) then right += 1 direction = "Right"
	elseif UIS:IsKeyDown(Enum.KeyCode.A) then right -= 1 direction = "Left" else
		direction = "Front"
	end

	local moveVector = (root.CFrame.LookVector * forward) + (root.CFrame.RightVector * right)

	if moveVector.Magnitude == 0 then
		return root.CFrame.LookVector
	end

	return moveVector.Unit, direction
end

local function canDash(char)
	if char:FindFirstChild("Cooldowns"):FindFirstChild("Dash") then return false end
	if char:GetAttribute("Stun") == true then return false end
	if char:GetAttribute("HitStun") == true then return false end
	if char:GetAttribute("Ragdoll") == true then return false end
	if char:GetAttribute("Slow") == true then return false end
	if char:GetAttribute("UsingSkill") ~= false then return false end
	if char:GetAttribute("Blocking") == true then return false end
	--if char:GetAttribute("Airborne") == true then return false end
	return true
end

local function playDashAnimation(char, direction)
	local hum = char:WaitForChild("Humanoid")
	local animator = hum:FindFirstChildOfClass("Animator")
	

	local animFolder = script

	local anim
	
	if char:FindFirstChild("Passives"):FindFirstChild("Godspeed") and (direction == "Front" or direction == "Back") then return end

	if direction == "Front" then
		anim = animFolder.ForwardDash
	elseif direction == "Back" then
		anim = animFolder.BackwardDash
	elseif direction == "Right" then
		anim = animFolder.RightDash
	else
		anim = animFolder.LeftDash
	end

	local track = animator:LoadAnimation(anim)
	track:Play()
	track:AdjustSpeed(1.2)
end

local function invisCharacter(char, duration)
	for _, part in pairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency ~= 1 then
			part.Transparency = 1
			task.delay(duration, function()
				part.Transparency = 0
			end)
		end
	end
end

local function playVFX(char, direction)
	
	local sound = Instance.new("Sound", char:FindFirstChild("HumanoidRootPart")); game.Debris:AddItem(sound, 1)
	sound.SoundId = "rbxassetid://126862391298039"
	sound:Play()
	
	if char:FindFirstChild("Passives"):FindFirstChild("Godspeed") and (direction == "Front" or direction == "Back") then
		local fx = game.ReplicatedStorage.VFX["Flicker Dash"].VFXRoot:Clone(); game.Debris:AddItem(fx, 0.7)
		fx.CFrame = char.HumanoidRootPart.CFrame
		fx.Weld.Part1 = char.HumanoidRootPart
		fx.Parent = char
		
		local sound = script.FlickerDashSound:Clone(); game.Debris:AddItem(sound, 1); sound.Parent = char.HumanoidRootPart
		local sound2 = script.FlickerDashSound2:Clone(); game.Debris:AddItem(sound2, 1.5); sound2.Parent = char.HumanoidRootPart
		sound:Play()
		sound2:Play()
		
		for _, effect in fx:GetDescendants() do
			if effect:IsA("ParticleEmitter") and effect.Name == "Flash" then
				effect.Enabled = true
				task.delay(0.7, function()
					effect.Enabled = false
				end)
			elseif effect:IsA("ParticleEmitter") and effect.Name == "Impact" then
				effect:Emit(1)
			end
		end
		invisCharacter(char, 0.5)
		return
	end
	
	if direction == "Right" then
		local fx = script.AttachmentR:Clone()
		fx.Parent = char.HumanoidRootPart
		game.Debris:AddItem(fx, 0.5)
		for _, pe in fx:GetDescendants() do
			if pe.Name == "Smoke" then
				pe.Enabled = true
				task.delay(0.3, function()
					pe.Enabled = false
				end)
			else
				pe:Emit(1)
			end
		end
	elseif direction == "Left" then
		local fx = script.AttachmentL:Clone()
		fx.Parent = char.HumanoidRootPart
		game.Debris:AddItem(fx, 0.5)
		for _, pe in fx:GetDescendants() do
			if pe.Name == "Smoke" then
				pe.Enabled = true
				task.delay(0.3, function()
					pe.Enabled = false
				end)
			else
				pe:Emit(1)
			end
		end
	end
end

local function tryDash(char)
	if not canDash(char) then 
		evasiveRemote:FireServer(player)
		return
	end

	local direction, relativeDirection = getDirection(char)
	relativeDirection = relativeDirection or "Front"

	playDashAnimation(char, relativeDirection)
	playVFX(char, relativeDirection)

	-- Start moving now; the server only validates (and sends "Rejected" if it disagrees).
	-- Godspeed's front/back flicker dash is a speed boost (FlickerDashing), not a velocity burst.
	local flicker = char.Passives:FindFirstChild("Godspeed") and (relativeDirection == "Front" or relativeDirection == "Back")
	if not flicker then
		local power = DashCurve.Power(relativeDirection, char:GetAttribute("Amputate_Leg") == true)
		applyDash(player, relativeDirection, DashCurve.TIME, power)
	end
	DashRemote:FireServer(direction, relativeDirection)
end

UIS.InputBegan:Connect(function(input, typing)
	if typing then return end
	if input.KeyCode ~= Enum.KeyCode.Q then return end

	local char = player.Character
	if not char then return end
	
	if char:GetAttribute("WallRunning") == true then return end

	tryDash(char)
end)

mobileGui:FindFirstChild("Dash").Dash.TouchTap:Connect(function()
	local char = player.Character
	if not char then return end

	tryDash(char)
end)


local function applyKB(Char, dir, mag, duration)
	local root = Char:FindFirstChild("HumanoidRootPart")
	if not root then warn("[CombatValidation: KB] No root") return end

	-- Kill existing velocity first so KB is consistent regardless of prior momentum
	root.AssemblyLinearVelocity = Vector3.zero

	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment then warn("[CombatValidation: KB] No attach") return end

	local LV = Instance.new("LinearVelocity")
	LV.VectorVelocity = dir * mag  -- mag should always be positive
	LV.Attachment0 = attachment
	LV.MaxForce = math.huge        -- ignore mass, always apply full force
	LV.ForceLimitsEnabled = false  -- critical for consistency
	LV.RelativeTo = Enum.ActuatorRelativeTo.World
	LV.Parent = root

	game.Debris:AddItem(LV, duration)
end

DashRemote.OnClientEvent:Connect(function(plr, ...)
	if plr == "Rejected" then
		cancelDash() -- the server refused a dash this client had already started
		return
	end
	applyDash(plr, ...)
end)
KillDashRemote.OnClientEvent:Connect(killMomentum)
KnockBackRemote.OnClientEvent:Connect(applyKB)
DashEffect.OnClientEvent:Connect(playVFX)