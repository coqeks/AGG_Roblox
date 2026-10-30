----- Loaded Modules -----

local ProfileService = require(game.ServerScriptService.ProfileService)
local PlayerTemplate = require(game.ServerScriptService.PlayerData.PlayerTemplate)
local StateService = require(game.ServerScriptService.PlayerStates.StateManager)
local Manager = require(game.ServerScriptService.PlayerData.Manager)
local Players = game:GetService("Players")
local leaveEvent = game.ReplicatedStorage.Bindables.LeaveProcessed

----- Constants -----

local PROFILE_KEY = "Beta7"
local ProfileStore = ProfileService.GetProfileStore(PROFILE_KEY, PlayerTemplate)

----- Runtime Storage -----

local Profiles = {} -- [player] = profile

----- Private Functions -----

local function CreateLeaderstats(player: Player)
	local profile = Manager.Profiles[player]
	if not profile then return end

	local leaderstats = Instance.new("Folder", player)
	leaderstats.Name = "leaderstats"

	local Kills = Instance.new("IntValue", leaderstats)
	Kills.Name = "Kills"
	Kills.Value = profile.Data.PlayerKills
	
	local Streak = Instance.new("IntValue", leaderstats)
	Streak.Name = "Streak"
	Streak.Value = 0

end

-- Recursive function to reconcile nested tables
local function ReconcileDeep(data, template)
	for key, defaultValue in template do
		if data[key] == nil then
			-- Key missing from profile, set to default
			if type(defaultValue) == "table" then
				data[key] = {}
				ReconcileDeep(data[key], defaultValue)
			else
				warn("Missing key '" .. key .. "', setting to default: " .. tostring(defaultValue))
				data[key] = defaultValue
			end
		elseif type(defaultValue) == "table" and type(data[key]) == "table" then
			-- Key exists and is a table, recurse into it
			ReconcileDeep(data[key], defaultValue)
		end
	end
end

-- Pass 1: Remove keys that no longer exist in the template
local function CleanOldKeys(data, template, path)
	path = path or ""
	for key, value in data do
		local fullPath = path ~= "" and (path .. "." .. key) or key
		if template[key] == nil then
			warn("Cleaning old key: " .. fullPath)
			data[key] = nil
		elseif type(value) == "table" and type(template[key]) == "table" then
			CleanOldKeys(value, template[key], fullPath)
		end
	end
end

----- Player Added -----

local function PlayerAdded(player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)

	if not profile then
		player:Kick("Data failed to load. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile:ListenToRelease(function()
		Profiles[player] = nil
		player:Kick("Profile loaded elsewhere.")
	end)
	
	--CleanOldKeys(profile.Data, PlayerTemplate)
	ReconcileDeep(profile.Data, PlayerTemplate)

	if player:IsDescendantOf(Players) then
		Manager.Profiles[player] = profile
		print("Profile loaded for", player.Name)
		print(profile.Data)
		player:LoadCharacterAsync()
		Manager.ProfileLoaded:Fire(player, profile.Data)
		CreateLeaderstats(player)
		Manager.UpdateGUI(player) --// initial gui update
		Manager.AdjustGold(player, 0)
		game.ReplicatedStorage.RemoteEvents.GUI.UpdateCurrency:FireClient(player, "Level", profile.Data.Level)
	else
		profile:Release()
		return
	end

end

----- Player Removing -----

local function PlayerRemoving(player)
	local profile = Profiles[player]
	if not profile then return end

	profile:Release()
	Profiles[player] = nil
end

----- Initialize -----

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(PlayerAdded, player)
end

Players.PlayerAdded:Connect(PlayerAdded)
--Players.PlayerRemoving:Connect(PlayerRemoving)
leaveEvent.Event:Connect(PlayerRemoving)