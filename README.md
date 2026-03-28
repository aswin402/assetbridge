# AssetBridge — Offline icon library for Linux

AssetBridge is a desktop icon management tool for Linux that pulls icon packs from GitHub or local ZIP files, extracts them, and provides a fast, searchable interface for designers and developers.

## Features
- **GitHub Downloads**: Instantly fetch the latest releases (Phosphor, Tabler, Lucide, Heroicons, Material Design).
- **Local Pack Support**: Add your own icon collections via ZIP files.
- **SQLite Indexing**: Blazing fast search based on SVG path names and directory structure.
- **XDG-Compliant**: Stores everything safely in `~/.local/share/assetbridge/`, respecting standard Linux conventions.
- **Modern UI**: Built with Flutter for a smooth, high-performance experience.

## Documentation
- [Architecture](docs/architecture.md) — Technical overview and data flow.
- [Working Principle](docs/working.md) — How icon packs are fetched, extracted, and indexed.
- [Developer Setup](docs/setup.md) — Build and run instructions.
- [Modifying & Extending](docs/modify.md) — How to add new features or custom parsers.
- [Code Explained](docs/codeexplain.md) — Deep dive into the main classes and models.

---

*(c) 2026 AssetBridge Developer*
