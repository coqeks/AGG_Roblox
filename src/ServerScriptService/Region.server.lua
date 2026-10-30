-- Sends each player their own country code (e.g. "US").
-- Previously this geolocated the server's IP, so every player got the server's region.

local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")

local locationEvent = game.ReplicatedStorage.RemoteEvents.GUI:FindFirstChild("LocationData")

local function sendRegion(player)
	local ok, countryCode = pcall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(player)
	end)
	if ok and countryCode then
		-- { country code, region name } (region name isn't available per player)
		locationEvent:FireClient(player, {countryCode, nil})
	else
		warn("[Region] Could not get region for", player.Name, countryCode)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.wait(3) -- give the client's listener time to connect
	sendRegion(player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(sendRegion, player)
end
