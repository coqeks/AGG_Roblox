-- Knockback and momentum stops for any character in workspace.Alive.
-- Clients apply knockback to the characters they simulate (DashClient's applyKB, via Movement.KnockBack).
-- PvE entities (tag "Entity") are simulated by the server, so the server applies it to them as well.

local Debris = game:GetService("Debris")

local knockBackRemote    = game.ReplicatedStorage.RemoteEvents.Movement.KnockBack
local killMomentumRemote = game.ReplicatedStorage.RemoteEvents.Movement.KillDashEvent

local Knockback = {}

local function isServerSimulated(char)
	return char:HasTag("Entity")
end

function Knockback.Apply(target, direction, magnitude, duration)
	knockBackRemote:FireAllClients(target, direction, magnitude, duration)
	if not isServerSimulated(target) then return end

	local root = target:FindFirstChild("HumanoidRootPart")
	local attachment = root and root:FindFirstChild("RootAttachment")
	if not attachment then return end

	-- Same as DashClient's applyKB
	root.AssemblyLinearVelocity = Vector3.zero
	local velocity = Instance.new("LinearVelocity")
	velocity.VectorVelocity = direction * magnitude
	velocity.Attachment0 = attachment
	velocity.ForceLimitsEnabled = false
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.Parent = root
	Debris:AddItem(velocity, duration)
end

-- Cancels dashes and knockback on the character
function Knockback.StopMomentum(char)
	killMomentumRemote:FireAllClients(char)
	if not isServerSimulated(char) then return end

	for _, child in char:GetDescendants() do
		if child:IsA("LinearVelocity") then
			child:Destroy()
		end
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

return Knockback
