local player = game.Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local localPlayer = game.Players.LocalPlayer

local awakenEvent = game.ReplicatedStorage.RemoteEvents.Combat.Awaken

awakenEvent.OnClientEvent:Connect(function(player, stage)
	
	local char = player.Character
	
	local music = script.music:Clone(); Debris:AddItem(music, 121)
	music.Parent = char.HumanoidRootPart
	local cc = script.ColorCorrection:Clone() ; Debris:AddItem(cc, 121)
	
	if player == localPlayer then
		cc.Parent = game.Lighting
		
		local gui = player.PlayerGui.Awakening:Clone()
		gui.Parent = player.PlayerGui
		gui.Enabled = false
		task.wait(6)
		gui.Enabled = true
		TweenService:Create(gui.Frame.TextLabel, TweenInfo.new(2), {TextTransparency = 0}):Play()
		task.wait(2)
		TweenService:Create(gui.Frame.TextLabel, TweenInfo.new(2), {TextTransparency = 1}):Play()
		TweenService:Create(gui.Background, TweenInfo.new(5), {BackgroundTransparency = 1}):Play()
		
		task.delay(5, function()
			gui.Enabled = false
		end)
		
		music.Parent = game.SoundService
		
		game.Players.LocalPlayer.CharacterRemoving:Connect(function()
			cc:Destroy()
			music:Destroy()
		end)
	end
	
	local heartbeat = script.Sound:Clone()
	local vfx = script.VFX:Clone() ; Debris:AddItem(vfx, 121)

	vfx.Anchored = false
	
	local weld = Instance.new("Weld")
	weld.Parent = char.HumanoidRootPart
	weld.Part0 = char.HumanoidRootPart
	weld.Part1 = vfx
	weld.C1 = CFrame.new(0, -0.3, 0)
	vfx.Parent = char
	
	heartbeat.Parent = char.HumanoidRootPart
	heartbeat:Play()
	game.Debris:addItem(heartbeat, 15)
	TweenService:Create(heartbeat, TweenInfo.new(5), {Volume = 0.5}):Play()
	
	music:Play()
	
	for _, pe in vfx.Heart:GetChildren() do
		pe.Enabled = true
	end
	
	vfx.Heart.Parent = char.Torso
	
	task.delay(3, function()
		for _, pe in vfx:GetDescendants() do
			if pe:IsA("ParticleEmitter") then
				pe.Enabled = true
			end
		end
		for _, part in char:GetChildren() do
			if part:IsA("Part") then
				local pe = script.Aura1:Clone() ; Debris:AddItem(pe, 121)
				local pe2 = script.Aura2:Clone() ; Debris:AddItem(pe2, 121)
				pe.Parent = part
				pe2.Parent = part
			end
		end
	end)
end)