import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var directoryPickerChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureDirectoryPickerChannel(for: flutterViewController)

    super.awakeFromNib()
  }

  private func configureDirectoryPickerChannel(for flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "ktv2_example/macos_directory_picker",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    directoryPickerChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "window_unavailable", message: "Main window unavailable", details: nil))
        return
      }

      guard call.method == "pickDirectory" else {
        result(FlutterMethodNotImplemented)
        return
      }

      let arguments = call.arguments as? [String: Any]
      let initialDirectory = arguments?["initialDirectory"] as? String
      self.presentDirectoryPicker(initialDirectory: initialDirectory, result: result)
    }
  }

  private func presentDirectoryPicker(
    initialDirectory: String?,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        result(FlutterError(code: "window_unavailable", message: "Main window unavailable", details: nil))
        return
      }

      let openPanel = NSOpenPanel()
      openPanel.title = "选择媒体目录"
      openPanel.message = "请选择要扫描的歌曲目录"
      openPanel.prompt = "选择目录"
      openPanel.canChooseFiles = false
      openPanel.canChooseDirectories = true
      openPanel.allowsMultipleSelection = false
      openPanel.canCreateDirectories = false
      openPanel.resolvesAliases = true

      if let initialDirectory, !initialDirectory.isEmpty {
        let initialUrl = URL(fileURLWithPath: initialDirectory, isDirectory: true)
        if FileManager.default.fileExists(atPath: initialUrl.path) {
          openPanel.directoryURL = initialUrl
        }
      }

      NSApp.activate(ignoringOtherApps: true)
      self.makeKeyAndOrderFront(nil)

      let response = openPanel.runModal()
      guard response == .OK else {
        result(nil)
        return
      }

      result(openPanel.url?.path)
    }
  }
}
