local Skill      = require(game.ServerScriptService.Combat.SkillClasses.Skill)
local Projectile = require(game.ServerScriptService.Combat.SkillClasses.Projectile)
local Targeting  = require(game.ServerScriptService.Combat.SkillClasses.Targeting)
local ShadowMark = require(game.ServerScriptService.Combat.ShadowMark)

-- Matches the client visual in ReplicatedStorage.Combat.Movesets["Dagger Throw"]:
-- each dagger spawns 3 studs in front of the HRP and flies straight along the look direction.
local SPAWN_OFFSET = CFrame.new(0, 0, -3)

-- Grounded cast: 3 straight daggers (one Projectile per section). Airborne cast: a fan of daggers
-- into the ground in front, one blockable AOE hit. Every landed hit applies Shadow Marked.
local DaggerThrow = Skill.extend(script.Name, {
	CD = 10,
	Sections = {
		[1] = {
			Damage = 5,
			Size = 1.25, -- projectile radius
			Offset = CFrame.new(0,0,0),
			Lifetime = 2,
			Delay = 0.50,
			BlockBreak = false,
			States = {
				["HitStun"] = 0.5
			},
			ProjectileSpeed = 100
		},
		[2] = {
			Damage = 5,
			Size = 1.25,
			Offset = CFrame.new(0,0,0),
			Lifetime = 2,
			Delay = 0.75,
			BlockBreak = false,
			States = {
				["HitStun"] = 0.5
			},
			ProjectileSpeed = 100
		},
		[3] = {
			Damage = 5,
			Size = 1.25,
			Offset = CFrame.new(0,0,0),
			Lifetime = 2,
			Delay = 1,
			BlockBreak = false,
			States = {
				["HitStun"] = 1
			},
			ProjectileSpeed = 100
		}
	},
	Duration = 2,
	SelfState = {
		["Slow"] = 1.5
	},
	HyperArmor = false,

	Air = {
		AirborneCheck = 5,     -- studs: no ground this far below the HRP = airborne (same as MyCombat)
		Delay = 0.35,          -- release time after the cast starts
		DaggerCount = 7,       -- visual only; the damage is a single AOE hit
		Speed = 120,           -- studs/s, used for the impact time (client daggers fly at the same speed)
		Range = 16,            -- horizontal distance from the caster to the impact centre
		MaxDrop = 60,          -- how far down to look for ground at the impact point
		Radius = 9,            -- AOE radius around the impact centre
		Damage = 12,
		BlockBreak = false,    -- blockable
		States = {
			["HitStun"] = 0.8,
			["Slow"] = 1
		},
		Knockback = 20,
		Duration = 0.9,        -- UsingSkill time for the caster
	}
})

function DaggerThrow:Run()
	if self:IsAirborne() then
		self:AirThrow()
	else
		self:GroundThrow()
	end
end

-- Every landed hit (either variant) marks the target for Shade Step
function DaggerThrow:OnHit(target, section, landed)
	if landed then
		ShadowMark.new(self.Character, target)
	end
end

function DaggerThrow:IsAirborne()
	local down = Vector3.new(0, -self.Config.Air.AirborneCheck, 0)
	return workspace:Raycast(self.Root.Position, down, Targeting.MapOnlyParams()) == nil
end

-- ─── Grounded: straight daggers ──────────────────────────────────────────────

function DaggerThrow:GroundThrow()
	self:Begin(1)
	for _, section in self.Config.Sections do
		self:After(section.Delay, function()
			self:ThrowDagger(section)
		end)
	end
end

-- Each dagger hits at most one target (the first along its path)
function DaggerThrow:ThrowDagger(section)
	local direction = self.Root.CFrame.LookVector
	local damageParams = self:BuildDamageParams(section)

	local dagger = Projectile.new({
		Name = "DaggerThrow",
		Owner = self.Character,
		Origin = self.Root.CFrame * SPAWN_OFFSET * section.Offset,
		Direction = direction,
		Speed = section.ProjectileSpeed,
		Radius = section.Size,
		Lifetime = section.Lifetime,
	})
	dagger.Hit:Connect(function(target)
		self:ApplyHit(target, section, damageParams, direction)
	end)
	dagger:Launch()
end

-- ─── Airborne: dagger spread ─────────────────────────────────────────────────

-- Impact point: on the ground `Range` studs ahead (flat), or diagonally down if there's no floor there
function DaggerThrow:FindImpact()
	local air = self.Config.Air
	local hrp = self.Root
	local flatLook = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	flatLook = flatLook.Magnitude > 0 and flatLook.Unit or Vector3.new(0, 0, -1)

	local params = Targeting.MapOnlyParams()
	local aimTop = hrp.Position + flatLook * air.Range + Vector3.new(0, 2, 0)
	local result = workspace:Raycast(aimTop, Vector3.new(0, -air.MaxDrop, 0), params)
	if not result then
		-- e.g. throwing off a ledge
		result = workspace:Raycast(hrp.Position, (flatLook * air.Range + Vector3.new(0, -air.Range, 0)).Unit * air.MaxDrop, params)
	end
	if result then
		return result.Position, result.Normal, flatLook
	end
	return aimTop - Vector3.new(0, air.MaxDrop, 0), Vector3.yAxis, flatLook
end

function DaggerThrow:AirThrow()
	local air = self.Config.Air
	local impactPos, impactNormal, flatLook = self:FindImpact()
	local travelTime = (impactPos - self.Root.Position).Magnitude / air.Speed

	self:Begin("Air", {
		Position = impactPos,
		Normal = impactNormal,
		Delay = air.Delay,
		Speed = air.Speed,
		Count = air.DaggerCount,
		Radius = air.Radius,
	}, air.Duration, {})

	self:After(air.Delay, function()
		task.wait(travelTime)
		if not self.Character.Parent then return end

		-- Single AOE hit: every character in the radius once, knocked away from the centre
		local damageParams = self:BuildDamageParams(air)
		for _, target in Targeting.CharactersInRadius(impactPos, air.Radius, self.Character) do
			local away = target.HumanoidRootPart.Position - impactPos
			away = Vector3.new(away.X, 0, away.Z)
			self:ApplyHit(target, air, damageParams, away.Magnitude > 0.1 and away.Unit or flatLook)
		end
	end)
end

return DaggerThrow
