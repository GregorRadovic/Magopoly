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

## Building for macOS

There's no macOS preset in the project yet (only "Windows Desktop" exists,
and it was built on Windows). Godot can export a macOS build from any host
OS, including this Windows machine — you don't need a Mac to *build* it,
just to *test* it:

1. **Project → Export…** → **Add…** → **macOS**. Godot creates the preset
   with sensible defaults.
2. Set its output path to `build/Magopoly.zip` (macOS exports as a `.zip`
   containing `Magopoly.app`, not a bare binary).
3. Turn on ETC2/ASTC texture import — this is a **project setting**, not a
   per-preset export option (macOS's export plugin doesn't expose it in the
   preset the way older Godot versions did): **Project → Project Settings →
   Rendering → Textures → VRAM Compression → Import Etc2 Astc** (flip
   **Advanced Settings**, top-right of that window, if the group isn't
   visible). Already set to `true` in `project.godot`. Apple Silicon Macs
   (arm64) need ASTC-compressed textures — Intel Macs use S3TC/BPTC like
   Windows does. Exporting **Universal** or **arm64** with this off either
   fails outright or ships broken textures on M-series Macs; enabling it
   makes the import cache a bit bigger (one-time reimport) but runs
   natively everywhere.
4. Under the preset's options, **Codesign**: pick **Ad-Hoc** (no Apple
   Developer account needed). This doesn't remove the Gatekeeper warning
   below, but it does avoid a harder "app is damaged" error some macOS
   versions show for completely unsigned bundles.
5. **Export Project…**. The same 4.7 export templates you already downloaded
   cover macOS too — no second download.
6. Commit the new preset entry in `export_presets.cfg` so it's there next
   time (the `.zip`/`.app` itself stays out of git, same as the Windows build).

### What Mac players will see

Gatekeeper blocks unsigned/ad-hoc apps harder than Windows SmartScreen does.
The first time they open it, right-click (or Control-click) `Magopoly.app` →
**Open** → **Open** in the dialog — a plain double-click will just refuse.
If macOS still calls it "damaged", they can run this once in Terminal:
```
xattr -cr /path/to/Magopoly.app
```
The only way to remove this warning entirely is notarizing through a paid
Apple Developer account ($99/yr) — not needed to ship, just smoother.

## Publishing a release

1. Build (`.\build.ps1 -Zip`), and separately export the macOS `.zip` if
   you're shipping that too.
2. On GitHub: **Releases → Draft a new release**, pick a tag (e.g. `v1.0`).
3. Drag `build\Magopoly.exe` (or the `.zip`) — and `Magopoly-macOS.zip` if you
   have one — into the **"Attach binaries"** box and publish. Release assets
   allow up to 2 GB per file and stay out of git. Name the files so players
   can tell which is which (e.g. `Magopoly-Windows.zip` / `Magopoly-macOS.zip`).

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
