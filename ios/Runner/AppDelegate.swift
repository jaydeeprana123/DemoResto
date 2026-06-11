import Flutter
import UIKit
import receive_sharing_intent

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let handled = ReceiveSharingIntentPlugin.instance.application(
      app,
      open: url,
      options: options
    )
    if handled {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
