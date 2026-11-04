# BOOT-001: Bootstrap the desktop canvas

Status: Done

## Approval

Approved in the setup conversation on 2026-11-04, including the project-local
official Godot download. Local ticketing is used because no Git repository or
GitHub tracker is configured.

## Scope

- Use Godot 4.7.2 stable, standard edition, with GDScript and Compatibility rendering.
- Provide a resizable desktop window with the game title and an empty play area.
- Verify startup on Linux.
- Document how to open, run, and smoke-test the project.
- Update the [design's technical direction](../the-tiny-empire-game-design-spec-v0.1.md).

No gameplay, third-party plugins, mobile support, export templates, Windows
verification, Git initialization, or commits are included.

## Acceptance criteria

- Project imports without errors in the selected Godot version.
- Main scene loads and runs without errors.
- Linux graphical startup displays the title and empty play area.
- Layout accommodates window resizing.
- Local tool downloads and generated engine files are ignored by version control.

## Verification

- Official Linux x86_64 download passed the release SHA-512 checksum check.
- Godot reported version `4.7.2.stable.official.ed1daf0bf`.
- Headless editor import completed with exit code 0 and no errors.
- Headless main-scene execution for ten frames completed with exit code 0.
- Graphical Linux startup used the Compatibility renderer successfully.
- A temporary graphical smoke script checked that the title and play area fit
  inside the canvas at requested window sizes of 1280 x 800 and 800 x 600;
  both checks passed.
- Captured and visually inspected the game viewport: title and empty play area
  rendered correctly.
- The graphical smoke process exited cleanly. No editor or game was left running.
- Windows export/testing and gameplay tests were not performed; neither is in scope.
