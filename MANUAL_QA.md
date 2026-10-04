# Manual QA checklist

Run through this before cutting any TestFlight/App Store build. These cover paths that
are either native iOS lifecycle behavior (not reachable by `flutter test`) or depend on
real device/share-sheet interaction that can't be automated in this project's current
test setup.

- [ ] **Share into the app while backgrounded.** Open S3 Browser, then switch to another
  app (don't force-quit it). Share a file into S3 Browser via the share sheet. The app
  should foreground and show the upload screen for that file.
- [ ] **Share into the app from a cold start.** Force-quit S3 Browser, then share a file
  into it via the share sheet from another app. It should launch straight into the
  upload screen.
- [ ] **Tap-to-play video.** From the browser, tap a video file. The native player should
  present and play - not just briefly show/flash the screen before returning.
- [ ] **Rename or copy a file with a space or special character in its name** (e.g.
  `"a report (draft).pdf"`). It should complete without a 403/404 or being misfiled under
  a new prefix.
