# AssetBridge — Offline Asset Library for Linux

AssetBridge is a desktop asset management tool for Linux designers and developers. It downloads icon packs and UI kits from GitHub or local files, indexes them into a fast SQLite database, and lets you search, preview, copy, and drag assets directly into design tools like Lunacy, Figma, and Inkscape — completely offline after the initial download.

---

## Features

### Icon Packs
- **GitHub Downloads** — Instantly fetch the latest releases of Phosphor, Tabler, Lucide, Heroicons, and Material Design Icons directly from GitHub.
- **Local Pack Support** — Add your own icon collections via ZIP files.
- **Fast Search** — SQLite-backed fuzzy search across icon names and auto-generated semantic tags (e.g. `arrow-up-right` → `direction`, `navigation`).
- **Copy SVG Source** — Tap any icon to copy its raw SVG to clipboard. Paste directly into Lunacy or any design tool as native vectors.
- **Drag & Drop** — Drag icons from the grid into Lunacy, Inkscape, or any GTK app that accepts file drops.

### UI Kits
- **Sketch File Support** — Add `.sketch` UI kits from local files or supported GitHub repositories.
- **Component Parsing** — Automatically unpacks and indexes individual artboards and symbol masters from Sketch libraries as separate searchable tiles.
- **Sketch → SVG Conversion** — Converts Sketch component JSON (shapes, paths, fills, strokes, groups, text) to clean SVG on the fly. Paste into Lunacy as native vectors — no plugins needed.
- **Live Component Preview** — Each component renders its own SVG preview thumbnail in the grid, throttled and cached so the app never crashes under load.
- **Supported UI Kit Sources** — macOS UI Kit, Bootstrap 5, Tailwind CSS Kit, and more via GitHub auto-download.

### General
- **XDG-Compliant** — All data stored in `~/.local/share/assetbridge/`, config in `~/.config/assetbridge/`, respecting Linux conventions.
- **Offline First** — After downloading, everything works with zero internet connection.
- **Dark / Light Theme** — Toggle in the top bar, persisted across sessions.
- **LRU Preview Cache** — Up to 150 converted SVG previews cached in memory; older entries evicted automatically.
- **Concurrent Load Throttling** — Max 4 SVG conversions run simultaneously, preventing memory spikes when browsing large UI kits.
- **Modern UI** — Built with Flutter desktop for smooth, high-performance rendering.

---

## Supported Icon Packs (Auto-Download)

| Pack | Icons | Source |
|---|---|---|
| Phosphor | 7,488 | github.com/phosphor-icons/core |
| Tabler | 4,200+ | github.com/tabler/tabler-icons |
| Lucide | 1,400+ | github.com/lucide-icons/lucide |
| Heroicons | 300+ | github.com/tailwindlabs/heroicons |
| Material Symbols | 2,500+ | github.com/google/material-design-icons |

## Supported UI Kits (Auto-Download)

| Kit | Source |
|---|---|
| macOS UI Kit | github.com/alexkaessner/macOS-UI-Kit |
| Bootstrap 5 UI Kit | github.com/themeselection/free-sketch-bootstrap-ui-kit |
| Tailwind CSS Kit | github.com/jessedobbelaere/tailwindcss-sketch-kit |
| Fomantic UI Kit | github.com/obsidiansystems/fomantic-sketch-ui-kit |

---

## How It Works

```
GitHub Release API
      │
      ▼
  Download ZIP / .sketch
      │
      ▼
  Extract to ~/.local/share/assetbridge/packs/<slug>/
  (.sketch files are also unzipped to a sibling directory)
      │
      ▼
  SvgIndexer walks the directory
  ├── SVG files → indexed by name + auto tags
  └── Sketch dirs (document.json + pages/) →
        SketchParser extracts artboards & groups →
        each component indexed with metadata JSON
      │
      ▼
  SQLite (Drift) — assets + packs tables
      │
      ▼
  Flutter grid UI
  ├── SVG tiles → flutter_svg renders inline
  └── Sketch tiles → SketchToSvg converts JSON → SVG string
                      → rendered via SvgPicture.string
                      → cached in LRU cache (max 150)
                      → throttled via Semaphore (max 4 concurrent)
```

---

## File Storage Layout

```
~/.local/share/assetbridge/
  ├── assetbridge.db          — SQLite database
  ├── packs/
  │   ├── phosphor/           — extracted icon pack
  │   ├── tabler/
  │   └── my_kit/
  │       ├── my_kit.sketch   — original .sketch file (kept as backup)
  │       └── my_kit/         — unzipped sketch library
  │           ├── document.json
  │           ├── meta.json
  │           ├── pages/
  │           │   └── <uuid>.json
  │           ├── images/
  │           └── previews/
  │               └── preview.png
  └── thumbnails/             — extracted preview images + temp SVG drag files

~/.config/assetbridge/        — user preferences (theme, window size)
```

---

## Documentation

- [Architecture](docs/architecture.md) — Technical overview and data flow.
- [Working Principle](docs/working.md) — How packs are fetched, extracted, and indexed.
- [Developer Setup](docs/setup.md) — Build and run instructions.
- [Modifying & Extending](docs/modify.md) — How to add new icon packs, UI kit sources, or custom parsers.
- [Code Explained](docs/codeexplain.md) — Deep dive into the main classes and models.

---

## Quick Start

```bash
# Prerequisites: Flutter 3.19+, libgtk-3-dev, libsqlite3-dev
flutter pub get
flutter run -d linux

# Release build
flutter build linux --release

# The binary is at:
# build/linux/x64/release/bundle/assetbridge
```

---

## Adding a Custom Icon Pack

1. Click **Add Pack** in the sidebar
2. Pick a `.zip` file containing SVG files
3. Optionally specify a subdirectory (e.g. `assets/svg`)
4. AssetBridge extracts, indexes, and makes it searchable immediately

## Adding a Custom UI Kit

1. Click **Add Pack** → **Add local pack**
2. Pick a `.sketch` file
3. Check **Treat as UI Kit**
4. AssetBridge unzips the Sketch bundle, parses all artboards and symbol masters as individual components, and renders each as a live SVG preview

---

## Copy & Paste into Lunacy

| Asset type | Action | Result in Lunacy |
|---|---|---|
| SVG icon | Tap tile | Copies SVG source → paste as native vectors ✅ |
| Sketch component | Tap tile | Converts to SVG → paste as native vectors ✅ |
| SVG icon | Drag to canvas | Drops as SVG file → Lunacy places as image |
| Sketch component | Drag to canvas | Converts to SVG file → drops into Lunacy |

> **Tip:** For best results with Lunacy, use **tap to copy** then **Ctrl+V** in Lunacy rather than drag & drop. Paste imports as fully editable vectors.

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI framework | Flutter 3.19+ (Linux desktop) |
| Database | Drift (SQLite, type-safe) |
| HTTP | Dio |
| SVG rendering | flutter_svg |
| Drag & drop | super_drag_and_drop |
| Clipboard | super_clipboard |
| File picking | file_picker |
| Paths | xdg_directories |
| State management | Riverpod |
| Archive | archive |

---

## Contributing

Pull requests welcome. When adding a new icon pack source:

1. Add a `PackConfig` entry to `lib/core/packs/pack_config.dart`
2. Verify the GitHub release zipball contains SVGs at a known path
3. Set `svgPathPrefix` to the folder containing SVGs inside the zip

When adding a UI kit source:

1. Add a `PackConfig` with `isUiKit: true`
2. Confirm the repo contains a `.sketch` file (zipped Sketch bundle)
3. The indexer handles unzipping and component parsing automatically

---

## Known Limitations

- Sketch → SVG conversion supports solid fills, gradients (approximated to first stop color), strokes, rectangles, ovals, bezier paths, groups, and text. Complex effects (blur, shadows, image fills) are not yet supported.
- Drag & drop into Lunacy places as a file drop — for fully editable vectors, use copy + paste instead.
- UI kit previews load asynchronously; large kits (200+ components) may take a few seconds to fully render thumbnails on first open.

---

*(c) 2026 AssetBridge Developer*