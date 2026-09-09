# Playable Units Contract

Unit definitions use the common identity, display name, category, and scene path fields plus:

- `owner`: `player`, `ally`, `neutral`, or `hostile`;
- `max_health`, `movement_speed`, and `selection_radius`: numbers greater than zero;
- `attack_damage`: zero or greater;
- `attack_interval` and `attack_range`: numbers greater than zero;
- `acquisition_range`: at least `attack_range`.

Placed units use the existing instance transform contract. Values belong to the reusable definition, not individual placements.

Frontier owns selection, commands, movement, targeting, damage, health presentation, and death. The editor validates and previews units but does not simulate gameplay.

Abilities, buffs, inventory, training, leveling, patrols, triggers, and advanced AI require separate commissioned contracts.
