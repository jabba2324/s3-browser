import Cocoa
import FlutterMacOS
import AVKit
import AVFoundation

@main
class AppDelegate: FlutterAppDelegate {
  private var videoWindow: NSWindow?
  private var playerView: AVPlayerView?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController

    // Set up method channel for native video player
    let videoChannel = FlutterMethodChannel(
      name: "com.s3browser/video",
      binaryMessenger: controller.engine.binaryMessenger
    )

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
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  private func presentVideoPlayer(url: URL) {
    DispatchQueue.main.async { [weak self] in
      // Create player
      let player = AVPlayer(url: url)

      // Create player view
      let playerView = AVPlayerView()
      playerView.player = player
      playerView.controlsStyle = .floating
      playerView.autoresizingMask = [.width, .height]

      // Calculate window size (16:9 aspect ratio, reasonable default)
      let windowWidth: CGFloat = 1280
      let windowHeight: CGFloat = 720

      // Get main screen for centering
      let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
      let windowX = screenFrame.midX - (windowWidth / 2)
      let windowY = screenFrame.midY - (windowHeight / 2)

      // Create window
      let window = NSWindow(
        contentRect: NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
      )

      window.title = "Video Player"
      window.contentView = playerView
      window.isReleasedWhenClosed = false
      window.minSize = NSSize(width: 480, height: 270)

      // Store references
      self?.videoWindow = window
      self?.playerView = playerView

      // Show window and play
      window.makeKeyAndOrderFront(nil)
      player.play()

      // Clean up when window closes
      NotificationCenter.default.addObserver(
        forName: NSWindow.willCloseNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        self?.playerView?.player?.pause()
        self?.playerView?.player = nil
        self?.playerView = nil
        self?.videoWindow = nil
      }
    }
  }
}
