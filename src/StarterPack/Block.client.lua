

local Player = game.Players.LocalPlayer
local Char = Player.Character or Player.CharacterAdded:Wait()
local UIS = game:GetService("UserInputService")

local requestConfig = game.ReplicatedStorage.RemoteEvents.Combat.RequestHBConfig
local blockRemote = game.ReplicatedStorage.RemoteEvents.Combat.Block

local blockingAnim = Instance.new("Animation")
blockingAnim.Name = "Blocking"
blockingAnim.AnimationId = "rbxassetid://121165347640078"

-- Only press/release is sent; the server (Combat.BlockService) remembers that F is held and
-- starts blocking by itself once stun, skills or the block cooldown end.
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.F then
		blockRemote:FireServer(true)
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then
		blockRemote:FireServer(false)
	end
end)

-- F held down while respawning
if UIS:IsKeyDown(Enum.KeyCode.F) then
	blockRemote:FireServer(true)
end

Char:GetAttributeChangedSignal("Blocking"):Connect(function()
	if Char:GetAttribute("Blocking") == true then
		Char.Humanoid:LoadAnimation(blockingAnim):Play()
	else
		local AnimTracks = Char.Humanoid:GetPlayingAnimationTracks()
		for i,v in pairs(AnimTracks) do
			if v.Name == "Blocking" then
				v:Stop()
			end
		end
	end
end)

requestConfig.OnClientEvent:Connect(function(config)
	print("Configuring blocking anim")
	local animName = config.WeaponClass
	blockingAnim = game.ReplicatedStorage.Animations.Combat[animName].Blocking
end)

