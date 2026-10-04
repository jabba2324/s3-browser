import Flutter
import UIKit
import XCTest

@testable import Runner

class RunnerTests: XCTestCase {

  /// Regression guard for a bug where native video playback silently failed
  /// to present after the app migrated to the UIScene lifecycle:
  /// AppDelegate.window is never populated under Scenes (the window lives on
  /// FlutterSceneDelegate instead), so looking up the root view controller via
  /// self.window always returned nil, and AVPlayerViewController.present(...)
  /// was silently skipped.
  ///
  /// This is a host-app unit test (see TEST_HOST in project.pbxproj), so it
  /// runs inside a live Runner.app with a real connected UIWindowScene -
  /// exactly the precondition the old self.window-based lookup failed under.
  func testKeyWindowRootViewControllerResolvesUnderSceneLifecycle() {
    let appDelegate = AppDelegate()

    let rootViewController = appDelegate.keyWindowRootViewController()

    XCTAssertNotNil(
      rootViewController,
      "Expected a key window's root view controller to be resolvable via the active UIWindowScene"
    )
  }

}
