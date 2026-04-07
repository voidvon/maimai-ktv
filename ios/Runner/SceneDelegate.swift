import Flutter
import Photos
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var pendingImageSaveResult: FlutterResult?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "ktv2_example/qr_image",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(code: "unavailable", message: "SceneDelegate is unavailable", details: nil)
        )
        return
      }
      switch call.method {
      case "saveQrImage":
        self.handleSaveQrImage(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handleSaveQrImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard pendingImageSaveResult == nil else {
      result(FlutterError(code: "busy", message: "An image save is already in progress", details: nil))
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let bytes = arguments["bytes"] as? FlutterStandardTypedData,
      let image = UIImage(data: bytes.data)
    else {
      result(FlutterError(code: "invalid_args", message: "Missing image bytes", details: nil))
      return
    }

    pendingImageSaveResult = result
    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
        self?.saveQrImage(image: image, authorizationStatus: status)
      }
    } else {
      PHPhotoLibrary.requestAuthorization { [weak self] status in
        self?.saveQrImage(image: image, authorizationStatus: status)
      }
    }
  }

  private func saveQrImage(image: UIImage, authorizationStatus: PHAuthorizationStatus) {
    switch authorizationStatus {
    case .authorized, .limited:
      DispatchQueue.main.async {
        UIImageWriteToSavedPhotosAlbum(
          image,
          self,
          #selector(self.image(_:didFinishSavingWithError:contextInfo:)),
          nil
        )
      }
    default:
      let result = pendingImageSaveResult
      pendingImageSaveResult = nil
      result?(
        FlutterError(code: "permission_denied", message: "没有相册写入权限", details: nil)
      )
    }
  }

  @objc
  private func image(
    _ image: UIImage,
    didFinishSavingWithError error: Error?,
    contextInfo: UnsafeMutableRawPointer?
  ) {
    let result = pendingImageSaveResult
    pendingImageSaveResult = nil
    if let error {
      result?(FlutterError(code: "save_failed", message: error.localizedDescription, details: nil))
      return
    }
    result?(nil)
  }
}
