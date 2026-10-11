# Canonical faction heraldry

The approved source is `assets/ui/ranks/rank_celebration_backdrop.png`: the six
large hanging flags on its left and right. The owner confirmed this set on
2026-10-11. It replaces the older garrison symbols (flame, wings, crystal, anchor).
These SVGs are transparent vector adaptations of the marks in that artwork;
the original cloth and perspective remain in the approved background.

- `nerids.svg`: trident and tide, navy cloth (upper left, inner flag).
- `surr.svg`: firebird, dark brown cloth (lower right).
- `meridian.svg`: sun, burgundy cloth (upper left, outer flag).
- `aery.svg`: compass star and crescent, ivory cloth (upper right, inner flag).
- `crystari.svg`: cosmic spiral, violet cloth (upper right, outer flag).
- `humans.svg`: branching antler mark and star, green cloth (lower left).

`humans.png` is a retained legacy asset; it is not a primary emblem.

`data/world/faction_catalog.json` is the source of truth and its `emblem` field
maps each faction ID to the master file. Runtime faction heraldry must load through
`GameData.get_faction_emblem(faction_id)` (or that catalog entry when building a
data-driven view). Do not draw alternate race marks in UI code or introduce emoji
substitutes. When a master symbol changes, update the file referenced by the catalog
so interfaces, world flags, and ship marks stay in sync. The catalog's
`banner_color` fixes the cloth colour. `systems/ui/faction_pennant.gd` draws the
reusable UI cloth pennant; it never substitutes a separate symbol.

The player-facing Sea Trader logo is not a faction emblem and remains separate.
