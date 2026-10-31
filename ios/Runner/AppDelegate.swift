import Flutter
import SwiftUI
import UIKit
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var alarmChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets flutter_local_notifications show reminders and handle taps.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Bridge for real system alarms (lib/services/reminders.dart).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PillTimeAlarms") {
      let channel = FlutterMethodChannel(
        name: "pilltime/alarms", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        PillTimeAlarms.handle(call, result: result)
      }
      alarmChannel = channel
    }
  }
}

/// Handles "isSupported", "requestAuthorization" and "reschedule" calls.
enum PillTimeAlarms {
  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      switch call.method {
      case "isSupported":
        result(true)
      case "requestAuthorization":
        Task { @MainActor in result(await AlarmScheduler.requestAuthorization()) }
      case "reschedule":
        let items = (call.arguments as? [[String: Any]]) ?? []
        let alarms: [(Date, String)] = items.compactMap { item in
          guard let ms = (item["time"] as? NSNumber)?.doubleValue,
                let title = item["title"] as? String else { return nil }
          return (Date(timeIntervalSince1970: ms / 1000), title)
        }
        Task { @MainActor in result(await AlarmScheduler.reschedule(alarms)) }
      default:
        result(FlutterMethodNotImplemented)
      }
      return
    }
    #endif
    switch call.method {
    case "isSupported": result(false)
    case "requestAuthorization", "reschedule": result(false)
    default: result(FlutterMethodNotImplemented)
    }
  }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
enum AlarmScheduler {
  struct PillMetadata: AlarmMetadata {}

  static func requestAuthorization() async -> Bool {
    let manager = AlarmManager.shared
    switch manager.authorizationState {
    case .authorized:
      return true
    case .denied:
      return false
    case .notDetermined:
      let state = try? await manager.requestAuthorization()
      return state == .authorized
    @unknown default:
      return false
    }
  }

  /// Replaces all of this app's alarms. Returns false if alarms aren't allowed.
  static func reschedule(_ alarms: [(Date, String)]) async -> Bool {
    guard await requestAuthorization() else { return false }
    let manager = AlarmManager.shared
    if let existing = try? manager.alarms {
      for alarm in existing {
        try? manager.cancel(id: alarm.id)
      }
    }
    for (time, title) in alarms where time > Date() {
      let alert = AlarmPresentation.Alert(
        title: LocalizedStringResource(stringLiteral: title),
        stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"))
      let attributes = AlarmAttributes<PillMetadata>(
        presentation: AlarmPresentation(alert: alert),
        metadata: PillMetadata(),
        tintColor: .green)
      let config = AlarmManager.AlarmConfiguration<PillMetadata>.alarm(
        schedule: .fixed(time),
        attributes: attributes)
      _ = try? await manager.schedule(id: UUID(), configuration: config)
    }
    return true
  }
}
#endif
