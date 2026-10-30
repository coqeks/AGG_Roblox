local player = game.Players.LocalPlayer
local character = player.Character
local humanoid = character:WaitForChild("Humanoid")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Camera = workspace.CurrentCamera
local root = character:WaitForChild("HumanoidRootPart")

local wallRunning = false
local wallRunTimer = 0
local MAX_WALL_RUN_TIME = 1
local dashCooldown = false
local runCooldown = false

local MAX_DASHES = 2
local DASH_RECHARGE_TIME = 3
local dashesRemaining = MAX_DASHES
local recharging = false

local rightRunAnim = Instance.new("Animation")
rightRunAnim.AnimationId = "rbxassetid://105471288189698"
local rightRunTrack = humanoid:LoadAnimation(rightRunAnim)
rightRunTrack.Priority = Enum.AnimationPriority.Action4

local leftRunAnim = Instance.new("Animation")
leftRunAnim.AnimationId = "rbxassetid://83881887735396"
local leftRunTrack = humanoid:LoadAnimation(leftRunAnim)
leftRunTrack.Priority = Enum.AnimationPriority.Action4

local airDashAnim = Instance.new("Animation")
airDashAnim.AnimationId = "rbxassetid://94193945199049"
local airDashTrack = humanoid:LoadAnimation(airDashAnim)
airDashTrack.Priority = Enum.AnimationPriority.Action4

local function stopWallRun()
	print("Stopping")
	wallRunning = false
	wallRunTimer = 0
	rightRunTrack:Stop()
	leftRunTrack:Stop()
	dashCooldown = true
	task.delay(0.3, function()
		dashCooldown = false
	end)
end

local function clearLinearVelocities()
	for _, v in ipairs(root:GetChildren()) do
		if v:IsA("LinearVelocity") then
			v:Destroy()
		end
	end
end

local function startRecharge()
	if recharging then return end
	recharging = true
	task.delay(DASH_RECHARGE_TIME, function()
		dashesRemaining = MAX_DASHES
		print("Recharged")
		recharging = false
	end)
end

local function airDash()
	if dashesRemaining <= 0 then return end

	local camLook = Camera.CFrame.LookVector
	local dashDirection = Vector3.new(camLook.X, 0, camLook.Z).Unit

	clearLinearVelocities()
	stopWallRun()

	dashCooldown = true
	task.delay(0.3, function()
		dashCooldown = false
	end)
	
	airDashTrack:Play()

	dashesRemaining -= 1
	-- Begin the 5 s recharge as soon as the first dash is spent
	if dashesRemaining < MAX_DASHES then
		startRecharge()
	end

	local dashVelocity = Instance.new("LinearVelocity")
	dashVelocity.Attachment0 = root:FindFirstChild("RootAttachment")
	dashVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	dashVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	dashVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	dashVelocity.MaxAxesForce = Vector3.new(15000,20000,15000)
	dashVelocity.VectorVelocity = dashDirection * 80 + Vector3.new(0, 30, 0)
	dashVelocity.Parent = root
	Debris:AddItem(dashVelocity, 0.10)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Space and wallRunning then
		airDash()
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	local rayOrigin = root.CFrame.Position
	local rayDirection = root.CFrame.RightVector * 2
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {workspace.Alive}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local rightResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	local leftResult = workspace:Raycast(rayOrigin, -rayDirection, raycastParams)

	local normal = rightResult and rightResult.Normal or leftResult and leftResult.Normal or Vector3.new(0,0,0)

	if wallRunning then
		wallRunTimer += deltaTime
		if wallRunTimer >= MAX_WALL_RUN_TIME then
			stopWallRun()
			return
		end
	end

	if (rightResult or leftResult) 
		and not wallRunning 
		and not dashCooldown 
		and normal.Y == 0 
		and character:GetAttribute("Airborne") == true
		and not runCooldown then
		local wallDirection = rightResult and normal:Cross(Vector3.new(0,1,0)) or leftResult and normal:Cross(Vector3.new(0,-1,0))

		if rightResult then
			if UserInputService:IsKeyDown(Enum.KeyCode.D) ~= true then
				return
			end
			if rightRunTrack.IsPlaying == false then
				rightRunTrack:Play()
			end
		elseif leftResult then
			if UserInputService:IsKeyDown(Enum.KeyCode.A) ~= true then
				return
			end
			if leftRunTrack.IsPlaying == false then
				leftRunTrack:Play()
			end
		end
		
		if not character:GetAttribute("WallRunning") then
			character:SetAttribute("WallRunning", true)
		end

		wallRunning = true

		local forwardVelocity = Instance.new("LinearVelocity") ; Debris:AddItem(forwardVelocity, 0.1)
		forwardVelocity.Attachment0 = root:FindFirstChild("RootAttachment")
		forwardVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		forwardVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		forwardVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		forwardVelocity.MaxAxesForce = Vector3.new(50000, 0, 50000)
		forwardVelocity.VectorVelocity = wallDirection * 35
		forwardVelocity.Parent = root

		local downwardVelocity = Instance.new("LinearVelocity") ; Debris:AddItem(downwardVelocity, 0.1)
		downwardVelocity.Attachment0 = root:FindFirstChild("RootAttachment")
		downwardVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		downwardVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		downwardVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		downwardVelocity.MaxAxesForce = Vector3.new(0, 50000, 0)
		downwardVelocity.VectorVelocity = Vector3.new(0, -3, 0)
		downwardVelocity.Parent = root

		task.wait(0.1)
		wallRunning = false

	elseif not wallRunning and not (rightResult or leftResult) or character:GetAttribute("Airborne") ~= true then
		rightRunTrack:Stop()
		leftRunTrack:Stop()
		character:SetAttribute("WallRunning", false)
	end
end)