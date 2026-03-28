# Setup & Build (Linux)

AssetBridge is currently focused on the Linux desktop environment. This document outlines the prerequisites and steps needed to set up a development environment and build the application.

## Prerequisites
Before you begin, ensure you have the following installed on your Linux system:

- **Flutter SDK**: [Follow the official Linux setup guide](https://docs.flutter.dev/get-started/install/linux).
- **SQLite3 Libraries**:
  ```bash
  sudo apt install libsqlite3-dev
  ```
- **Standard Build Tools**:
  ```bash
  sudo apt install build-essential pkg-config
  ```

## 1. Clone & Initialize
```bash
git clone https://github.com/aswin402/assetbridge.git
cd assetbridge
```

## 2. Install Dependencies
```bash
flutter pub get
```

## 3. Generate Code
AssetBridge uses **Drift (Moor)** for its database and **Riverpod Generator** (if used) for state. Run the build command:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 4. Run the App
```bash
flutter run -d linux
```

## Build for Distribution
To create a production-ready Linux binary:
```bash
flutter build linux
```
The compiled binary will be located in `build/linux/x64/release/bundle/assetbridge`.

## Data Locations
When running in development or production, AssetBridge stores its data in:
- **Index Database**: `~/.local/share/assetbridge/assetbridge.db`
- **Extracted Icons**: `~/.local/share/assetbridge/packs/`
