# Building Magopoly for distribution

The goal: one file, `build/Magopoly.exe`, with the whole game embedded (no
separate `.pck`, no folder of assets). `build/` is git-ignored — the binary
never goes in the repo; it's published through **GitHub Releases** instead.

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
`build\Magopoly.exe`. Flags:

- `-Run` — launch the result right after building
- `-Zip` — also write `build\Magopoly.zip` (handy for the release upload)
- `-Godot "C:\path\to\Godot_v4.7-stable_win64_console.exe"` — if it can't find Godot

### From the editor instead

**Project → Export → "Windows Desktop" → Export Project…** The preset already
writes to `build/Magopoly.exe` (embed-PCK on, codesign off).

### By hand

```powershell
godot --headless --path . --export-release "Windows Desktop" build/Magopoly.exe
```

## Publishing a release

1. Build (`.\build.ps1 -Zip`).
2. On GitHub: **Releases → Draft a new release**, pick a tag (e.g. `v1.0`).
3. Drag `build\Magopoly.exe` (or the `.zip`) into the **"Attach binaries"** box
   and publish. Release assets allow up to 2 GB per file and stay out of git.

The README's download link already points at the Releases page.

### What your players will see

**A Windows SmartScreen warning** ("Windows protected your PC") because the file
isn't code-signed. To run it they click **More info → Run anyway**. This is
normal for any indie game without a paid signing certificate. A few antivirus
tools also flag unsigned Godot builds as a false positive; if that happens they
can whitelist it.

Requirements on their side: 64-bit Windows 10/11. The game uses the OpenGL
(Compatibility) renderer, so it runs on integrated graphics and older machines.

## Notes

- `build/`, `Magopoly.exe`, and `Magopoly.pck` are all git-ignored — don't
  `git add` the binary.
- `export_presets.cfg` holds the export settings (embed-PCK is on, output is
  `./build/Magopoly.exe`).
- Renderer is set to **Compatibility** in `project.godot`
  (`renderer/rendering_method="gl_compatibility"`).
