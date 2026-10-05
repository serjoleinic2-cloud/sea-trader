# Hireable ship crew portraits

`crew_portrait_atlas.png` is a 3-column × 6-row atlas of 18 distinct recruitable crew portraits. Each race has three faces; the hiring board rotates through variants so same-race candidates do not share faces within one board. These characters are separate from the player's fixed captain portrait.

Rows follow the six faction IDs: `humans`, `nerids`, `surr`, `meridians`, `aery`, and `crystari`. Candidate statistics and traits are generated separately and persist in the hiring board/save. UI windows use `AtlasTexture` regions so the source stays one asset.
