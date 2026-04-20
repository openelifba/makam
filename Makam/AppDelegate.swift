import UIKit
import SwiftUI
import Combine
import Statsig

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    let prayerViewModel = PrayerViewModel()
    let languageManager = LanguageManager()
    let habitViewModel = HabitViewModel()
    let qiblaViewModel = QiblaViewModel()
    let jellyfinService = JellyfinService()
    let settingsViewModel = SettingsViewModel()

    private var cancellables = Set<AnyCancellable>()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        setupStatsig()
        setupLanguageObserver()
        SettingsViewModel.setDefaultLocationIfNeeded()
        prayerViewModel.language = languageManager.current
        setupWindow()
        Task { @MainActor in await self.prayerViewModel.fetchPrayers() }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in
            self.prayerViewModel.language = self.languageManager.current
            await self.prayerViewModel.fetchPrayers()
        }
    }

    // MARK: - Private

    private func setupStatsig() {
        let userId: String
        if let cached = AuthManager.cachedDeviceId() {
            userId = cached
        } else {
            userId = UUID().uuidString
            UserDefaults.standard.set(userId, forKey: AuthManager.deviceIdKey)
        }
        Statsig.start(
            sdkKey: "client-Saz0qNAZ1EvptEcQrNHAgtJtRuF3yofu6wdwQM4rJaZ",
            user: StatsigUser(userID: userId),
            options: StatsigOptions()
        ) { _ in }
    }

    private func setupLanguageObserver() {
        languageManager.$current
            .dropFirst()
            .sink { [weak self] newLanguage in
                guard let self else { return }
                self.prayerViewModel.language = newLanguage
                if let schedule = self.prayerViewModel.schedule {
                    NotificationService.scheduleNotifications(for: schedule, language: newLanguage)
                }
            }
            .store(in: &cancellables)
    }

    private func setupWindow() {
        let rootView = MainTabView()
            .environmentObject(prayerViewModel)
            .environmentObject(languageManager)
            .environmentObject(habitViewModel)
            .environmentObject(qiblaViewModel)
            .environmentObject(jellyfinService)
            .environmentObject(settingsViewModel)

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIHostingController(rootView: rootView)
        window?.makeKeyAndVisible()
    }
}
