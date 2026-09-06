import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// One ayah does not need a 800x600 canvas. Tall rather than wide: Arabic at
  /// 30pt plus a tafsir-length translation is a column, not a page.
  static let contentSize = NSSize(width: 460, height: 620)

  /// Placed near the top of the screen rather than centred, so the window sits
  /// where a glance goes and does not cover what is behind it.
  static let topMargin: CGFloat = 24

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.contentMinSize = NSSize(width: 380, height: 420)
    self.setContentSize(MainFlutterWindow.contentSize)
    self.placeNearTop()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  /// `visibleFrame` excludes the menu bar and the Dock, so this cannot land
  /// underneath either of them on any display arrangement.
  private func placeNearTop() {
    guard let visible = (self.screen ?? NSScreen.main)?.visibleFrame else { return }

    let size = self.frame.size
    self.setFrameOrigin(NSPoint(
      x: visible.midX - size.width / 2,
      y: visible.maxY - size.height - MainFlutterWindow.topMargin
    ))
  }
}
