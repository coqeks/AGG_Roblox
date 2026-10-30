local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Player = Players.LocalPlayer
local Char = Player.Character or Player.CharacterAdded:Wait()

local mouse = Player:GetMouse()

local HoldSkill = Replicated.RemoteEvents.Combat.HoldSkill
local skillReplicator = Replicated:WaitForChild("RemoteEvents"):WaitForChild("SkillReplicator")

local SphereCast = require(Replicated.Modules.SphereCast)

local currentTool = nil
local inputConnection = nil
local inputEndConnection = nil

--////////////////////////////////////////////////////////////

local function LockOn(plr)
	local camera = workspace.CurrentCamera
	local mousePos = UIS:GetMouseLocation()

	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local result = SphereCast.Cast({
		origin = ray.Origin,
		direction = ray.Direction,
		radius = 5,
		maxDistance = 150,
		characterFolder = workspace.Alive,
		ignoreList = {plr.Character}
	})

	if result and result.Character then
		print("Locked onto:", result.Character.Name)
		return result.Character
	else
		print("No valid target found")
		return nil
	end
end

--////////////////////////////////////////////////////////////

local function cleanupConnections()

	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end

	if inputEndConnection then
		inputEndConnection:Disconnect()
		inputEndConnection = nil
	end

end

--////////////////////////////////////////////////////////////

local function useSkill(skill)
	local target = LockOn(Player)
	if target then
		skillReplicator:FireServer(skill, target)
	else
		skillReplicator:FireServer(skill)
	end
end

--////////////////////////////////////////////////////////////

HoldSkill.OnClientEvent:Connect(function(action, holdTime : number, skillKey : string)
	if action == "Hold" and holdTime and UIS:IsKeyDown(Enum.KeyCode[skillKey]) then
		local startTime = tick()
		inputConnection = UIS.InputEnded:Connect(function(input)
			if input.KeyCode == Enum.KeyCode[skillKey] then
				local elapsed = tick() - startTime
				if elapsed >= holdTime then
					useSkill(skillKey)
				end
			end
		end)
	end
end)

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.One then
		useSkill(1)
	elseif input.KeyCode == Enum.KeyCode.Two then
		useSkill(2)
	elseif input.KeyCode == Enum.KeyCode.Three then
		useSkill(3)
	elseif input.KeyCode == Enum.KeyCode.Four then
		useSkill(4)
	end
end)

local skillGUI = Player.PlayerGui:WaitForChild("ToolBar")
for _, button in skillGUI.Frame:GetDescendants() do
	if button:IsA("TextButton") then
		button.TouchTap:Connect(function()
			useSkill(tonumber(button.Name))
		end)
	end
end