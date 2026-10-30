-- Single server-side weapon model handler (replaces the per-player StarterPack.WeaponScript.WeaponServer copies).
-- Equip   -> weapon model welded to the Right Arm, WeaponEquipped = weapon name
-- Unequip -> weapon model strapped to the Torso, WeaponEquipped = false

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local StateService = require(game.ServerScriptService.PlayerStates.StateManager)
local ProfileManager = require(game.ServerScriptService.PlayerData.Manager)

local Remote = game.ReplicatedStorage.RemoteEvents.ItemRelated.WeaponToggle

local motors = {} -- [char] = {Motor6D}

local function clearWeapon(char)
	for _, child in char:GetChildren() do
		if child.Name == "Handle" then
			child:Destroy()
		end
	end
	for _, motor in motors[char] or {} do
		motor:Destroy()
	end
	motors[char] = {}
end

-- jointName is "Grip" (held) or "Strap" (on the back); both are CFrame holders inside the weapon model
local function attachWeapon(char, weaponName, partName, jointName)
	local model = weaponName and ServerStorage.WeaponModels:FindFirstChild(weaponName)
	local part = char:FindFirstChild(partName)
	if not model or not part then return end
	if not model:FindFirstChild(jointName) then
		warn("[WeaponEquipService] " .. weaponName .. " has no " .. jointName .. " joint data")
		return
	end

	clearWeapon(char)

	local handle = model:Clone()
	handle.Anchored = false
	handle.Name = "Handle"
	handle.Parent = char

	local grip = Instance.new("Motor6D")
	grip.Name = "Grip"
	grip.Part0 = part
	grip.Part1 = handle
	grip.C0 = handle[jointName].C0
	grip.C1 = handle[jointName].C1
	if partName == "Left Arm" then
		grip.C1 = grip.C1 * CFrame.Angles(0, math.rad(180), 0)
	end
	grip.Parent = part
	table.insert(motors[char], grip)
end

local function strapWeapon(plr)
	local char = plr.Character
	local data = ProfileManager.GetData(plr)
	if not char or not data then return end
	char:WaitForChild("Torso", 5)
	attachWeapon(char, data.EquippedWeapon, "Torso", "Strap")
end

Remote.OnServerEvent:Connect(function(plr, action)
	local char = plr.Character
	local data = ProfileManager.GetData(plr)
	if not char or not data then return end

	if action == "Equip" then
		StateService:AddState(char, "WeaponEquipped", nil, data.EquippedWeapon)
		attachWeapon(char, data.EquippedWeapon, "Right Arm", "Grip")
	elseif action == "Unequip" then
		StateService:RemoveState(char, "WeaponEquipped")
		attachWeapon(char, data.EquippedWeapon, "Torso", "Strap")
	end
end)

-- Strap the weapon on every spawn once the profile exists (first spawn is covered by ProfileLoaded)
local function onCharacterAdded(plr, char)
	char.Destroying:Connect(function()
		motors[char] = nil
	end)
	if ProfileManager.GetData(plr) then
		strapWeapon(plr)
	end
end

ProfileManager.ProfileLoaded.Event:Connect(function(plr)
	strapWeapon(plr)
end)

local function onPlayerAdded(plr)
	plr.CharacterAdded:Connect(function(char)
		onCharacterAdded(plr, char)
	end)
	if plr.Character then
		onCharacterAdded(plr, plr.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, plr in Players:GetPlayers() do
	onPlayerAdded(plr)
end
