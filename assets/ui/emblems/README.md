# Canonical faction heraldry

These six symbols are the game's approved primary faction emblems. Their silhouettes
follow the six faction marks shown on the bottom banner row of the captain-rank
celebration artwork. The artwork's flags are decorative presentation; these symbols
are the clean, reusable master marks for UI crests, ship insignia, and cloth flags.

| Faction ID | Primary emblem | Mark |
| --- | --- | --- |
| `nerids` | `nerids.svg` | Trident and tide |
| `surr` | `surr.svg` | Flame |
| `meridians` | `meridian.svg` | Meridian compass sun |
| `aery` | `aery.svg` | Sky wings |
| `crystari` | `crystari.svg` | Faceted crystal |
| `humans` | `humans.png` | Anchor |

`data/world/faction_catalog.json` is the source of truth and its `emblem` field
maps each faction ID to the master file. Runtime faction heraldry must load through
`GameData.get_faction_emblem(faction_id)` (or that catalog entry when building a
data-driven view). Do not draw alternate race marks in UI code or introduce emoji
substitutes. When a master symbol changes, update the file referenced by the catalog
so interfaces, world flags, and ship marks stay in sync.

The player-facing Sea Trader logo is not a faction emblem and remains separate.
