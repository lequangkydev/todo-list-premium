import UIKit
import Flutter
import FirebaseCore
import google_mobile_ads
import FBAudienceNetwork
import FBSDKCoreKit
import flutter_local_notifications
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var backupFolder: BackupFolderChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // meta ads
        FBAdSettings.setAdvertiserTrackingEnabled(true)
        FBSDKCoreKit.ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        
        GeneratedPluginRegistrant.register(with: self)
        // Notification actions (Done / Snooze) run in a background isolate
        FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
            GeneratedPluginRegistrant.register(with: registry)
        }
        UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        if let registrar = registrar(forPlugin: "BackupFolderChannel") {
            backupFolder = BackupFolderChannel(messenger: registrar.messenger())
        }
        //    FirebaseApp.configure()
        registerAdFactory()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func registerAdFactory() {
        FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
            self, factoryId: "bottomExtraNativeAd", nativeAdFactory: ExtraNativeAdFactory())
        FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
            self, factoryId: "topExtraNativeAd", nativeAdFactory: ExtraNativeAdFactory(buttonPosition: ButtonPosition.top))
        FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
            self, factoryId: "bottomNormalNativeAd", nativeAdFactory: NormalNativeAdFactory())
        FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
            self, factoryId: "topNormalNativeAd", nativeAdFactory: NormalNativeAdFactory(buttonPosition: ButtonPosition.top))
        FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
            self, factoryId: "homeNativeAd", nativeAdFactory: HomeNativeAdFactory())
        FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
            self, factoryId: "smallNativeAd", nativeAdFactory: SmallNativeAdFactory())
        FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
            self, factoryId: "fullNativeAd", nativeAdFactory: FullNativeAdFactory())
        
    }
}

/// A folder the user picks in Files (iCloud Drive, On My iPhone, another
/// provider) that daily backups are copied to. Access is kept with a
/// security-scoped bookmark, so it works across launches without the app
/// needing an iCloud container of its own.
final class BackupFolderChannel: NSObject, UIDocumentPickerDelegate {
    private static let bookmarkKey = "backup_folder_bookmark"
    private let channel: FlutterMethodChannel
    private var pending: FlutterResult?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "todolist/backup_folder", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result)
        }
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        switch call.method {
        case "name":
            result(withFolder { $0.lastPathComponent })
        case "pick":
            pick(result)
        case "clear":
            UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
            result(nil)
        case "write":
            guard let name = args?["name"] as? String,
                  let bytes = args?["bytes"] as? FlutterStandardTypedData
            else {
                result(false)
                return
            }
            DispatchQueue.global(qos: .utility).async {
                let written = self.withFolder { folder in
                    Self.write(bytes.data, to: folder.appendingPathComponent(name))
                } ?? false
                DispatchQueue.main.async { result(written) }
            }
        case "prune":
            guard let prefix = args?["prefix"] as? String,
                  let keep = args?["keep"] as? Int
            else {
                result(nil)
                return
            }
            DispatchQueue.global(qos: .utility).async {
                _ = self.withFolder { folder in Self.prune(folder, prefix: prefix, keep: keep) }
                DispatchQueue.main.async { result(nil) }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Runs `body` with access to the saved folder; nil when there is none
    /// or it can't be reached any more
    private func withFolder<T>(_ body: (URL) -> T) -> T? {
        guard let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        if stale, let fresh = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(fresh, forKey: Self.bookmarkKey)
        }
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder),
              isFolder.boolValue
        else { return nil }
        return body(url)
    }

    /// Coordinated, so iCloud Drive syncs it properly
    private static func write(_ data: Data, to url: URL) -> Bool {
        var written = false
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(
            writingItemAt: url,
            options: .forReplacing,
            error: &coordinationError
        ) { target in
            written = (try? data.write(to: target, options: .atomic)) != nil
        }
        return written && coordinationError == nil
    }

    private static func prune(_ folder: URL, prefix: String, keep: Int) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for old in names.filter({ $0.hasPrefix(prefix) }).sorted(by: >).dropFirst(keep) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(old))
        }
    }

    private func pick(_ result: @escaping FlutterResult) {
        guard pending == nil, let top = Self.topController() else {
            result(nil)
            return
        }
        pending = result
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        top.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            finish(nil)
            return
        }
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        guard let bookmark = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            finish(nil)
            return
        }
        UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
        finish(url.lastPathComponent)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish(nil)
    }

    private func finish(_ value: Any?) {
        pending?(value)
        pending = nil
    }

    private static func topController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
