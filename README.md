# TubeArchivist Companion (YouTube Clone)

A feature-rich Flutter client for [TubeArchivist](https://github.com/tubearchivist/tubearchivist), designed to provide a "YouTube clone" experience for your self-hosted video archive.

## New Features

- **Cross-Platform Video Playback**: Now powered by `media_kit` for high-performance playback on **Android**, **macOS**, and **Windows**.
- **Discover & Latest Filters**: Toggle between a random interleaved "Discover" feed and a chronological "Latest" feed.
- **Channel Pages**: Browse videos specifically from your favorite archived channels.
- **Library & History**: 
  - **Continue Watching**: Pick up right where you left off.
  - **Watch History**: Revisit your recently watched videos.
- **Enhanced Player Experience**:
  - **Related Videos**: Navigate through suggested content.
  - **Comments**: View indexed comments from the original YouTube videos.
  - **Responsive Layout**: Optimized side-by-side view for desktop and vertical stack for mobile.
- **Improved Downloads**: 
  - Retry failed downloads directly from the queue.
  - Add new YouTube URLs to your TubeArchivist server from within the app.

## Platform Support

- [x] Android
- [x] macOS (Network client entitlements enabled)
- [x] Windows
- [x] Web (Basic support)

## Getting Started

1.  Ensure you have Flutter installed.
2.  Configure your TubeArchivist Server URL and API Token in the **Settings** tab.
3.  On macOS, ensure you are running on a machine with the necessary entitlements.

### Development

To run the app:
```bash
flutter run -d macos  # For macOS
flutter run -d windows # For Windows
flutter run           # For default device
```

## Dependencies

- `media_kit`: Cross-platform video engine.
- `http` & `dio`: API communication.
- `cached_network_image`: Efficient thumbnail loading.
- `shared_preferences`: Local settings storage.
