import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // 隐藏系统标题栏，使用自定义标题栏
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)

    RegisterGeneratedPlugins(registry: flutterViewController)

    DispatchQueue.main.async { [weak self] in
      self?.shiftTrafficLights()
    }

    super.awakeFromNib()
  }

  private func shiftTrafficLights() {
    let xOffset: CGFloat = 8
    let yOffset: CGFloat = -3

    [self.standardWindowButton(.closeButton),
     self.standardWindowButton(.miniaturizeButton),
     self.standardWindowButton(.zoomButton)]
      .compactMap { $0 }
      .forEach { button in
        var frame = button.frame
        frame.origin.x += xOffset
        frame.origin.y += yOffset
        button.frame = frame
      }
  }
}
