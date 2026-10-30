local StatConfig = {}

local baseExpReq = 50

local Passives = { -- Passive Name, Stat, requirement and description
	["Powerful Blow"] = {"STR", 10, "Last M1 deals increased damage. [1.5x]"}, -- Last m1 deals more damage
	["Execution"] = {"STR", 20, "Enemies can be executed by landing attacks when lower than 8% HP."}, -- Enemies can be executed by landing attacks that lowers them below 8% hp
	["Rhythmic Tendency"] = {"AGI", 10, "M1 speed increases by [5%] with each landed attack, caps at 5 stacks."}, -- M1 gets faster each time after landing attack, caps at 5 stacks
	["Godspeed"] = {"AGI", 20, "Your reflexes allows you to dodge incoming attacks [10%]. Your dashes are enhanced."},
	["Bastion"] = {"DEF", 10, "Your last M1 now has hyperarmor."},
	["Unwavering Resolve"] = {"DEF", 20, "Enemies can no longer land critical hits on you."},
	["Precise Strike"] = {"INT", 10, "Your critical attacks have a chance [25%] to amputate."},
	["Enlightened"] = {"INT", 20, "Your weapon skills can land as critical hits now."} 
}

function StatConfig.GetExpRequirement(currentTotal)
	local req = baseExpReq
	for i = 1, currentTotal do
		req = req + 50
	end
	return math.floor(req)
end

function StatConfig.GetDmgMult(dmg, stats)
	if not stats then warn("No stats found!") return end
	local stat = stats["STR"]
	return dmg * (1 + stat / 40)
end

function StatConfig.GetSwingSpeedMult(swingCD, stats)
	if not stats then warn("No stats found!") return end
	local stat = stats["AGI"]
	return swingCD * (1 - stat / 60)
end

function StatConfig.GetSpeedMult(speed, stats)
	if not stats then warn("No stats found!") return end
	local stat = stats["AGI"]
	return speed * (1 + stat / 60)
end

function StatConfig.GetHealth(stats)
	if not stats then warn("No stats found!") return end
	local stat = stats["DEF"]
	return 100 + stat * 5
end

function StatConfig.GetCritChance(stats) -- In percent
	if not stats then warn("No stats found!") return end
	local stat = stats["INT"]
	local base = 5
	local increase = stat * 0.25
	return base + increase
end

function StatConfig.GetExpMult(stats)
	if not stats then warn("No stats found!") return end
	local stat = stats["INT"]
	local base = 1
	local increase = stat * 0.05
	return base + increase
end

function StatConfig.GetSkillCD(cd, stats)
	if not stats then warn("No stats found!") return end
	local stat = stats["AGI"]
	return cd - stat * 0.25
end

function StatConfig.ReturnPassives(stats)
	local unlocked = {}
	for name, info in Passives do
		local statName, threshold = info[1], info[2]
		if stats[statName] >= threshold then
			unlocked[name] = info[3]
		end
	end
	return unlocked
end

return StatConfig
