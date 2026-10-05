# Developer test loadout

To refresh the current local save with a combat transport escort and test resources, run the `GrantRaidTest` scene once with the explicit command-line flag:

```powershell
& 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\path\to\sea-trader' --scene 'res://tools/dev/grant_raid_test.tscn' -- --grant-raid-test
```

The command is repeatable: it updates the same test ship instead of adding duplicates, restores its 30 guards and 3 crystal mortars, ensures 250,000 gold and 1,000 of each resource at the home port, and preserves the existing home garrison. It writes through `SaveSystem`; it does not add save files to the repository.
