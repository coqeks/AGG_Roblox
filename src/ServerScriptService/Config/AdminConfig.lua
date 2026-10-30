-- Admin list and testing (dev) flags.
-- Flags live as attributes on ReplicatedStorage.DevFlags so the admin panel can show them.
-- Each server starts with the values saved on DevFlags in the place file (all false);
-- admins flip them from the in-game Admin panel.

local RunService = game:GetService("RunService")

local AdminConfig = {}

AdminConfig.AdminUserIds = {
	[212183400] = true, -- iZkoi (game owner)
}

-- name -> description shown in the admin panel
AdminConfig.Flags = {
	FreeSkillUnlocks = "Skills 1-3 count as unlocked for everyone (not saved to profiles).",
	ShortSkillCooldowns = "All skill cooldowns become 3 seconds.",
	AnyWeapon = "Players can equip any weapon, even skins they don't own.",
}

AdminConfig.FlagFolder = game.ReplicatedStorage:WaitForChild("DevFlags")

function AdminConfig.IsAdmin(player: Player)
	if RunService:IsStudio() then return true end
	if AdminConfig.AdminUserIds[player.UserId] then return true end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
	return false
end

function AdminConfig.GetFlag(name: string): boolean
	return AdminConfig.FlagFolder:GetAttribute(name) == true
end

function AdminConfig.SetFlag(name: string, value: boolean)
	if AdminConfig.Flags[name] == nil then return end
	AdminConfig.FlagFolder:SetAttribute(name, value)
end

return AdminConfig
