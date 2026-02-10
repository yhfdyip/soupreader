import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var originalBrightness: CGFloat?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "soupreader/screen_brightness",
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate deallocated", details: nil))
          return
        }

        switch call.method {
        case "setBrightness":
          if self.originalBrightness == nil {
            self.originalBrightness = UIScreen.main.brightness
          }
          guard
            let args = call.arguments as? [String: Any],
            let value = args["brightness"] as? Double
          else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "Missing brightness", details: nil))
            return
          }
          let clamped = min(max(value, 0.0), 1.0)
          UIScreen.main.brightness = CGFloat(clamped)
          result(nil)

        case "resetBrightness":
          if let original = self.originalBrightness {
            UIScreen.main.brightness = original
            self.originalBrightness = nil
          }
          result(nil)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      let keepScreenOnChannel = FlutterMethodChannel(
        name: "soupreader/keep_screen_on",
        binaryMessenger: controller.binaryMessenger
      )

      keepScreenOnChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "setEnabled":
          guard let args = call.arguments as? [String: Any],
                let enabled = args["enabled"] as? Bool
          else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "Missing enabled", details: nil))
            return
          }
          UIApplication.shared.isIdleTimerDisabled = enabled
          result(nil)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      let cookiesChannel = FlutterMethodChannel(
        name: "soupreader/webview_cookies",
        binaryMessenger: controller.binaryMessenger
      )

      cookiesChannel.setMethodCallHandler { call, result in
        let store = WKWebsiteDataStore.default().httpCookieStore

        switch call.method {
        case "getCookies":
          guard let args = call.arguments as? [String: Any],
                let domain = args["domain"] as? String
          else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "Missing domain", details: nil))
            return
          }
          let includeSubdomains = args["includeSubdomains"] as? Bool ?? true
          store.getAllCookies { cookies in
            let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
            let filtered = cookies.filter { cookie in
              let d = cookie.domain.trimmingCharacters(in: .whitespacesAndNewlines)
              if trimmed.isEmpty { return true }
              if d == trimmed { return true }
              if includeSubdomains {
                if d.hasSuffix("." + trimmed) { return true }
                if trimmed.hasSuffix("." + d) { return true }
              }
              return false
            }

            let out: [[String: Any]] = filtered.map { c in
              var m: [String: Any] = [
                "name": c.name,
                "value": c.value,
                "domain": c.domain,
                "path": c.path,
                "secure": c.isSecure,
                "httpOnly": c.isHTTPOnly
              ]
              if let exp = c.expiresDate {
                m["expiresMs"] = Int(exp.timeIntervalSince1970 * 1000.0)
              }
              return m
            }
            result(out)
          }

        case "clearAllCookies":
          store.getAllCookies { cookies in
            if cookies.isEmpty {
              result(true)
              return
            }
            let group = DispatchGroup()
            for c in cookies {
              group.enter()
              store.delete(c) {
                group.leave()
              }
            }
            group.notify(queue: .main) {
              result(true)
            }
          }

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
