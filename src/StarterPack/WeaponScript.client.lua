local UIS = game:GetService("UserInputService")


local Player = game.Players.LocalPlayer
local Char = Player.Character
local Hum = Char:WaitForChild("Humanoid")

local equipAnim = script.Equip:Clone()
local equipTrack = Hum:LoadAnimation(equipAnim)

local unequipTrack = Hum:LoadAnimation(script.Unequip:Clone())

local weaponToggle = game.ReplicatedStorage.RemoteEvents.ItemRelated.WeaponToggle

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.X and Char:GetAttribute("WeaponEquipped") == false then
		equipTrack:Play()
		equipTrack:GetMarkerReachedSignal("Fire"):Once(function()
			weaponToggle:FireServer("Equip")
		end)
	elseif input.KeyCode == Enum.KeyCode.X and Char:GetAttribute("WeaponEquipped") ~= false then
		unequipTrack:Play()
		unequipTrack:GetMarkerReachedSignal("Fire"):Once(function()
			weaponToggle:FireServer("Unequip")
		end)
	end
end)

