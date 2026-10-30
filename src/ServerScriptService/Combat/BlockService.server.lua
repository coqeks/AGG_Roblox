-- Single server-side block handler (replaces the per-player StarterPack.Block.RemoteEvent.BlockServer copies).
-- The client only sends F pressed (true) / released (false). While F is held, the server keeps the
-- intent and starts blocking as soon as whatever prevented it (stun, skill, dash, block cooldown) ends.

local Players = game:GetService("Players")

local stateManager = require(game.ServerScriptService.PlayerStates.StateManager)
local dataManager = require(game.ServerScriptService.PlayerData.Manager)
local weaponConfig = require(game.ServerScriptService.Config.WeaponConfig)

local blockRemote = game.ReplicatedStorage.RemoteEvents.Combat.Block
local blockEvent = game.ReplicatedStorage.Bindables.BlockedHit
local blockEffect = game.ReplicatedStorage.RemoteEvents.Effects.BlockEffect

-- States that prevent blocking; when one of them changes we retry if the player is still holding F
local RETRY_STATES = {"Stun", "HitStun", "Ragdoll", "UsingSkill", "Blocking"}

local blockHeld = {} -- [char] = true while the owning player holds F

------------------------------------------------
-- Initiate Blocking State
------------------------------------------------
local function canBlock(char)
	return stateManager:CheckCooldown(char, "Block") == false
		and stateManager:CheckStun(char) == false
		and not stateManager:HasState(char, "Blocking")
		and not stateManager:HasState(char, "UsingSkill")
end

local function tryStartBlock(char)
	if not blockHeld[char] or not char.Parent then return end
	if canBlock(char) then
		stateManager:AddState(char, "Blocking")
		stateManager:AddState(char, "PBFrame", 0.2)
	end
end

local function stopBlock(char)
	if stateManager:HasState(char, "Blocking") == true then
		stateManager:RemoveState(char, "Blocking")
		stateManager:AddCooldown(char, "Block", 0.2)
	end
end

local function hookCharacter(char)
	for _, stateName in RETRY_STATES do
		char:GetAttributeChangedSignal(stateName):Connect(function()
			if blockHeld[char] then
				task.defer(tryStartBlock, char)
			end
		end)
	end

	local cooldowns = char:WaitForChild("Cooldowns", 10)
	if cooldowns then
		cooldowns.ChildRemoved:Connect(function(cd)
			if cd.Name == "Block" and blockHeld[char] then
				task.defer(tryStartBlock, char)
			end
		end)
	end

	char.Destroying:Connect(function()
		blockHeld[char] = nil
	end)
end

blockRemote.OnServerEvent:Connect(function(plr, held)
	if typeof(held) ~= "boolean" then return end
	local char = plr.Character
	if not char then return end

	if held then
		blockHeld[char] = true
		tryStartBlock(char)
	else
		blockHeld[char] = nil
		stopBlock(char)
	end
end)

local function onCharacterAdded(char)
	task.spawn(hookCharacter, char)
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(onCharacterAdded)
end)
for _, plr in Players:GetPlayers() do
	plr.CharacterAdded:Connect(onCharacterAdded)
	if plr.Character then onCharacterAdded(plr.Character) end
end

------------------------------------------------
-- When an attack is blocked
------------------------------------------------

local function findConfig(char)
	return weaponConfig.Preset(char:GetAttribute("WeaponEquipped"))
end

blockEvent.Event:Connect(function(char, hitter, damage)
	local player = Players:GetPlayerFromCharacter(char)
	if player then
		dataManager.AdjustCombatExp(player, 10)
	end

	local hitterConfig = findConfig(hitter)
	if hitterConfig then
		stateManager:AddCooldown(hitter, "M1", hitterConfig.EndLag)
	end

	blockEffect:FireAllClients(char, findConfig(char))
end)
