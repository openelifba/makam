import Foundation
import UserNotifications

// MARK: - NotificationService

/// Manages local notifications that fire 30 minutes before each prayer time.
enum NotificationService {

    private static let leadTime: TimeInterval = 30 * 60   // 30 minutes
    private static let idPrefix = "makam.azan."
    private static let enabledKey = "makam.notifications.enabled"

    // MARK: - Public API

    static func isEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
    }

    /// Requests notification authorization. Returns true if granted.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    /// Cancels all pending azan notifications then, if notifications are enabled
    /// and permission is granted, schedules reminders 30 min before each prayer.
    static func scheduleNotifications(for schedule: DailyPrayerSchedule, language: AppLanguage) {
        let center = UNUserNotificationCenter.current()

        // Always wipe stale requests first.
        cancelAll(center: center)

        guard isEnabled() else { return }

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            scheduleAll(schedule: schedule, language: language, center: center)
        }
    }

    /// Cancels all pending azan notifications.
    static func cancelAll() {
        cancelAll(center: UNUserNotificationCenter.current())
    }

    // MARK: - Private helpers

    private static func cancelAll(center: UNUserNotificationCenter) {
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(idPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private static func scheduleAll(
        schedule: DailyPrayerSchedule,
        language: AppLanguage,
        center: UNUserNotificationCenter
    ) {
        let now = Date()
        for prayer in schedule.prayers {
            let fireDate = prayer.time.addingTimeInterval(-leadTime)
            guard fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = title(for: prayer, language: language)
            content.body  = body(for: prayer, language: language)
            content.sound = .default

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request  = UNNotificationRequest(
                identifier: idPrefix + "\(prayer.id)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    // MARK: - Localised strings

    private static func title(for prayer: Prayer, language: AppLanguage) -> String {
        switch language {
        case .turkish:    return "\(prayer.name) Vakti Yaklaşıyor"
        case .english:    return "\(prayer.name) Prayer Coming Up"
        case .arabic:     return "\(prayer.arabicName) قريباً"
        case .german:     return "\(prayer.name)-Gebet nähert sich"
        case .french:     return "Prière \(prayer.name) imminente"
        case .russian:    return "Намаз \(prayer.name) приближается"
        case .indonesian: return "Waktu \(prayer.name) Segera Tiba"
        }
    }

    private static func body(for prayer: Prayer, language: AppLanguage) -> String {
        switch language {
        case .turkish:    return "\(prayer.name) vakti 30 dakika sonra başlıyor."
        case .english:    return "\(prayer.name) prayer starts in 30 minutes."
        case .arabic:     return "صلاة \(prayer.arabicName) تبدأ بعد 30 دقيقة."
        case .german:     return "\(prayer.name)-Gebet beginnt in 30 Minuten."
        case .french:     return "La prière \(prayer.name) commence dans 30 minutes."
        case .russian:    return "Намаз \(prayer.name) начнётся через 30 минут."
        case .indonesian: return "Waktu \(prayer.name) dimulai dalam 30 menit."
        }
    }
}
