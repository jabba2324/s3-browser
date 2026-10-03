# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Flutter app for browsing AWS S3 and S3-compatible buckets (e.g. Exoscale), targeting **iOS and Web**. It connects directly to S3 using the `minio` package (S3-compatible client, so a custom `endpoint` can be supplied instead of AWS). Credentials are entered by the user and stored securely on-device — there is no backend server.

## Commands

```bash
flutter pub get               # install dependencies
flutter run -d chrome         # run on Web
flutter run -d ios            # run on iOS simulator/device (resolves Swift Package Manager deps automatically)

flutter analyze                # lint (flutter_lints, configured in analysis_options.yaml)
flutter test                   # run all tests
flutter test test/widget_test.dart   # run a single test file

open ios/Runner.xcworkspace    # open iOS project directly in Xcode
```

There is no CI config in this repo — `flutter analyze` and `flutter test` are the manual gate before committing.

### Versioning

`pubspec.yaml`'s `version: X.Y.Z+N` controls both the app version and the native build number (`+N` is `CFBundleVersion`/iOS build number). Bump `+N` whenever a build is shipped to TestFlight/App Store, independent of whether `X.Y.Z` changes.

## Architecture

### Platform abstraction via conditional exports

Code that differs between Web and native (iOS) lives under `lib/platform/`, split as `foo.dart` (the public export shim), `foo_native.dart`, and `foo_web.dart`:

```dart
export 'file_handler_native.dart' if (dart.library.html) 'file_handler_web.dart';
```

The rest of the app imports only `foo.dart` and never checks platform inside shared code (aside from `kIsWeb` guards for optional native-only integrations like the iOS Share Extension). When adding platform-specific behavior, follow this split rather than branching on `kIsWeb` inside shared widgets/services. Existing pairs: `file_handler`, `photo_viewer`, `video_viewer`.

### Layering: Services → Controllers → Screens/Widgets

- **Services** (`lib/services/`) wrap external I/O with no Flutter/UI dependency: `AuthS3Service` owns the `Minio` client and connection lifecycle; `S3BrowserService` does the actual S3 listing/upload/download/rename/copy against a fixed `bucketName`; `FileOperationsService` composes browser-service calls into higher-level file operations (returning `FileOperationResult`); `AuthStorageService` persists credentials via `flutter_secure_storage`; `ShareExtensionService` bridges to the iOS Share Extension over a `MethodChannel`; `SharedFilesService` polls for files shared into the app from other apps.
- **Controllers** (`lib/controllers/`) are `ChangeNotifier`s that hold UI state and call into services — e.g. `S3BrowserController` holds the object list, sort/filter/selection state, and loading/error state for one bucket+prefix.
- **Screens** (`lib/screens/`) are `StatefulWidget`s that own a controller instance and render against it; shared presentational pieces live in `lib/widgets/`, grouped by purpose (`dialogs/`, `sheets/`, `tiles/`, `cards/`, `media/`, `states/`, `upload/`) and re-exported through a per-folder barrel file (e.g. `widgets/tiles/tiles.dart`). `lib/models/models.dart` is the same barrel pattern for data models.

### Folder navigation is screen-stack-based, not state-based

`S3BrowserScreen` takes an `initialPrefix` and constructs an `S3BrowserController` scoped to that single prefix (`currentPrefix` is immutable on the controller). Navigating into a folder pushes a **new** `S3BrowserScreen` route with `initialPrefix` set to the folder's key, rather than mutating prefix state in place — so "going up" a level is just the platform back button/gesture, and each folder depth is its own screen/controller instance. When extending folder browsing, keep this one-controller-per-prefix-per-route model; don't reintroduce in-place prefix mutation. Because every folder level is its own screen instance, UI details that should only appear once (e.g. the "Logout" menu item) must be explicitly gated on `initialPrefix.isEmpty` rather than assumed to run once per app session. Logging out calls `Navigator.popUntil(isFirst)` before popping, to unwind the whole folder stack back to the root.

### S3 listing semantics

`S3BrowserService.listObjects` lists one directory level at a time by relying on S3's common-prefix grouping (passing `prefix` to `client.listObjects` and reading `result.prefixes` for subfolders vs `result.objects` for files), then filters client-side to only the single relative level requested. It does not recurse — nested-folder awareness comes entirely from calling it again with a deeper prefix (see folder navigation above).

### Cross-app file sharing (iOS)

Two independent mechanisms exist and are easy to conflate:
- **Outbound**: `ShareExtensionService` pushes the current saved credentials to shared storage over a `MethodChannel` so the native iOS Share Extension (sharing *into* this app from other apps) can authenticate without the Flutter app running.
- **Inbound**: `SharedFilesService` + `main.dart`'s `_initSharedFilesHandler` detect files that were shared into the app (via the Share Extension) and route to `SharedUploadScreen` through the global `navigatorKey`, both on a startup delay and via a live callback.

Both are no-ops on Web (`kIsWeb` early-return).
