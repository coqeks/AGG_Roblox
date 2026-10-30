--// Services
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

--// Modules
local RagdollModule = {}
RagdollModule.PlayersCollisionGroup = "Players" -->> idk, if u have another name for the players collision group just change it
RagdollModule.CanCollide = false -->> set true if you want the parts to collide with each other

if not PhysicsService:IsCollisionGroupRegistered(RagdollModule.PlayersCollisionGroup) then
	local CollisionGroup = PhysicsService:RegisterCollisionGroup(RagdollModule.PlayersCollisionGroup)
end

if not PhysicsService:IsCollisionGroupRegistered("Uncollidable") then
	local CollisionGroup = PhysicsService:RegisterCollisionGroup("Uncollidable")
end

PhysicsService:CollisionGroupSetCollidable("Uncollidable", RagdollModule.PlayersCollisionGroup, false)

--// Main Function's
function RagdollModule:Ragdoll(Character: Model)
	local IsNpc = Players:GetPlayerFromCharacter(Character) == nil
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")

	if not Humanoid then return end

	for _, Animation in Humanoid.Animator:GetPlayingAnimationTracks() do
		Animation:Stop()
	end

	--Character:SetAttribute("Ragdoll", true)

	Humanoid.BreakJointsOnDeath = false
	Humanoid.AutoRotate = false
	Humanoid.RequiresNeck = true

	Humanoid.WalkSpeed = 0
	Humanoid.JumpPower = 0

	--[[if Character:GetAttribute("CanMove") then
		Humanoid.WalkSpeed = 0
		Humanoid.JumpPower = 0
	end]]

	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	Character:FindFirstChild("HumanoidRootPart").CanCollide = false

	if IsNpc then
		Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
	end

	self:ReplaceJoints(Character)
end

function RagdollModule:unRagdoll(Character : Model)
	local IsNpc = Players:GetPlayerFromCharacter(Character) == nil
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")

	if not Humanoid then return end
	if Humanoid.Health <= 0.1 then return end

	--Character:SetAttribute("Ragdoll", false)

	Humanoid.AutoRotate = true
	Humanoid.RequiresNeck = false

	Humanoid.WalkSpeed = 16
	Humanoid.JumpPower = 50

	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

	Character:FindFirstChild("HumanoidRootPart").CanCollide = true

	if IsNpc then
		Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	self:ResetJoints(Character)
end

--// Attachments CFrame's
local AttachmentCFrames = {
	["Neck"] = {CFrame.new(0, 1, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1), CFrame.new(0, -0.5, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1)},
	["Left Shoulder"] = {CFrame.new(-1.3, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1), CFrame.new(0.2, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1)},
	["Right Shoulder"] = {CFrame.new(1.3, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), CFrame.new(-0.2, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)},
	["Left Hip"] = {CFrame.new(-0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1), CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1)},
	["Right Hip"] = {CFrame.new(0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1), CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1)},
}

local RagdollInstanceNames = {
	["RagdollAttachment"] = true,
	["RagdollConstraint"] = true,
	["ColliderPart"] = true,
}


function RagdollModule:CreateColliderPart(Part: BasePart)
	if not Part then return end
	local RagdollColliderPart = Instance.new("Part")
	RagdollColliderPart.Name = "ColliderPart"
	RagdollColliderPart.Size = Part.Size / 1.7
	RagdollColliderPart.Massless = true			
	RagdollColliderPart.CFrame = Part.CFrame
	RagdollColliderPart.Transparency = 1

	RagdollColliderPart.CollisionGroup = "Uncollidable"

	local WeldConstraint = Instance.new("WeldConstraint")
	WeldConstraint.Part0 = RagdollColliderPart
	WeldConstraint.Part1 = Part

	WeldConstraint.Parent = RagdollColliderPart
	RagdollColliderPart.Parent = Part
end


function RagdollModule:ReplaceJoints(Character: Model)
	local Humanoid : Humanoid = Character:FindFirstChildWhichIsA("Humanoid")

	for _, Motor: Motor6D in Character:GetDescendants() do
		if Motor:IsA("Motor6D") then
			if not AttachmentCFrames[Motor.Name] then continue end
			Motor.Enabled = false
			local Attachment0, Attachment1 = Instance.new("Attachment"), Instance.new("Attachment")
			Attachment0.CFrame = AttachmentCFrames[Motor.Name][1]
			Attachment1.CFrame = AttachmentCFrames[Motor.Name][2]

			Attachment0.Name = "RagdollAttachment"
			Attachment1.Name = "RagdollAttachment"

			self:CreateColliderPart(Motor.Part1)

			local BallSocketConstraint = Instance.new("BallSocketConstraint")
			BallSocketConstraint.Attachment0 = Attachment0
			BallSocketConstraint.Attachment1 = Attachment1
			BallSocketConstraint.Name = "RagdollConstraint"

			BallSocketConstraint.Radius = 0.15
			BallSocketConstraint.LimitsEnabled = true
			BallSocketConstraint.TwistLimitsEnabled = true
			BallSocketConstraint.MaxFrictionTorque = 0
			BallSocketConstraint.Restitution = 0
			BallSocketConstraint.UpperAngle = 45
			BallSocketConstraint.TwistLowerAngle = -70
			BallSocketConstraint.TwistUpperAngle = 70
			BallSocketConstraint.Restitution = 0

			Attachment0.Parent = Motor.Part0
			Attachment1.Parent = Motor.Part1
			BallSocketConstraint.Parent = Motor.Parent
		end
	end
end

function RagdollModule:ResetJoints(Character: Model)
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")

	if Humanoid then	
		if Humanoid.Health < 0.1 then return end
		for _, Instance in Character:GetDescendants() do
			if RagdollInstanceNames[Instance.Name] then
				Instance:Destroy()
			end

			if Instance:IsA("Motor6D") then
				Instance.Enabled = true
			end
		end
	end
end

return RagdollModule