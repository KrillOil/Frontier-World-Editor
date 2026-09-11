# Guided Mission Creator Review

Use this checklist on a disposable package created from `docs/CREATOR_TUTORIAL.md`.

## Authoring speed and clarity

- [ ] An empty scenario becomes a valid playable spine with one button.
- [ ] Missing player, ally, or hostile roles produce a specific recovery message.
- [ ] Generated names describe reusable roles, not Crimsdale or story lore.
- [ ] Regions, groups, objectives, encounters, cinematics, and sequences are editable without opening JSON.
- [ ] Save, reopen, and Test World preserve the same authored meaning.

## Recovery and accessibility

- [ ] Validation identifies the failing reference and the panel where it can be fixed.
- [ ] A missing optional audio file does not remove its subtitle.
- [ ] Escape skips either cinematic and produces the same playable post-state.
- [ ] Tutorial instructions name controls and do not rely on color alone.
- [ ] Control lock pauses gameplay consistently and returns control after playback.

## WC3-style flow

- [ ] The opening establishes one immediate task.
- [ ] Each tutorial prompt appears close to the action it teaches.
- [ ] Allies join through world interaction, not a hidden runtime rule.
- [ ] Hostile groups remain dormant until their authored sequence activates them.
- [ ] Combat, an optional reward, and the final goal give immediate visible feedback.
- [ ] The ending and victory occur only after the authored completion conditions pass.

Record only failed items and concrete desired changes in a GitHub issue. Do not expand the data contract from review notes alone.
