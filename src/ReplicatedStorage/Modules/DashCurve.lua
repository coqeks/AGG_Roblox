-- Shared dash tuning and velocity curve. DashClient (player dashes and the DashAttack lunge),
-- DashServer (cooldowns/states) and Entity:Dash all read it, so every dash moves the same way.

local DashCurve = {}

DashCurve.POWER = 60            -- peak speed of a side dash
DashCurve.FRONT_BACK_MULT = 1.25
DashCurve.AMPUTATED_MULT = 0.5
DashCurve.TIME = 0.5
DashCurve.COOLDOWN = 2

local RAMP = 0.04 -- share of the dash spent reaching peak speed
local HOLD = 0.25 -- peak is held until this point, then eases out

function DashCurve.Power(relativeDirection, legAmputated)
	local power = DashCurve.POWER
	if relativeDirection == "Front" or relativeDirection == "Back" then
		power *= DashCurve.FRONT_BACK_MULT
	end
	if legAmputated then
		power *= DashCurve.AMPUTATED_MULT
	end
	return power
end

-- Speed at `alpha` (0..1 through the dash): a quick burst to `peak`, a short hold, then an ease-out
-- that lands on `exitSpeed` (the character's walk speed) so the dash hands straight over to normal
-- movement instead of braking to a stop first.
function DashCurve.Speed(alpha, peak, exitSpeed)
	exitSpeed = math.min(exitSpeed or 0, peak)
	if alpha < RAMP then
		local t = alpha / RAMP
		return peak * (1 - (1 - t) ^ 2)
	elseif alpha < HOLD then
		return peak
	end
	local t = math.clamp((alpha - HOLD) / (1 - HOLD), 0, 1)
	return exitSpeed + (peak - exitSpeed) * (1 - t) ^ 2
end

return DashCurve
