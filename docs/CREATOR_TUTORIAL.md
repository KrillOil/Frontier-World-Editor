# Build a Guided Tutorial Mission

Outcome: a playable original mission with an opening scene, leader guidance, recruited allies, two staged encounters, an ending scene, and victory. No JSON or Frontier source edits are required.

## Prepare

1. Duplicate the `worlds/crimsdale` folder in your file manager so the reference mission remains untouched.
2. Run Frontier World Editor in Godot 4.7.1 and choose **Open**. Select the duplicated folder.
3. Confirm the world contains at least one player unit, one allied unit, and two hostile units. Use **Object Editor** to inspect each unit's **Owner**; use the palette and viewport to place any missing role. Also confirm **Object Editor** contains at least one permanent reward. If not, choose **New Definition**, fill **Stable definition ID**, **Display name**, choose Category `item`, fill **Scene path**, **Item kind** `permanent_stat`, **Effect stat**, **Effect amount**, and **Feedback text**, then choose **Create Definition**.
4. Open **Scenario**. If the copy contains a scenario, choose **Remove Scenario**, confirm, and save. This is the empty-scenario starting point.

## Generate the playable spine

5. In **Scenario**, choose **Create Guided Mission Template**.
6. Confirm the status says the template was created. If it names a missing player leader, recruitable ally, or number of hostile units, place exactly that role and try again. If it reports a missing permanent-stat item, follow the **New Definition** actions in step 3, save, and try again.
7. Choose **Apply Scenario Details** after giving the mission its own title and description. Keep the generated stable IDs unless a specific design requires new ones.
8. The region list is alphabetized by stable ID, not by mission order. Review these generated point and rectangle regions in route order: `recruit_checkpoint`, `encounter_one_bounds`, `reward_checkpoint`, `encounter_two_bounds`, then `mission_goal`. Select one region at a time, edit its visibly labelled first/second X and Z coordinates, then choose **Update Selected Region**. Put the recruit checkpoint on the allies, each encounter boundary around its hostile group, the optional reward checkpoint on a reachable side path, and the mission goal beyond the far edge of the final encounter. No generated path region needs maintenance.

## Review each authored system

9. Open **Objectives & Guidance**. Confirm the main route is recruit allies → clear encounters → reach goal. Confirm `claim_optional_reward` is an optional objective with a step pointing to `reward_checkpoint`. Choose **Preview Mission Guidance** and ensure every instruction names its control; never rely on color alone.
10. Open **Groups & Encounters**. Confirm the leader, recruitable allies, and both hostile groups contain the intended placed units. Both encounter records start inactive: the first starts with sleep behavior and the second with guard behavior. In **Sequences**, `approach_first_encounter` changes the first group to active attack behavior.
11. Open **Cinematics**. Choose the opening or ending, select its dialogue row, replace the generic subtitle with original text, then choose **Update Selected Step**. Preview and skip both scenes. Audio is optional; subtitles must carry the meaning alone.
12. Open **Sequences** and manually review this order: start → recruit → approach and clear the first encounter → optional reward branch → final encounter → goal and victory. Inspect `claim_optional_reward`: its actions must complete the optional step and objective and grant the permanent-stat item to `player_party`. Then inspect `reward_final_approach_guidance`: it shows `approach_final_encounter` only if the final approach has not already run, so a late reward never replaces combat or goal guidance. Choose **Validate Flow** to check schema, references, and disabled-sequence warnings. Errors and notices open in a results window; select one and choose **Open Selected Finding** to reach its repair workspace. Validation does not certify the narrated mission order.
13. Choose **Save**, then choose **Open** and select the same copied package folder again. Run **Validate Flow** once more.

## Play and verify

14. Choose **Test Setup…**. For source review, set **Frontier executable or Godot 4.7.1 executable** to the absolute Godot 4.7.1 executable and set **Frontier project folder** to the absolute `Frontier/Game` folder. For an exported build, select `Frontier.exe` and leave the project folder empty. Choose **Use These Values**, then choose **Test World ▶**.
15. Verify the opening can be skipped with Escape and restores control.
16. Confirm the authored leader starts selected and the opening leaves one **Move to the waiting allies** prompt. Follow its labeled viewport cue and gold world marker, then confirm the recruited allies automatically join the selected squad. Follow the next marked-camp prompt.
17. Defeat the first group and follow the optional side-path prompt: `both` guidance shows a labeled viewport cue and gold world marker at `reward_checkpoint`. Confirm the leader receives the permanent reward and the final group remains dormant. The next prompt and marker point to the final hostile camp. Follow them; entering the authored final boundary replaces the movement cue with the attack or ability prompt and activates that group. If the leader has an authored ability, select the leader and press `1` during the final encounter.
18. Defeat the final group, move to the goal, and confirm the ending scene and `MISSION VICTORY` appear.
19. Repeat once after saving mid-mission. Confirm completed objectives, defeated groups, hero state, and rewards restore.

The result should feel like a fast classic RTS tutorial: one clear instruction, one nearby action, immediate feedback, and the next beat—without copying Warcraft names, dialogue, assets, or map geometry.
