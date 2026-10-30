-- Marks admins (player attribute IsAdmin) and applies dev flag changes sent from the Admin panel.

local Players = game:GetService("Players")
local AdminConfig = require(game.ServerScriptService.Config.AdminConfig)
local Manager = require(game.ServerScriptService.PlayerData.Manager)

local setFlagRemote = game.ReplicatedStorage.RemoteEvents.Admin.SetDevFlag
local notification = game.ReplicatedStorage.RemoteEvents.GUI.Notification

-- Publish flag descriptions for the client panel
local descriptions = AdminConfig.FlagFolder:FindFirstChild("Descriptions") or Instance.new("Configuration")
descriptions.Name = "Descriptions"
for name, text in AdminConfig.Flags do
	descriptions:SetAttribute(name, text)
	if AdminConfig.FlagFolder:GetAttribute(name) == nil then
		AdminConfig.FlagFolder:SetAttribute(name, false)
	end
end
descriptions.Parent = AdminConfig.FlagFolder

local function onPlayerAdded(player)
	player:SetAttribute("IsAdmin", AdminConfig.IsAdmin(player))
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

setFlagRemote.OnServerEvent:Connect(function(player, flagName, value)
	if not AdminConfig.IsAdmin(player) then return end
	if typeof(flagName) ~= "string" or AdminConfig.Flags[flagName] == nil then return end
	if typeof(value) ~= "boolean" then return end

	AdminConfig.SetFlag(flagName, value)
	print("[AdminService]", player.Name, "set", flagName, "=", value)
	notification:FireClient(player, "General", "- " .. flagName .. (value and " ON" or " OFF") .. " -", Color3.fromRGB(255, 170, 0), nil, 2)

	-- Skill toolbars show unlocked skills, so refresh everyone when the unlock flag changes
	if flagName == "FreeSkillUnlocks" then
		for _, plr in Players:GetPlayers() do
			Manager.PushSkillList(plr)
		end
	end
end)
