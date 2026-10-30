-- PvE entity types. Entities.EntityService spawns one at every part in workspace.EntitySpawns whose
-- EntityType attribute is a key of this table, and respawns it RespawnTime seconds after it dies.

return {
	Bandit = {
		Model = "Bandit",            -- ServerStorage.Entities.Models[Model]
		DisplayName = "Bandit",
		Health = 150,
		WalkSpeed = 12,              -- Sprinting adds 8 (StateResolverServer)
		Weapon = "Iron Gladius",     -- WeaponConfig preset: M1 hitbox/damage/combo, weapon model, animations
		DamageMultiplier = 1,        -- scales M1 damage (skills use their own Config)
		CritChance = 5,              -- percent, for crittable hits
		-- MovesetLogic skill names, or { Name = ..., Range = ..., MinRange = ... } (see Brain's SKILL_RANGES)
		Skills = { "Rapid Pierce", "Cross Slash" },

		Vision = {
			Range = 60,              -- how far ahead it sees
			Width = 40,
			Height = 20,
			LoseSightTime = 6,       -- seconds without line of sight before giving up the chase
			Debug = false,           -- true shows the vision box (for tuning)
		},
		WanderRadius = 12,           -- idle wandering around the spawn (0 = stand still)
		LeashRange = 120,            -- gives up and walks home past this distance from its spawn
		AttackRange = 6,             -- M1s when the target is this close
		SprintDistance = 20,         -- sprints when the target is further than this

		Behaviour = {
			ReactionTime = 0.3,      -- delay before reacting to the target's attack (+0-0.15s random)
			BlockChance = 0.4,       -- chance to block an incoming attack
			DashChance = 0.2,        -- chance to dash out of an incoming attack instead
			GapCloseChance = 0.3,    -- per second, dash forward when the target is 14-30 studs away
			SkillChance = 0.5,       -- chance per skill decision (2 per second) to use a ready skill
			JumpChance = 0.1,        -- per second, a random hop while in melee
		},

		Rewards = { Exp = 60, Gold = 25 }, -- to the player who dealt the most damage
		RespawnTime = 20,
		CorpseTime = 5,              -- seconds the body stays after death
	},
}
