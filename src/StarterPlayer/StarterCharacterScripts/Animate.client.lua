

-- SERVICES
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- PLAYER
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")

local sprintRemote = game.ReplicatedStorage.RemoteEvents.Movement.SprintEvent
local configEvent = game.ReplicatedStorage.Bindables.ConfigAnim

--------------------------------------------------
-- CONFIG (FOR VIDEO CUSTOMIZATION)
--------------------------------------------------

local WALK_SPEED = 16
local SPRINT_SPEED = 24

-- Sprint key options
local SPRINT_KEYS = {
	[Enum.KeyCode.LeftShift] = true,
	[Enum.KeyCode.LeftControl] = true
}

--------------------------------------------------
-- ANIMATIONS
--------------------------------------------------

local Animations = {}

Animations.Idle = Instance.new("Animation")
Animations.Idle.AnimationId = "rbxassetid://180435792"

Animations.Walk = Instance.new("Animation")
Animations.Walk.AnimationId = "rbxassetid://136847809532978"

Animations.Sprint = Instance.new("Animation")
Animations.Sprint.AnimationId = "rbxassetid://102717946178201"

Animations.Jump = Instance.new("Animation")
Animations.Jump.AnimationId = "rbxassetid://127668457254982"

--------------------------------------------------
-- LOAD TRACKS
--------------------------------------------------

local Tracks = {}
for name, anim in pairs(Animations) do
	local track = humanoid:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Movement
	Tracks[name] = track
end

local current = nil

local function playAnim(name)
	if current == name then 
		return 
	end

	for trackName, track in pairs(Tracks) do
		if trackName ~= name then
			track:Stop(0.15)
		end
	end

	Tracks[name]:Play(0.1)
	current = name
end

--------------------------------------------------
-- SPRINT LOGIC
--------------------------------------------------

local DoubleClickTime = 0.2
local LastClickTime = 0

UserInputService.InputBegan:Connect(function(Input)
	if Input.KeyCode ~= Enum.KeyCode.W then return end
	local CurrentClickTime = RunService.Stepped:Wait()
	if (CurrentClickTime - LastClickTime) < DoubleClickTime and char:GetAttribute("Slow") == false and char:GetAttribute("Blocking") == false and char:GetAttribute("UsingSkill") == false then
		sprintRemote:FireServer(char, true)
	end
	LastClickTime = CurrentClickTime
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.W and char:GetAttribute("Slow") == false and char:GetAttribute("Blocking") == false and char:GetAttribute("UsingSkill") == false then
		sprintRemote:FireServer(char, false)
	end
end)

--------------------------------------------------
-- SPRINT LOGIC (MOBILE THUMBSTICK)
--------------------------------------------------
local function setupThumbstick()
	local playerGui = player:WaitForChild("PlayerGui")
	local touchGui = playerGui:WaitForChild("TouchGui", 10)
	if not touchGui then return end
	
	local startPos
	local isMobileSprinting = false

	local thumbstickFrame = touchGui
		:WaitForChild("TouchControlFrame")
		:WaitForChild("DynamicThumbstickFrame")

	thumbstickFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			startPos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	-- Check position whenever the touch moves
	thumbstickFrame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			if startPos and (pos - startPos).Magnitude > 50 and not isMobileSprinting then
				isMobileSprinting = true
				sprintRemote:FireServer(char, true)
			elseif startPos and (pos - startPos).Magnitude < 50 and isMobileSprinting then
				isMobileSprinting = false
				sprintRemote:FireServer(char, false)
			end
		end
	end)

	-- Always stop sprinting when thumb lifts
	thumbstickFrame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			if isMobileSprinting then
				isMobileSprinting = false
				sprintRemote:FireServer(char, false)
			end
		end
	end)
end

if UserInputService.TouchEnabled then
	task.spawn(setupThumbstick)
end


--------------------------------------------------
-- MAIN ANIMATION LOOP
--------------------------------------------------

RunService.RenderStepped:Connect(function()
	local state = humanoid:GetState()
	local moving = humanoid.MoveDirection.Magnitude > 0.1

	--if char:GetAttribute("Slow") == true or char:GetAttribute("PreventDM") == true then
	--	return
	--end

	if char:GetAttribute("Blocking") == true or char:GetAttribute("Slow") == true then
		Tracks["Walk"]:AdjustSpeed(0.3)
	end
	
	if char:GetAttribute("Airborne") then
		playAnim("Jump")
	elseif moving and char:GetAttribute("Sprinting") then
		playAnim("Sprint")
	elseif moving then
		playAnim("Walk")
	else
		playAnim("Idle")
	end
	
	task.wait(0.1)
end)

configEvent.Event:Connect(function(name)
	print("Configuring movement anims: ", name)

	local animPath = game.ReplicatedStorage.Animations.Movement:WaitForChild(name)

	-- Create new animation objects
	local newAnimations = {
		Idle = Animations.Idle, -- keep same idle unless you want to change it too
		Walk = Instance.new("Animation"),
		Sprint = Instance.new("Animation"),
		Jump = Animations.Jump
	}

	newAnimations.Walk.AnimationId = animPath.Walk.AnimationId
	newAnimations.Sprint.AnimationId = animPath.Run.AnimationId

	-- Load new tracks
	local newTracks = {}
	for animName, anim in pairs(newAnimations) do
		local track = humanoid:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Movement
		newTracks[animName] = track
	end

	-- 🔥 CROSSFADE LOGIC
	for name, newTrack in pairs(newTracks) do
		local oldTrack = Tracks[name]

		if oldTrack and oldTrack.IsPlaying then
			-- Match time position for smoothness
			newTrack.TimePosition = oldTrack.TimePosition

			-- Play new track smoothly
			newTrack:Play(0.2)

			-- Fade out old track
			oldTrack:Stop(0.2)
		end
	end

	-- Small delay before cleanup (ensures fade completes)
	task.delay(0.25, function()
		for _, track in pairs(Tracks) do
			track:Destroy()
		end
	end)

	-- Replace references
	Animations = newAnimations
	Tracks = newTracks
end)