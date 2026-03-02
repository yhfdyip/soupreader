import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var originalBrightness: CGFloat?
  private var bootOverlay: UIView?

  private func installBootOverlayIfNeeded(controller: FlutterViewController) {
    if bootOverlay != nil { return }
    let view = controller.view
    let overlay = UIView(frame: view.bounds)
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.backgroundColor = UIColor.systemBackground

    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"

    let titleLabel = UILabel()
    titleLabel.text = "SoupReader"
    titleLabel.textAlignment = .center
    titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
    titleLabel.textColor = UIColor.label

    let metaLabel = UILabel()
    metaLabel.text = "native boot overlay\\nversion \(version) (\(build))\\n\\n如果此屏持续不消失，说明 Flutter 未完成首帧渲染。"
    metaLabel.textAlignment = .center
    metaLabel.numberOfLines = 0
    metaLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .medium)
    metaLabel.textColor = UIColor.secondaryLabel

    let stack = UIStackView(arrangedSubviews: [titleLabel, metaLabel])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false
    overlay.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
      stack.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -20),
    ])

    view.addSubview(overlay)
    bootOverlay = overlay
  }

  private func removeBootOverlay() {
    bootOverlay?.removeFromSuperview()
    bootOverlay = nil
  }

  private func bindBootOverlayChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "soupreader/boot_overlay",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate deallocated", details: nil))
        return
      }
      switch call.method {
      case "hide":
        DispatchQueue.main.async {
          self.removeBootOverlay()
          result(true)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      installBootOverlayIfNeeded(controller: controller)
      bindBootOverlayChannel(controller: controller)

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
        func filterCookies(
          _ cookies: [HTTPCookie],
          domain: String,
          includeSubdomains: Bool
        ) -> [HTTPCookie] {
          let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !trimmed.isEmpty else { return cookies }
          return cookies.filter { cookie in
            let d = cookie.domain.trimmingCharacters(in: .whitespacesAndNewlines)
            if d == trimmed { return true }
            if includeSubdomains {
              if d.hasSuffix("." + trimmed) { return true }
              if trimmed.hasSuffix("." + d) { return true }
            }
            return false
          }
        }

        func serializeCookies(_ cookies: [HTTPCookie]) -> [[String: Any]] {
          cookies.map { c in
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
        }

        switch call.method {
        case "getCookiesForUrl":
          guard let args = call.arguments as? [String: Any],
                let urlText = args["url"] as? String,
                let url = URL(string: urlText),
                let host = url.host
          else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "Missing url", details: nil))
            return
          }
          let includeSubdomains = args["includeSubdomains"] as? Bool ?? true
          store.getAllCookies { cookies in
            let filtered = filterCookies(
              cookies,
              domain: host,
              includeSubdomains: includeSubdomains
            )
            result(serializeCookies(filtered))
          }

        case "getCookies":
          guard let args = call.arguments as? [String: Any],
                let domain = args["domain"] as? String
          else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "Missing domain", details: nil))
            return
          }
          let includeSubdomains = args["includeSubdomains"] as? Bool ?? true
          store.getAllCookies { cookies in
            let filtered = filterCookies(
              cookies,
              domain: domain,
              includeSubdomains: includeSubdomains
            )
            result(serializeCookies(filtered))
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
