import Flutter
import UIKit
import AVKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var sharedFilesChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set up method channel for native video player
    let controller = window?.rootViewController as! FlutterViewController
    let videoChannel = FlutterMethodChannel(
      name: "com.s3browser/video",
      binaryMessenger: controller.binaryMessenger
    )

    // Set up method channel for shared files
    sharedFilesChannel = FlutterMethodChannel(
      name: "com.s3browser/shared_files",
      binaryMessenger: controller.binaryMessenger
    )

    sharedFilesChannel?.setMethodCallHandler { (call, result) in
      if call.method == "getPendingSharedFiles" {
        if let userDefaults = UserDefaults(suiteName: "group.com.otacon.s3browser"),
           let files = userDefaults.array(forKey: "pending_shared_files") as? [String] {
          // Clear after reading
          userDefaults.removeObject(forKey: "pending_shared_files")
          userDefaults.synchronize()
          result(files)
        } else {
          result([String]())
        }
      } else if call.method == "clearSharedFiles" {
        // Clean up files from shared container
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.otacon.s3browser") {
          let sharedFilesDir = containerURL.appendingPathComponent("SharedFiles")
          try? FileManager.default.removeItem(at: sharedFilesDir)
        }
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    videoChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "playVideo" {
        guard let args = call.arguments as? [String: Any],
              let urlString = args["url"] as? String,
              let url = URL(string: urlString) else {
          result(FlutterError(code: "INVALID_URL", message: "Invalid video URL", details: nil))
          return
        }

        self?.presentVideoPlayer(url: url)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // Set up method channel for sharing credentials with extension
    let credentialsChannel = FlutterMethodChannel(
      name: "com.s3browser/credentials",
      binaryMessenger: controller.binaryMessenger
    )

    credentialsChannel.setMethodCallHandler { (call, result) in
      if call.method == "saveCredentialsForExtension" {
        guard let args = call.arguments as? [String: Any],
              let credentials = args["credentials"] as? [[String: String]] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
          return
        }

        // Save to shared App Group UserDefaults
        if let userDefaults = UserDefaults(suiteName: "group.com.otacon.s3browser") {
          userDefaults.set(credentials, forKey: "saved_credentials")
          userDefaults.synchronize()
          result(true)
        } else {
          result(FlutterError(code: "STORAGE_ERROR", message: "Could not access shared storage", details: nil))
        }
      } else if call.method == "clearCredentialsForExtension" {
        if let userDefaults = UserDefaults(suiteName: "group.com.otacon.s3browser") {
          userDefaults.removeObject(forKey: "saved_credentials")
          userDefaults.synchronize()
          result(true)
        } else {
          result(FlutterError(code: "STORAGE_ERROR", message: "Could not access shared storage", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func presentVideoPlayer(url: URL) {
    // Configure audio session to play sound even when mute switch is on
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Failed to configure audio session: \(error)")
    }

    let player = AVPlayer(url: url)
    let playerViewController = AVPlayerViewController()
    playerViewController.player = player

    DispatchQueue.main.async {
      if let rootViewController = self.window?.rootViewController {
        rootViewController.present(playerViewController, animated: true) {
          player.play()
        }
      }
    }
  }

  // Handle URL scheme for share extension
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if url.scheme == "s3browser" && url.host == "share" {
      // Notify Flutter that we have shared files to process
      sharedFilesChannel?.invokeMethod("onSharedFilesReceived", arguments: nil)
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
