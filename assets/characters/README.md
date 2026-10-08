# Character art catalogue

Character art is grouped by **race first**, then by gameplay role. Keep the fixed player-captain portraits in `captains/`; their face and outfit are canonical and must not be randomized.

## Troops

`units/<race>/roster_atlas.png` contains six faction-specific troop illustrations. It is an editable source atlas, not a flattened UI card. Read cells left to right, top to bottom:

1. `coast_guard` — береговой дозорный
2. `rune_spearman` — рунный копейщик
3. `stone_warden` — каменный страж
4. `wind_rider` — всадник ветра
5. `crystal_mortar` — расчёт кристальной мортиры
6. `storm_drake` — грозовой дракончик

The Godot lookup in `systems/characters/character_art_catalog.gd` makes an `AtlasTexture` for the requested race and unit. Replace one cell in the source atlas while preserving its 3×2 layout, or update that lookup if the atlas layout changes. Existing generic unit images remain as a safe fallback.

## Hireable ship officers

`crew/naval_officers/<race>/officers_atlas.png` contains six distinct candidates per race. The top row is three captains; the bottom row is three assistants. A portrait id from 0 to 2 selects the candidate within the role row. Captains use these portraits only as ship-staff candidates; the player's own captain art stays in `captains/`.

The hiring board, fleet roster and crew window all use the same race-and-role lookup. Other crew roles retain the existing crew portrait atlas until a dedicated art set is authored for them.

## Commanders

`commanders/<race>/portrait_01.png` through `portrait_03.png` are the race-specific garrison commander and deputy candidates. Their mapping is `data/combat/commander_portraits.json`.

All atlases are 2D game art. 3D models are not stored in this catalogue.
