# Modifying & Extending AssetBridge

AssetBridge is designed to be easily extensible. This document explains how to add new predefined icon packs or modify the core indexing logic.

## 1. Adding a Predefined GitHub Pack
To add a new icon pack to the "Download" list, update `lib/core/packs/pack_config.dart`.

```dart
const supportedPacks = [
  ...
  PackConfig(
    name: 'My New Pack',
    slug: 'my-new-pack',
    owner: 'github-owner',
    repo: 'repository-name',
    svgPathPrefix: 'path/to/svgs', // Optional
  ),
];
```

## 2. Modifying the SVG Indexer
If you need to handle specific filename patterns (e.g., Lucide uses `heart.svg` while Material Icons uses `ic_round_heart.svg`), modify `lib/core/indexer/tag_parser.dart`.

- **`tagsFromSvgFilename`**: Extract tags from file names.
- **`categoryFromRelativePath`**: Infer categories from directory structure.

## 3. Database Schema Updates
If you need to store more metadata (e.g., icon license, creator), update:
- **`lib/core/database/app_database.dart`**: Add columns to `Packs` or `Assets` tables.
- **Run the build-runner**: `flutter pub run build_runner build` (Crucial!).

## 4. UI Customization
AssetBridge uses standard Flutter Material 3 components. The main screens are located in:
- `lib/features/downloader/`: Installation and updates.
- `lib/features/library/`: Search and browsing.

---

*(c) 2026 AssetBridge Developers*
