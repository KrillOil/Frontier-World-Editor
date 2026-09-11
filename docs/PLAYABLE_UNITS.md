# Playable Units Contract

Unit definitions use the common identity, display name, category, and scene path fields plus:

- `owner`: `player`, `ally`, `neutral`, or `hostile`;
- `max_health`, `movement_speed`, and `selection_radius`: numbers greater than zero;
- `attack_damage`: zero or greater;
- `attack_interval` and `attack_range`: numbers greater than zero;
- `acquisition_range`: at least `attack_range`.

Placed units use the existing instance transform contract. Values belong to the reusable definition, not individual placements.

## Hero and reward fields

- A hero unit sets `hero: true`, mana, starting level/experience, strength/agility/intellect, ordered ability IDs, inventory limit, and automatic/manual pickup.
- Ability definitions use targeted, area, or chained-damage mode plus deterministic damage, range, cooldown, mana, area/chain limits, and presentation text.
- Item definitions are consumable or permanent-stat rewards with one health, mana, strength, agility, or intellect effect and feedback text.
- Items place like other definitions. `grant_reward.reward_id` must resolve to an item definition; a unit ability ID must resolve to an ability definition.

Frontier owns selection, commands, movement, targeting, damage, health presentation, and death. The editor validates and previews units but does not simulate gameplay.

Abilities, buffs, inventory, training, leveling, patrols, triggers, and advanced AI require separate commissioned contracts.
