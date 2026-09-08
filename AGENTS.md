# Agent Operating Contract

## Audience

This repository is written for two readers:

1. Codex agents implementing one accepted GitHub issue at a time.
2. The Creator approving outcomes and making product decisions.

Keep documentation short, testable, and tied to implementation. Put planned work in issues, not speculative documents.

## Before changing code

1. Read the assigned issue and its milestone.
2. Read only the linked repository contracts.
3. Inspect existing code and tests before proposing architecture.
4. Stop and ask on the issue when a decision would change product scope, authored-data compatibility, or the Frontier integration boundary.

## Fixed decisions

- This is a separate repository and application from Frontier.
- Use Godot 4.7.1.
- Match Warcraft III's authoring philosophy and fast workflow, not its proprietary implementation or exact visual design.
- The editor owns canonical object definitions and placed-world data.
- Frontier implements runtime concepts and consumes exported authored data.
- Crimsdale is the first reference world.
- Only world composition is commissioned initially.
- Terrain authoring, triggers, regions, campaigns, mod packaging, and broad asset import are out of scope until commissioned.
- **Test World** integration is the destination of the first end-to-end sequence, not a reason to couple repositories.

## Delivery rules

- One issue should produce one independently reviewable outcome.
- Add automated tests for deterministic data behavior and regressions.
- Do not invent fields in canonical data outside an accepted issue.
- Prefer simple Godot-native implementation unless a requirement proves otherwise.
- Update a contract only when the issue changes that contract.
- Report the verification performed and any remaining limitation in the pull request.

## Definition of done

- Issue acceptance criteria are demonstrably satisfied.
- Relevant automated checks pass.
- Changed user behavior is manually verified in Godot where applicable.
- No unrelated feature or framework is added.
- Documentation changes are concise and necessary for the next agent or the Creator.

