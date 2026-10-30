local player = game.Players.LocalPlayer
local character = player.Character
local humanoid = character:WaitForChild("Humanoid")

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local attachment = Instance.new("Attachment", character:WaitForChild("HumanoidRootPart"))
--attachment.Visible = true
attachment.CFrame = CFrame.new(0, 1.5, -2)

local attachment2 = Instance.new("Attachment", character:WaitForChild("HumanoidRootPart"))
--attachment2.Visible = true
attachment2.CFrame = CFrame.new(0, 4, -2)

local root = character:WaitForChild("HumanoidRootPart")
local vaulting = false
local ledging = false

local animation = Instance.new("Animation")
animation.AnimationId = "rbxassetid://99580836331892"
local animationTrack = humanoid:LoadAnimation(animation)
animationTrack.Priority = Enum.AnimationPriority.Action

local highAnimation = Instance.new("Animation")
highAnimation.AnimationId = "rbxassetid://139443862067487"
local highAnimationTrack = humanoid:LoadAnimation(highAnimation)
highAnimationTrack.Priority = Enum.AnimationPriority.Action

local ledgeAnimation = Instance.new("Animation")
ledgeAnimation.AnimationId = "rbxassetid://82118492718046"
local ledgeAnimationTrack = humanoid:LoadAnimation(ledgeAnimation)
ledgeAnimationTrack.Priority = Enum.AnimationPriority.Action

local raycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = {workspace.Alive}
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- After getting vaultRaycastResult, check for overhead obstruction
local function hasOverheadClearance(hitPosition, requiredHeight)
	local upwardCheck = workspace:Raycast(
		hitPosition,
		Vector3.new(0, requiredHeight, 0),
		raycastParams
	)
	return upwardCheck == nil -- nil means nothing blocking = clear
end

RunService.RenderStepped:Connect(function()
	local vaultRayOrigin = attachment.WorldPosition
	local ledgeRayOrigin = attachment2.WorldPosition
	local vaultRayDirection = Vector3.new(0, -6, 0)
	
	local vaultRaycastResult = workspace:Raycast(vaultRayOrigin, vaultRayDirection, raycastParams)
	local ledgeRaycastResult = workspace:Raycast(ledgeRayOrigin, vaultRayDirection, raycastParams)
	local reverseRaycastResult = workspace:Raycast(vaultRayOrigin, -vaultRayDirection, raycastParams)
	
	if ledgeRaycastResult 
		and ledgeRaycastResult.Distance < 3 
		and not vaulting 
		and not ledging 
		and character:GetAttribute("Airborne") == true
		and hasOverheadClearance(ledgeRaycastResult.Position, 5)
		and hasOverheadClearance(root.CFrame.Position, 5) then
		
		if ledgeRaycastResult.Instance.CanCollide == false then return end
		
		print("Ledging")
		ledgeRaycastResult.Instance.CanCollide = false
		ledging = true

		task.wait()

		local upwardVelocity = Instance.new("LinearVelocity");  Debris:AddItem(upwardVelocity,0.1)
		upwardVelocity.Attachment0 = root:FindFirstChild("RootAttachment")
		upwardVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		upwardVelocity.VectorVelocity = Vector3.new(0, math.min(50 / ledgeRaycastResult.Distance, 50), 0)
		upwardVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		upwardVelocity.MaxAxesForce = Vector3.new(0, 500000, 0)
		upwardVelocity.Parent = root

		task.delay(0.1, function()
			ledgeRaycastResult.Instance.CanCollide = true
		end)

		ledgeAnimationTrack:Play()

		task.wait(0.5)
		ledging = false
	elseif vaultRaycastResult 
		and vaultRaycastResult.Distance < 2.5 
		and not vaulting 
		and not ledging 
		and character:GetAttribute("Airborne") ~= true 
		and character:GetAttribute("Sprinting") == true
		and hasOverheadClearance(vaultRaycastResult.Position, 5) then
		
		if vaultRaycastResult.Instance.CanCollide == false then return end
		
		print("Vaultable")
		vaulting = true
		vaultRaycastResult.Instance.CanCollide = false
		
		task.wait()
		
		local forwardVelocity = Instance.new("LinearVelocity");  Debris:AddItem(forwardVelocity,0.4)
		forwardVelocity.Attachment0 = root:FindFirstChild("RootAttachment")
		forwardVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		forwardVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		forwardVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		forwardVelocity.MaxAxesForce = Vector3.new(40000, 0, 40000)
		forwardVelocity.Parent = root
		
		local upwardVelocity = Instance.new("LinearVelocity");  Debris:AddItem(upwardVelocity,0.05)
		upwardVelocity.Attachment0 = root:FindFirstChild("RootAttachment")
		upwardVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		upwardVelocity.VectorVelocity = Vector3.new(0, math.min(40 / vaultRaycastResult.Distance, 40), 0)
		upwardVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		upwardVelocity.MaxAxesForce = Vector3.new(0, 200000, 0)
		upwardVelocity.Parent = root
		print(50 / vaultRaycastResult.Distance)
		
		task.delay(0.05, function()
			forwardVelocity.VectorVelocity = root.CFrame.LookVector * 25
		end)
		task.delay(0.2, function()
			vaultRaycastResult.Instance.CanCollide = true
		end)
		
		if vaultRaycastResult.Distance < 0.5 then
			highAnimationTrack:Play()
		else
			animationTrack:Play()
		end
		
		task.wait(0.5)
		vaulting = false
	end
end)