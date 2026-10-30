-- Admin panel: topbar "Admin" button (admins only) that opens a list of dev flag toggles.
-- Flags: ReplicatedStorage.DevFlags attributes. Changes go through RemoteEvents.Admin.SetDevFlag (server re-checks admin).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

if player:GetAttribute("IsAdmin") == nil then
	player:GetAttributeChangedSignal("IsAdmin"):Wait()
end
if player:GetAttribute("IsAdmin") ~= true then return end

local Topbar = require(ReplicatedStorage.Modules.Icon)
local devFlags = ReplicatedStorage:WaitForChild("DevFlags")
local descriptions = devFlags:WaitForChild("Descriptions")
local setFlagRemote = ReplicatedStorage.RemoteEvents.Admin.SetDevFlag

local FONT = Enum.Font.Arcade
local ON_COLOR = Color3.fromRGB(60, 170, 90)
local OFF_COLOR = Color3.fromRGB(150, 50, 50)

-- ─── GUI ────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "AdminPanel"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 50

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(420, 0)
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
frame.BackgroundTransparency = 0.1
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local padding = Instance.new("UIPadding", frame)
for _, side in {"PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight"} do
	padding[side] = UDim.new(0, 12)
end

local layout = Instance.new("UIListLayout", frame)
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.Font = FONT
title.TextSize = 28
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Dev Flags (this server)"
title.LayoutOrder = 0
title.Parent = frame

local buttons = {}

local function refresh(flagName)
	local button = buttons[flagName]
	if not button then return end
	local on = devFlags:GetAttribute(flagName) == true
	button.Text = on and "ON" or "OFF"
	button.BackgroundColor3 = on and ON_COLOR or OFF_COLOR
end

local names = {}
for name in descriptions:GetAttributes() do
	table.insert(names, name)
end
table.sort(names)

for i, name in names do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 48)
	row.BackgroundTransparency = 1
	row.LayoutOrder = i
	row.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -80, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextSize = 18
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.new(1, 1, 1)
	label.RichText = true
	label.Text = "<b>" .. name .. "</b>\n" .. tostring(descriptions:GetAttribute(name))
	label.Parent = row

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, 0, 0.5, 0)
	button.Size = UDim2.fromOffset(70, 32)
	button.Font = FONT
	button.TextSize = 22
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Parent = row
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)
	buttons[name] = button

	button.Activated:Connect(function()
		setFlagRemote:FireServer(name, devFlags:GetAttribute(name) ~= true)
	end)
	devFlags:GetAttributeChangedSignal(name):Connect(function()
		refresh(name)
	end)
	refresh(name)
end

gui.Parent = player:WaitForChild("PlayerGui")

-- ─── Topbar button ──────────────────────────────────────────────────────────
local adminIcon = Topbar.new()
adminIcon:setLabel("Admin")
adminIcon:setTextFont("PressStart2P")
adminIcon.selected:Connect(function() gui.Enabled = true end)
adminIcon.deselected:Connect(function() gui.Enabled = false end)
