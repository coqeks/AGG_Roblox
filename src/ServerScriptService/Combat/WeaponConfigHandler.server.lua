local remote = game.ReplicatedStorage.RemoteEvents.Combat.RequestHBConfig
local event = game.ReplicatedStorage.Bindables.CombatData
local HBConfig = require(game.ServerScriptService.Config.WeaponConfig)

game.Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		char:GetAttributeChangedSignal("WeaponEquipped"):Connect(function()
			local weapon = char:GetAttribute("WeaponEquipped")
			if weapon then
				local config = HBConfig.Preset(weapon)
				if config then
					remote:FireClient(plr,config)
					event:Fire(plr, config)
				end
			end
		end)
		
	end)
end)