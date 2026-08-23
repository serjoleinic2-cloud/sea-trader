# Tests

## Framework: GUT (Godot Unit Testing)

GUT is **not included** in this repository.
Install via Godot Asset Library or GitHub:
https://github.com/bitwes/Gut

After installation:
1. Enable the plugin in Project Settings -> Plugins.
2. Configure GUT test directories to include `res://tests/`.

Test files follow GUT conventions:
- Named `test_*.gd`
- Extend `GutTest`
- Place in `tests/unit/` or `tests/integration/`

## Running Tests

Via GUT panel in Godot Editor, or via CLI:
```
godot --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit
```
