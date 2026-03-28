# Code Explained

This document explains the core components and classes that power AssetBridge.

## 1. Core Classes & Models

### `PackConfig` (`lib/core/packs/pack_config.dart`)
A lightweight configuration class for icon packs.
- **`name`**: Display name (e.g., "Phosphor").
- **`slug`**: Machine name used for folder paths and database keys.
- **`owner` & `repo`**: GitHub coordinates for predefined packs.
- **`isLocal`**: Inferred when `owner` or `repo` is null.

### `AppPaths` (`lib/core/paths/app_paths.dart`)
Utility for resolving Linux-specific XDG paths.
- **`dataRoot`**: Base path for application data.
- **`packsRoot`**: Folder where all extracted SVGs are stored.
- **`databaseFile`**: Path to the SQLite `assetbridge.db`.

## 2. The Indexing Engine

### `PackInstaller` (`lib/core/packs/pack_installer.dart`)
The main orchestrator for adding icon libraries.
- **`install()`**: Fetches from GitHub, extracts, and indexes.
- **`installLocal()`**: Extracts from a local ZIP file and indexes.
- **`_finishInstallation()`**: Shared logic for database insertion and SvgIndexer walk.

### `SvgIndexer` (`lib/core/indexer/svg_indexer.dart`)
Recursively walks an extracted pack directory.
- **`indexPackContents()`**: Identifies `*.svg` files and inserts them as `Assets` in the database.
- **Category Support**: Each folder in the pack structure is treated as a potential category.

## 3. Database Layer (Drift)

### `AppDatabase` (`lib/core/database/app_database.dart`)
The primary data source using Float-native SQLite.
- **`Packs`**: Represents an entire icon library collection.
- **`Assets`**: Represents a single SVG file with meta tags.

## 4. UI Components

### `DownloaderScreen` (`lib/features/downloader/downloader_screen.dart`)
A centralized place for managing icon sources.
- Displays supported GitHub packs.
- Provides a **FloatingActionButton** to add custom local ZIP archives.
- Shows real-time installation progress (downloading, extracting, indexing).

### `LibraryScreen` (`lib/features/library/library_screen.dart`)
The primary search and exploration interface.
- Filters by **Keyword**, **Category**, and **Pack**.
- Renders SVGs efficiently using `flutter_svg`.

---

*(c) 2026 AssetBridge Developers*
