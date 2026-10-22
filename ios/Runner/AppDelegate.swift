import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let encoded = Bundle.main.object(forInfoDictionaryKey: "DartDefines") as? String {
      let defines = encoded.split(separator: ",").compactMap { Data(base64Encoded: String($0)) }.compactMap { String(data: $0, encoding: .utf8) }
      let key = defines.first(where: { $0.hasPrefix("GOOGLE_MAPS_IOS_API_KEY=") }) ?? defines.first(where: { $0.hasPrefix("GOOGLE_MAPS_API_KEY=") })
      if let key = key { GMSServices.provideAPIKey(String(key.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)[1])) }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
