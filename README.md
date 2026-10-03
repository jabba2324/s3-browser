# S3 Browser

A Flutter application for browsing AWS S3 buckets and S3-compatible storage services.

## Features

- Connect to AWS S3 or S3-compatible services (like Exoscale)
- Browse bucket contents with folder navigation
- View and download files
- Photo viewer with navigation for images
- Native video player for iOS (mp4, mov, m4v, etc.)
- Save multiple connection credentials securely
- Support for iOS and Web platforms

## Running the App

### Web

```bash
flutter run -d chrome
```

### iOS

1. Open iOS Simulator or connect your iPhone

2. Run the app:
```bash
flutter run -d ios
```

Or open in Xcode (Xcode resolves Swift Package Manager dependencies automatically on build):
```bash
open ios/Runner.xcworkspace
```

## iOS Configuration

The app is configured with:
- Minimum iOS version: 15.0
- Network permissions for S3 access (NSAppTransportSecurity)
- URL scheme support for opening download links
- All device orientations supported

## Setup

1. Install Flutter dependencies:
```bash
flutter pub get
```

iOS native dependencies are resolved via Swift Package Manager, which Xcode/`flutter build` handle automatically - no separate install step needed.

## CORS Configuration

For web usage, your S3 bucket must have CORS configured. Example CORS rule:

```json
{
  "CORSRules": [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "POST", "PUT", "HEAD"],
      "AllowedOrigins": ["*"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3000
    }
  ]
}
```

Note: iOS does not require CORS configuration.

## Project Structure

- `lib/main.dart` - App entry point
- `lib/screens/credentials_screen.dart` - AWS credentials input
- `lib/screens/s3_browser_screen.dart` - S3 bucket browser
- `lib/screens/photo_viewer_screen.dart` - Photo viewer with navigation
- `lib/services/auth_s3_service.dart` - S3 connection management
- `lib/services/auth_storage_service.dart` - Secure credential storage
- `lib/services/s3_browser_service.dart` - S3 browsing operations
