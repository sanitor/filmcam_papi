import Flutter
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let engine = (UIApplication.shared.delegate as! AppDelegate).flutterEngine
        let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        let sceneWindow = UIWindow(windowScene: windowScene)
        sceneWindow.rootViewController = controller
        self.window = sceneWindow
        sceneWindow.makeKeyAndVisible()
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var metadataReader: CameraMetadataReader?
    private var depthHelper: ArDepthHelper?
    lazy var flutterEngine = FlutterEngine(name: "main_engine")

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        flutterEngine.run()
        GeneratedPluginRegistrant.register(with: flutterEngine)

        let messenger = flutterEngine.binaryMessenger
        let metadataChannel = FlutterMethodChannel(
            name: "com.filmcam/camera_metadata",
            binaryMessenger: messenger)
        metadataChannel.setMethodCallHandler { [weak self] call, result in
            self?.handleMetadataCall(call, result: result)
        }

        let depthChannel = FlutterMethodChannel(
            name: "com.filmcam/arcore_depth",
            binaryMessenger: messenger)
        depthChannel.setMethodCallHandler { [weak self] call, result in
            self?.handleDepthCall(call, result: result)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    private func handleMetadataCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            let cameraId = (call.arguments as? [String: Any])?["cameraId"] as? String ?? "0"
            let reader = CameraMetadataReader()
            let ok = reader.start(cameraId: cameraId)
            if ok { metadataReader = reader }
            result(ok)

        case "getLatest":
            result(metadataReader?.getLatest() ?? [
                "aperture": -1.0, "exposureTime": -1, "iso": -1,
                "focusDistance": -1.0, "isRunning": false, "sessionType": "none",
            ])

        case "getStaticAperture":
            let cameraId = (call.arguments as? [String: Any])?["cameraId"] as? String ?? "0"
            let reader = CameraMetadataReader()
            result(reader.getStaticAperture(cameraId: cameraId))

        case "measureDistance":
            let cameraId = (call.arguments as? [String: Any])?["cameraId"] as? String ?? "0"
            let reader = CameraMetadataReader()
            result(reader.measureDistance(cameraId: cameraId))

        case "dispose":
            metadataReader?.cleanup()
            metadataReader = nil
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleDepthCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            let helper = ArDepthHelper()
            result(helper.isSupported())

        case "measure":
            let helper = ArDepthHelper()
            result(helper.measureDepth())

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
