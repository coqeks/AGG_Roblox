local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local stateManager = require(game.ServerScriptService.PlayerStates.StateManager)
local DashRemote = ReplicatedStorage.RemoteEvents.Movement.DashEvent
local DashEffect = ReplicatedStorage.RemoteEvents.Effects.Dash
local DashCurve = require(ReplicatedStorage.Modules.DashCurve)


local DASH_TIME = DashCurve.TIME
local DASH_CD = DashCurve.COOLDOWN

local RELATIVE_DIRECTIONS = {Front = true, Back = true, Left = true, Right = true}

local function validateDash(char)
	if stateManager:CheckCooldown(char, "Dash") then return false end
	if stateManager:HasState(char, "Stun") then return false end
	if stateManager:HasState(char, "HitStun") then return false end
	if stateManager:HasState(char, "Ragdoll") then return false end
	if stateManager:HasState(char, "Slow") then return false end
	if stateManager:HasState(char, "UsingSkill") then return false end
	if stateManager:HasState(char, "Blocking") then return false end
	return true
end

DashRemote.OnServerEvent:Connect(function(player, direction, relativeDirection)
	if typeof(direction) ~= "Vector3" then return end
	if direction.Magnitude == 0 then return end

	local char = player.Character
	if not char then return end

	if not validateDash(char) then
		-- The client starts its dash on the key press, so tell it to stop
		DashRemote:FireClient(player, "Rejected")
		return
	end
	
	direction = direction.Unit
	
	if not RELATIVE_DIRECTIONS[relativeDirection] then relativeDirection = "Front" end
	
	if char:FindFirstChild("Passives"):FindFirstChild("Godspeed") and (relativeDirection == "Front" or relativeDirection == "Back") then
		stateManager:AddCooldown(char, "Dash", DASH_CD + 1)
		stateManager:AddState(char, "FlickerDashing", DASH_TIME)
		stateManager:AddState(char, "Dashing", DASH_TIME - 0.25)
		stateManager:AddState(char, "JumpLock", DASH_TIME)
		stateManager:AddState(char, "IFrame", 0.1)
		return
	end

	stateManager:AddCooldown(char, "Dash", DASH_CD)
	stateManager:AddState(char, "Dashing", DASH_TIME - 0.25)
	stateManager:AddState(char, "JumpLock", DASH_TIME)
	
	-- The dashing client already moved itself (DashCurve); other clients only need the VFX
	if stateManager:HasState(char, "Amputate_Leg") then
		stateManager:AddCooldown(char, "Dash", DASH_CD + 1)
	else
		stateManager:AddState(char, "IFrame", 0.1)
	end
	
	for _, other in Players:GetPlayers() do
		if other ~= player then
			DashEffect:FireClient(other, char, relativeDirection)
		end
	end
end)
