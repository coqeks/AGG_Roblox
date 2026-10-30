# A Gladiator Game: Scripts

A collection of scripts responsible for various features in my Roblox game.

## Architecture

* **StarterPlayer**: Input reading, local character movement, GUI handling

* **StarterPack**: Combat-related client side logic

* **ReplicatedStorage**:
    * Combat/Movesets: Visual & Auditory logic for usable movesets
    * Loaders: Module script loaders, preloads animations for movesets as well
    * Modules: Helper & 3rd party modules. Left out 3rd party modules not written by me

* **ServerScriptService**:
    * Combat: State checking & changing, Damage calculation, M1 & Skill logic, etc.
        * SkillClasses: Skill base class, Projectile class & targeting helpers shared by every skill
    * Config: Stat and weapon configuration 
    * Entities: Object-oriented PvE enemies. Entity (body/actions), Brain (AI state machine), Vision (front region check + line of sight), Navigator (direct movement or pathfinding), configs & spawner
    * Movement: Server validation for dashing & sprinting
    * PlayerData: Saving/loading, progression (exp, levels, stats, skill unlocks, gold), wipe on death
    * PlayerStates: StateManager (single source of truth for stuns, cooldowns, i-frames, etc.) & resolver that turns states into movement
    * Services: Weapon equipping, weapon skin shop, admin dev flags

* **ServerStorage**:
    * MovesetLogic: Server logic for each skill, one subclass of the Skill base class per skill

* **ReplicatedFirst**: Loading screen

## Skill Sequence

1. **Input (client):** `StarterPack/SkillScript` reads keys 1-4, locks onto a target under the mouse, and fires `SkillReplicator` to the server with the slot and target.
2. **Validation (server):** `Combat/SkillService2` maps the slot to a skill name from the equipped weapon class. It then checks cooldowns, stuns, whether a skill is already active, and whether the skill is unlocked. It also calls the skill's `CanUse` for skill-specific conditions.
3. **Cast (server):** it applies the cooldown and calls `Skill:Cast(caster, target)`. This creates one instance per cast and runs the subclass's `Run` from `ServerStorage/MovesetLogic/<Skill>`.
4. **Execution (server):** inside `Run`, the skill calls `Begin`, which replicates the cast to all clients, adds the `UsingSkill` state and listens for stun-cancels. Then `RunSections` spawns a hitbox for each attack section at its delay. A hit goes through `ApplyHit`: damage via DamageManager, then knockback, then the skill's `OnHit` hook, then a finisher if the hit killed.
5. **Visuals (all clients):** `SkillReplicationClient` receives the replication and calls `Fire` on the matching `ReplicatedStorage/Combat/Movesets/<Skill>` module, which plays the animation, sounds and VFX locally. If the caster is stunned, it calls `Stop` to cancel them.

Since the caster can be a player or an NPC model, PvE enemies cast the exact same skill classes.
