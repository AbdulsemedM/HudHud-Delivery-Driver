import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let configChannel = "hudhud_delivery_driver/config"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let apiKey = resolveGoogleMapsApiKey()
    if !apiKey.isEmpty {
      GMSServices.provideAPIKey(apiKey)
    }

    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: configChannel,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "getGoogleMapsApiKey":
          result(self?.resolveGoogleMapsApiKey() ?? "")
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return result
  }

  private func resolveGoogleMapsApiKey() -> String {
    if let plistKey = Bundle.main.infoDictionary?["GoogleMapsAPIKey"] as? String,
       !plistKey.isEmpty,
       !plistKey.hasPrefix("$(") {
      return plistKey
    }
    if let envKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"],
       !envKey.isEmpty {
      return envKey
    }
    return ""
  }
}
