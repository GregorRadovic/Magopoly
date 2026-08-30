# Building Magopoly for distribution

The goal: one file, `build/Magopoly.exe`, that you can send to friends. It has
the whole game embedded (no separate `.pck`, no folder of assets).

## One-time setup: export templates

Godot needs the "export templates" for its exact version to build a
standalone executable. They aren't bundled with the editor.

1. Open this project in the Godot 4.7 editor.
2. Menu bar: **Editor → Manage Export Templates**.
3. Click **Download and Install** (about 700 MB, one time).

That's it — you won't need to do this again unless you upgrade Godot.

## Building

From this folder, in PowerShell:

```powershell
.\build.ps1
```

It finds Godot, checks the templates are installed, and writes
`build\Magopoly.exe`. Add `-Run` to launch it right after building.

If the script can't find Godot, point it at the console executable:

```powershell
.\build.ps1 -Godot "C:\path\to\Godot_v4.7-stable_win64_console.exe"
```

### Doing it by hand instead

```powershell
godot --headless --path . --export-release "Windows Desktop" build/Magopoly.exe
```

## Sending it to friends

`Magopoly.exe` is self-contained — just send that one file (zip it first;
some mail/chat clients block bare `.exe` attachments).

**They will see a Windows SmartScreen warning** ("Windows protected your PC")
because the file isn't code-signed. To run it they click
**More info → Run anyway**. This is normal for any indie game that isn't
signed with a paid certificate. A few antivirus tools also flag unsigned
Godot builds as a false positive; if that happens they can whitelist it.

Requirements on their side: 64-bit Windows 10/11. The game uses the
OpenGL (Compatibility) renderer, so it runs on integrated graphics and
older machines.

## Notes

- `build/` is git-ignored.
- `export_presets.cfg` holds the export settings (embed-PCK is on there).
- Renderer is set to **Compatibility** in `project.godot`
  (`renderer/rendering_method="gl_compatibility"`).
