# Architecture Overview

AssetBridge is designed to be a lightweight, offline-first icon manager for Linux desktop users. It follows a modular architecture that separates data storage, metadata indexing, and user interface.

## 1. Storage Layers (XDG)
AssetBridge strictly adheres to the **XDG Base Directory Specification**. This ensures it feels like a native Linux application:

- **Data Home (`~/.local/share/assetbridge/`)**: Stores the extracted SVG icon packs and the SQLite database.
- **Config Home (`~/.config/assetbridge/`)**: Reserved for user preferences (UI settings, custom sources).

## 2. Metadata Engine (Drift/SQLite)
Instead of scanning the filesystem on every search, AssetBridge uses a **SQLite** database via the **Drift** library for Dart.

- **Packs Table**: Stores the name, version, local path, and icon count for each library.
- **Assets Table**: Stores individual SVG metadata including filename, path, tags, and category (parsed from folder structure).

## 3. State Management (Riverpod)
The application uses **Flutter Riverpod** for predictable state management:

- **Library States**: Reactive filters for searching and categorizing icons.
- **Installation States**: Notifiers to track the progress of ongoing downloads or ZIP extractions.

## 4. Key Libraries
- **Dio**: Handles GitHub API requests and ZIP downloads.
- **Archive**: Performs fast extraction of ZIP files into the local data root.
- **Flutter SVG**: High-performance SVG rendering in the UI.
- **File Picker**: Native Linux file selection for adding local icon packs.

## Data Flow Diagram
```mermaid
graph TD
    A[GitHub API / Local ZIP] -->|Fetch/Pick| B[PackInstaller]
    B -->|Extract| C[~/.local/share/assetbridge/packs/]
    B -->|Analyze| D[SvgIndexer]
    D -->|Insert Metadata| E[SQLite (Drift)]
    E -->|Reactive Stream| F[Riverpod Providers]
    F -->|Render| G[Flutter UI]
```
