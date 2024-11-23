import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)

        // İlk olarak LoadingViewController'ı göster
        showLoadingScreen()

        return true
    }

    func showLoadingScreen() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let loadingVC = storyboard.instantiateViewController(withIdentifier: "LoadingViewController") as? LoadingViewController {
            window?.rootViewController = loadingVC
            window?.makeKeyAndVisible()
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Uygulama aktif olduğunda tekrar yükleme ekranını göster
        showLoadingScreen()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Uygulama sonlandırıldığında tekrar yükleme ekranını göster
        showLoadingScreen()
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Discarded session işlemleri
    }
}
