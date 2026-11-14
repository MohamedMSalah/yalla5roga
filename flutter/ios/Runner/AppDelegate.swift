import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var chatActions: FlutterMethodChannel?
  private var pendingChatAction: [String: Any]?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OutingChatActions") {
      let channel = FlutterMethodChannel(name: "yalla5roga/chat_notification_actions", binaryMessenger: registrar.messenger())
      chatActions = channel
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "takeInitialAction" {
          result(self?.pendingChatAction)
          self?.pendingChatAction = nil
        } else { result(FlutterMethodNotImplemented) }
      }
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let content = response.notification.request.content
    let action = response.actionIdentifier
    // Local notifications already carry their serialized payload and use the plugin.
    if content.categoryIdentifier == "outing_chat", content.userInfo["payload"] == nil,
       action == "reply_action" || action == "mark_read_action" {
      var data: [String: Any] = [:]
      for (key, value) in content.userInfo { if let key = key as? String { data[key] = value } }
      data["actionType"] = action == "reply_action" ? "reply" : "mark_read"
      if let reply = response as? UNTextInputNotificationResponse { data["replyText"] = reply.userText }
      pendingChatAction = data
      chatActions?.invokeMethod("chatAction", arguments: data)
      completionHandler()
      return
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
