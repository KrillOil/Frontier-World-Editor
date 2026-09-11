# Build a Guided Tutorial Mission

Outcome: a playable original mission with an opening scene, leader guidance, recruited allies, two staged encounters, an ending scene, and victory. No JSON or Frontier source edits are required.

## Prepare

1. Duplicate the `worlds/crimsdale` folder in your file manager so the reference mission remains untouched.
2. Run Frontier World Editor in Godot 4.7.1 and choose **Open**. Select the duplicated folder.
3. Confirm the world contains at least one player unit, one allied unit, and two hostile units. Use **Object Editor** to inspect ownership; use the palette and viewport to place any missing role.
4. Open **Scenario**. If the copy contains a scenario, choose **Remove Scenario**, confirm, and save. This is the empty-scenario starting point.

## Generate the playable spine

5. In **Scenario**, choose **Create Guided Mission Template**.
6. Confirm the status says the template was created. If it reports missing roles, return to the world, place the named unit roles, and try again.
7. Choose **Apply Scenario Details** after giving the mission its own title and description. Keep the generated stable IDs unless a specific design requires new ones.
8. Review the generated point and rectangle regions. Select a region to edit its coordinates, then choose **Update Selected Region**. Put the recruit checkpoint on the allies, each encounter boundary around its hostile group, and the mission goal beyond the final encounter.

## Review each authored system

9. Open **Objectives & Guidance**. Confirm the main route is recruit allies → clear encounters → reach goal. Preview guidance and ensure every instruction names its control; never rely on color alone.
10. Open **Groups & Encounters**. Confirm the leader, recruitable allies, and both hostile groups contain the intended placed units. Keep both encounters dormant initially; use attack for the first and guard for the second.
11. Open **Cinematics**. Replace the generic opening and ending dialogue with original text. Preview and skip both scenes. Audio is optional; subtitles must carry the meaning alone.
12. Open **Sequences** and choose **Validate Flow**. Confirm the generated flow remains: start → recruit → first encounter cleared → final encounter cleared → goal and victory.
13. Save, close the package, reopen it, and run **Validate Flow** again.

## Play and verify

14. Configure the Frontier executable as described in `docs/FRONTIER_INTEGRATION.md`, then choose **Test World ▶**.
15. Verify the opening can be skipped with Escape and restores control.
16. Select the leader, move to the allies, and confirm ownership transfers.
17. Defeat the first group and confirm the second group activates. If the leader has an authored ability, select the leader and press `1` to use it.
18. Defeat the final group, move to the goal, and confirm the ending scene and `MISSION VICTORY` appear.
19. Repeat once after saving mid-mission. Confirm completed objectives, defeated groups, hero state, and rewards restore.

The result should feel like a fast classic RTS tutorial: one clear instruction, one nearby action, immediate feedback, and the next beat—without copying Warcraft names, dialogue, assets, or map geometry.
