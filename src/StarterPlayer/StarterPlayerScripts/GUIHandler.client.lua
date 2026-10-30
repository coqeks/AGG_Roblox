local Topbar = require(game.ReplicatedStorage.Modules.Icon)
local TweenService = game:GetService("TweenService")

local player = game.Players.LocalPlayer
local StatGUI = player.PlayerGui:WaitForChild("Stats")
local ShopGUI = player.PlayerGui:WaitForChild("Shop")
local InvenGUI = player.PlayerGui:WaitForChild("Inventory")
local killLog = player.PlayerGui:WaitForChild("KillLog")
local SpawnGUI = player.PlayerGui:WaitForChild("Spawn")
local toolBar = player.PlayerGui:WaitForChild("ToolBar")
local notif = player.PlayerGui:WaitForChild("Notif")
local Currency = player.PlayerGui:WaitForChild("Currency")
local guideGUI = player.PlayerGui:WaitForChild("Guide")

local updateRemote = game.ReplicatedStorage.RemoteEvents.GUI.UpdateStats
local updatePassive = game.ReplicatedStorage.RemoteEvents.GUI.UpdatePassive
local killLogRemote = game.ReplicatedStorage.RemoteEvents.GUI.KillLog
local getSkills = game.ReplicatedStorage.RemoteEvents.PlayerData.GetSkills
local getWeaponSkins = game.ReplicatedStorage.RemoteEvents.PlayerData.GetWeaponSkins
local changeWeapon = game.ReplicatedStorage.RemoteEvents.PlayerData.ChangeWeapon
local configAnim = game.ReplicatedStorage.Bindables.ConfigAnim
local notification = game.ReplicatedStorage.RemoteEvents.GUI.Notification
local buyWeaponSkin = game.ReplicatedStorage.RemoteEvents.PlayerData.BuyWeaponSkin
local weaponToggle = game.ReplicatedStorage.RemoteEvents.ItemRelated.WeaponToggle

-- ─── Topbar Icons (one-time setup, these persist) ────────────────────────────
local statIcon = Topbar.new()
local weaponIcon = Topbar.new()
local shopIcon = Topbar.new()
local invenIcon = Topbar.new()
local helpIcon = Topbar.new()

game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

statIcon:setImage(8587689304)
statIcon:setLabel("Stats", "Viewing")

shopIcon:setImage(11385395241)
shopIcon:setLabel("Shop", "Viewing")

invenIcon:setImage(83588998609796)
invenIcon:setLabel("Inventory", "Viewing")

helpIcon:setImage(12905962634)
helpIcon:setLabel("Guide", "Viewing")

local sword = Topbar.new():setLabel("Sword")
local dagger = Topbar.new():setLabel("Dagger")

weaponIcon:setImage(7485051715)
weaponIcon:setLabel("Weapon", "Viewing"):setDropdown({ sword, dagger })

sword.selected:Connect(function()
	changeWeapon:FireServer("Iron Gladius")
	local ws = player.Backpack:FindFirstChild("WeaponScript")
	if ws then ws.WeaponServer:FireServer("Unequip") end
	configAnim:Fire("Default")
end)

dagger.selected:Connect(function()
	changeWeapon:FireServer("Iron Dagger")
	local ws = player.Backpack:FindFirstChild("WeaponScript")
	if ws then ws.WeaponServer:FireServer("Unequip") end
	configAnim:Fire("Default")
end)

for _, icon in Topbar.getIcons() do
	icon:setTextFont("PressStart2P")
end

statIcon.selected:Connect(function()
	StatGUI.Enabled = true 
	statIcon:clearNotices()
end)
statIcon.deselected:Connect(function() StatGUI.Enabled = false end)

shopIcon.selected:Connect(function()
	ShopGUI.Enabled = true
end)
shopIcon.deselected:Connect(function() ShopGUI.Enabled = false end)

invenIcon.selected:Connect(function()
	InvenGUI.Enabled = true
	getWeaponSkins:FireServer()
end)
invenIcon.deselected:Connect(function() InvenGUI.Enabled = false end) 

local guideText = "Controls\nX - Equip/Unequip weapon\nM1 - Attack\nF - Block\nR - Critical Attack\n1, 2, 3, 4 - Abilities\n\nLevels\nEngage in combat for experience and levels\nNew abilities unlock on certain levels\nAllocate stat points you gained from leveling to customize build"
guideGUI:FindFirstChild("Main"):FindFirstChild("ScrollingFrame"):FindFirstChild("TextBox").Text = guideText

helpIcon.selected:Connect(function()
	guideGUI.Enabled = true
end)
helpIcon.deselected:Connect(function() guideGUI.Enabled = false end)

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function typeWrite(textLabel, text)
	textLabel.Text = ""
	local sound = game.SoundService.Typewrite:Clone()
	sound.Parent = game.SoundService
	sound:Play()
	for i = 1, #text do
		textLabel.Text = textLabel.Text .. string.sub(text, i, i)
		task.wait(0.05)
	end
	sound:Destroy()
end

-- ─── Stat GUI buttons (one-time, GUI persists across respawns) ───────────────
for _, elm in StatGUI:GetDescendants() do
	if elm:IsA("ImageButton") then
		elm.MouseButton1Click:Connect(function()
			local statName = elm:GetAttribute("stat")
			if not statName then return end
			game.ReplicatedStorage.RemoteEvents.PlayerData.StatUpdate:FireServer(statName)
		end)
	elseif elm:IsA("TextLabel") and elm.Name == "Desc" then
		if elm.Parent.Name == "STR" then
			elm.Text = "- Increases M1 DMG \n- Increases Skill DMG"
		elseif elm.Parent.Name == "AGI" then
			elm.Text = "- Increases M1 Speed \n- Increases Walk Speed \n- Decreases Skill CD"
		elseif elm.Parent.Name == "DEF" then
			elm.Text = "- Increases HP \n- Increases Blocking Power"
		elseif elm.Parent.Name == "INT" then
			elm.Text = "- Increases Crit Chance \n- Increases Combat EXP Gain"
		end
	elseif elm:IsA("TextButton") and elm.Parent.Name == "Reset"  then
		elm.MouseButton1Click:Connect(function()
			game.ReplicatedStorage.RemoteEvents.PlayerData.StatUpdate:FireServer("Reset")
		end)
	elseif elm:IsA("TextButton") and elm.Name == "Skill" then
		elm.MouseEnter:Connect(function()
			StatGUI.SkillDescription.Visible = true
			if elm.Parent.Name == "1" then
				StatGUI.SkillDescription.Req.Text = "Requirement: LvL 3, 50 Mastery"
			elseif elm.Parent.Name == "2" then
				StatGUI.SkillDescription.Req.Text = "Requirement: LvL 7, 100 Mastery"
			elseif elm.Parent.Name == "3" then
				StatGUI.SkillDescription.Req.Text = "Requirement: LvL 12, 200 Mastery"
			end
		end)
		elm.MouseLeave:Connect(function()
			StatGUI.SkillDescription.Visible = false
		end)
	elseif elm:IsA("TextButton") and elm.Name == "Passive" then
		elm.MouseEnter:Connect(function()
			StatGUI.PassiveDescription.Visible = true
			if elm.Parent.Name == "1" then
				StatGUI.PassiveDescription["1"].Visible = true
			elseif elm.Parent.Name == "2" then
				StatGUI.PassiveDescription["2"].Visible = true
			elseif elm.Parent.Name == "3" then
				StatGUI.PassiveDescription["3"].Visible = true
			end
		end)
		elm.MouseLeave:Connect(function()
			StatGUI.PassiveDescription.Visible = false
			for _, elm in StatGUI.PassiveDescription:GetDescendants() do
				if elm:IsA("TextLabel") then
					elm.Visible = false
				end
			end
		end)
	end
end

for _, elm in ShopGUI:GetDescendants() do
	if elm:IsA("TextButton") and elm.Parent.Name == "SkinRoll" then
		elm.MouseButton1Click:Connect(function()
			buyWeaponSkin:FireServer()
		end)
	end
end

for _, elm in InvenGUI.Main.Types:GetChildren() do
	if elm:IsA("TextButton") then
		elm.MouseButton1Click:Connect(function()
			local enabledFrame = InvenGUI.Main[elm.Name .. "Skins"]
			enabledFrame.Visible = true
			
			for _, frame in InvenGUI.Main:GetChildren() do
				if frame:IsA("ScrollingFrame") and frame ~= enabledFrame then
					frame.Visible = false
				end
			end
		end)
	end
end

-- ─── Remote events (persist across respawns) ─────────────────────────────────
updateRemote.OnClientEvent:Connect(function(stats, exp, expReq, sound, mastery)
	for _, elm in StatGUI:GetDescendants() do
		if elm.Name == "Stat" and elm:IsA("TextLabel") then
			elm.Text = stats[elm.Parent.Name]
		end
	end
	if exp then
		StatGUI.ExpBar.TextLabel.Text = exp .. " / " .. expReq
		StatGUI.ExpBar.Bar.Size = UDim2.new(math.min(exp / expReq, 1), 0, 1, 0)
		Currency.Main.Exp.Value.Text = exp .. "/" .. expReq
		if exp >= expReq then
			Currency.Main.Exp.Value.Text = "MAX"
		end
	end
	if sound then
		local statIncreaseAudio = StatGUI.Sound:Clone()
		statIncreaseAudio.SoundId = sound
		statIncreaseAudio:Play()
		statIncreaseAudio.Parent = game.SoundService
		game.Debris:AddItem(statIncreaseAudio, 1)
	end
	if mastery then
		StatGUI.Info.Mastery.Text = "Mastery: " .. math.round(mastery * 10) / 10
	end
end)

updatePassive.OnClientEvent:Connect(function(passives)
	print("Passives: ", passives)
	
	for _, frame in StatGUI.Passives:GetChildren() do
		if frame:IsA("Frame") then
			frame.Visible = false
		end
	end
	
	local index = 1
	for name, description in passives do
		StatGUI.Passives[tostring(index)].Visible = true
		StatGUI.Passives[tostring(index)].Passive.Text = name
		StatGUI.PassiveDescription[tostring(index)].Text = description
		index += 1
	end
end)

killLogRemote.OnClientEvent:Connect(function(killer, streak, nextLifeExp)
	print(streak)
	task.wait(1)
	killLog.Enabled = true
	local blur = killLog.Blur:Clone()
	blur.Parent = game.Lighting

	local sound = killLog.Sound:Clone()
	sound.Parent = game.SoundService
	sound:Play()
	game.Debris:AddItem(sound, 2)

	for _, frame in killLog:GetDescendants() do
		if frame:IsA("Frame") then
			frame.BackgroundTransparency = 1
		elseif frame:IsA("TextLabel") then
			frame.Text = ""
			frame.TextTransparency = 0
		end
	end

	killLog.Frame.TextLabel.Text = ""
	killLog.Frame.Killer.Text = ""
	task.delay(.5, function()
		typeWrite(killLog.Frame.TextLabel, "Defeated By: ")
		typeWrite(killLog.Frame.Streak, "Streak: ")
		typeWrite(killLog.Frame.Exp, "Passed Down EXP: " .. nextLifeExp)
	end)
	task.delay(1.5, function()
		typeWrite(killLog.Frame.Killer, killer)
		killLog.Frame.Counter.Text = streak
	end)

	TweenService:Create(blur, TweenInfo.new(2), {Size = 24}):Play()
	TweenService:Create(killLog.Background, TweenInfo.new(1), {BackgroundTransparency = 0.01}):Play()
	task.delay(3, function()
		TweenService:Create(killLog.Frame.TextLabel, TweenInfo.new(1), {TextTransparency = 1}):Play()
		TweenService:Create(killLog.Frame.Killer, TweenInfo.new(1), {TextTransparency = 1}):Play()
		TweenService:Create(killLog.Frame.Streak, TweenInfo.new(1), {TextTransparency = 1}):Play()
		TweenService:Create(killLog.Frame.Counter, TweenInfo.new(1), {TextTransparency = 1}):Play()
		TweenService:Create(killLog.Frame.Exp, TweenInfo.new(2), {TextTransparency = 1}):Play()
		TweenService:Create(killLog.Background, TweenInfo.new(1), {
			Size = UDim2.new(1,0,1,0),
			Position = UDim2.new(0,0,0,0)
		}):Play()
	end)
	task.wait(5.1)
	killLog.Enabled = false
	killLog.Background.Size = UDim2.new(1,0,0.3,0)
	killLog.Background.Position = UDim2.new(0,0,0.35,0)
	blur:Destroy()
	
	if notif.Notifications.CombatTag.Visible then
		notif.Notifications.CombatTag.Visible = false
	end
end)

getSkills.OnClientEvent:Connect(function(unlocked)
	print(unlocked)
	for _, tool in toolBar.Frame:GetChildren() do
		if tool:IsA("Frame") then
			tool.Visible = false
		end
	end
	for index, skill in unlocked do
		toolBar.Frame[index].Visible = true
		toolBar.Frame[index].Skill.Text = skill
	end
end)

getWeaponSkins.OnClientEvent:Connect(function(unlocked)
	if not unlocked then return end
	
	for _, frame in InvenGUI.Main:GetChildren() do 
		if frame:IsA("ScrollingFrame") then
			for _, button in frame:GetChildren() do
				if button:IsA("TextButton") and button.Name ~= "Template" then
					button:Destroy()
				end
			end
		end
	end
	
	for class, list in unlocked do
		print(list)
		for _, skin in ipairs(list) do
			print(skin)
			local frame = InvenGUI.Main.SwordSkins.Template:Clone()
			frame.Parent = InvenGUI.Main[class .. "Skins"]
			frame.Name = skin[1]
			frame.Text = skin[1]
			frame.Visible = true
			frame.MouseButton1Click:Connect(function()
				changeWeapon:FireServer(skin[1])
				weaponToggle:FireServer("Unequip")
				configAnim:Fire("Default")
			end)
		end
	end
end)

game.ReplicatedStorage.RemoteEvents.GUI.SkillCD.OnClientEvent:Connect(function(skillNum: number, cd: number)
	local cdFrame = toolBar.Frame[tostring(skillNum)].Cooldown
	cdFrame.Size = UDim2.new(1,0,1,0)
	cdFrame.Position = UDim2.new(0,0,0,0)
	cdFrame.Visible = true
	TweenService:Create(cdFrame, TweenInfo.new(cd, Enum.EasingStyle.Linear), {
		Size = UDim2.new(1,0,0,0),
		Position = UDim2.new(0,0,1,0)
	}):Play()
	task.wait(cd)
	cdFrame.Visible = false
end)

game.ReplicatedStorage.RemoteEvents.GUI.UpdateCurrency.OnClientEvent:Connect(function(key, amount)
	if key == "Gold" and amount then
		Currency.Main.Gold.Value.Text = amount
		game.SoundService.Gold:Play()
	elseif key == "Level" and amount then
		Currency.Main.Level.Value.Text = amount
	end
end)

local function fadeInOut(item, duration)
	if item:IsA("TextLabel") then
		item.Visible = true
		TweenService:Create(item, TweenInfo.new(1), {TextTransparency = 0, BackgroundTransparency = 0.95}):Play()
		task.wait(duration)
		TweenService:Create(item, TweenInfo.new(duration/2), {TextTransparency = 1, BackgroundTransparency = 1}):Play()
		task.wait(duration/2)
		item.Visible = false
	end
end

notification.OnClientEvent:Connect(function(action, text, color, sound, duration)
	notif.Enabled = true
	if action == "LevelUp" then
		statIcon:notify()
		game.SoundService.LevelUp:Play()
		local frame = notif.Notifications.LevelUp:Clone(); game.Debris:AddItem(frame, 3)
		frame.Parent = notif.Notifications
		fadeInOut(frame.TextLabel, 2)
	end
	if action == "SkinRoll" and text then
		local frame = notif.Notifications.General:Clone(); game.Debris:AddItem(frame, 3)
		frame.Parent = notif.Notifications
		frame.TextLabel.Text = text
		fadeInOut(frame.TextLabel, 1.5)
	elseif action == "General" then
		local frame = notif.Notifications.General:Clone(); game.Debris:AddItem(frame, duration*2)
		frame.Parent = notif.Notifications
		frame.TextLabel.Text = text
		frame.TextLabel.TextColor3 = color
		if sound then game.SoundService[sound]:Play() end
		fadeInOut(frame.TextLabel, duration)
	end
end)

changeWeapon.OnClientEvent:Connect(function(config)
	if not config then return end
	local class = config.WeaponClass
	StatGUI.Info.Class.Text = "Class: " .. class
end)

-- ─── Per-character setup (re-runs every respawn) ──────────────────────────────
local function onCharacterAdded(character)
	-- Reset stat GUI
	StatGUI.Enabled = false
	
	-- WeaponEquipped listener tied to THIS character instance
	character:GetAttributeChangedSignal("WeaponEquipped"):Connect(function()
		if character:GetAttribute("WeaponEquipped") ~= false then
			toolBar.Enabled = true
			getSkills:FireServer()
		else
			toolBar.Enabled = false
		end
	end)
	
	character:GetAttributeChangedSignal("CombatTagged"):Connect(function()
		if character:GetAttribute("CombatTagged") == true then
			notif.Notifications.CombatTag.Visible = true
		else
			notif.Notifications.CombatTag.Visible = false
		end
	end)

	-- Hide toolbar until a weapon is equipped
	toolBar.Enabled = false

	-- Spawn transition tween
	SpawnGUI.Enabled = true
	TweenService:Create(SpawnGUI.Frame1, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 0, 0)
	}):Play()
	TweenService:Create(SpawnGUI.Frame2, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 1, 0)
	}):Play()
	task.wait(2)
	SpawnGUI.Enabled = false
	SpawnGUI.Frame1.Size = UDim2.new(1, 0, 0.5, 0)
	SpawnGUI.Frame2.Size = UDim2.new(1, 0, 0.5, 0)
	SpawnGUI.Frame2.Position = UDim2.new(0, 0, 0.5, 0)
end

-- Hook up for future respawns and handle the first spawn
player.CharacterAdded:Connect(onCharacterAdded)
player.CharacterRemoving:Connect(function()
	StatGUI.Enabled = false
	toolBar.Enabled = false
end)

-- Fire immediately if character already loaded (e.g. LocalScript runs after spawn)
if player.Character then
	onCharacterAdded(player.Character)
end