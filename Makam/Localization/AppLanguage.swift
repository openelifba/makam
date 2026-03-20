import Foundation
import SwiftUI

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case turkish    = "tr"
    case english    = "en"
    case arabic     = "ar"
    case german     = "de"
    case french     = "fr"
    case russian    = "ru"
    case indonesian = "id"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .turkish:    return "Türkçe"
        case .english:    return "English"
        case .arabic:     return "العربية"
        case .german:     return "Deutsch"
        case .french:     return "Français"
        case .russian:    return "Русский"
        case .indonesian: return "Bahasa Indonesia"
        }
    }

    var flag: String {
        switch self {
        case .turkish:    return "🇹🇷"
        case .english:    return "🇬🇧"
        case .arabic:     return "🇸🇦"
        case .german:     return "🇩🇪"
        case .french:     return "🇫🇷"
        case .russian:    return "🇷🇺"
        case .indonesian: return "🇮🇩"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
}

// MARK: - Localized Keys

enum LK: String {
    // Tabs
    case tabHabits, tabPrayerTimes, tabQibla, tabSettings
    // Prayer names
    case prayerImsak, prayerGunes, prayerOgle, prayerIkindi, prayerAksam, prayerYatsi
    // ContentView
    case contentToday, contentRetry, contentUntil
    // Settings
    case settingsLanguage, settingsLanguagePicker
    case settingsSelectCountry, settingsSearchCountry, settingsCountryError
    case settingsSelectCity, settingsSearchCity, settingsCityError
    case settingsSelectDistrict, settingsSearchDistrict, settingsDistrictError
    case settingsSave, settingsLocation
    // Habits
    case habitNoTasks, habitNewTask, habitEditTask
    case habitCancel, habitSave
    case habitTitleField, habitDateField, habitPeriodField, habitDurationField
    case habitRepeatField, habitNotesField
    case habitTitlePlaceholder, habitNotesPlaceholder
    case habitCopy, habitReschedule, habitTomorrow, habitEdit, habitDelete
    case habitDeleteTaskTitle, habitDeleteConfirm
    case habitDeleteRecurringTitle, habitDeleteOnlyThis, habitDeleteAllSeries, habitDeleteRecurringMessage
    case habitRescheduleTitle, habitNewDate, habitPlanButton
    // Repeat frequencies
    case repeatNone, repeatDaily, repeatWeekly, repeatMonthly, repeatYearly, repeatCustom
    // Duration
    case durationMinutes, duration1h, duration1h30m, duration2h, durationHours
}

// MARK: - Language Manager

@MainActor
final class LanguageManager: ObservableObject {
    static let userDefaultsKey = "makam.appLanguage"

    @Published private(set) var current: AppLanguage

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.userDefaultsKey),
           let lang = AppLanguage(rawValue: saved) {
            current = lang
        } else {
            let code = String((Locale.preferredLanguages.first ?? "en").prefix(2))
            current = AppLanguage(rawValue: code) ?? .english
        }
    }

    func setLanguage(_ language: AppLanguage) {
        current = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.userDefaultsKey)
    }

    func str(_ key: LK) -> String {
        translations[current]?[key] ?? translations[.english]?[key] ?? key.rawValue
    }

    func prayerName(forId id: Int) -> String {
        let keys: [LK] = [.prayerImsak, .prayerGunes, .prayerOgle, .prayerIkindi, .prayerAksam, .prayerYatsi]
        guard id >= 0 && id < keys.count else { return "" }
        return str(keys[id])
    }

    func untilText(prayerName name: String) -> String {
        str(.contentUntil).replacingOccurrences(of: "%@", with: name)
    }

    func repeatLabel(_ freq: RepeatFrequency) -> String {
        switch freq {
        case .none:    return str(.repeatNone)
        case .daily:   return str(.repeatDaily)
        case .weekly:  return str(.repeatWeekly)
        case .monthly: return str(.repeatMonthly)
        case .yearly:  return str(.repeatYearly)
        case .custom:  return str(.repeatCustom)
        }
    }

    func timePeriodName(_ period: TimePeriod) -> String {
        switch period {
        case .imsak:  return str(.prayerImsak)
        case .gunes:  return str(.prayerGunes)
        case .ogle:   return str(.prayerOgle)
        case .ikindi: return str(.prayerIkindi)
        case .aksam:  return str(.prayerAksam)
        case .yatsi:  return str(.prayerYatsi)
        }
    }

    func durationLabel(_ minutes: Int) -> String {
        switch minutes {
        case ..<60:
            return str(.durationMinutes).replacingOccurrences(of: "%d", with: "\(minutes)")
        case 60:   return str(.duration1h)
        case 90:   return str(.duration1h30m)
        case 120:  return str(.duration2h)
        default:
            return str(.durationHours).replacingOccurrences(of: "%d", with: "\(minutes / 60)")
        }
    }
}

// MARK: - Translations

private typealias T = [LK: String]

private let translations: [AppLanguage: T] = [

    // MARK: Turkish
    .turkish: [
        .tabHabits: "Alışkanlık",
        .tabPrayerTimes: "Namaz Vakitleri",
        .tabQibla: "Kıble",
        .tabSettings: "Ayarlar",

        .prayerImsak: "İmsak",
        .prayerGunes: "Güneş",
        .prayerOgle: "Öğle",
        .prayerIkindi: "İkindi",
        .prayerAksam: "Akşam",
        .prayerYatsi: "Yatsı",

        .contentToday: "BUGÜN",
        .contentRetry: "Tekrar Dene",
        .contentUntil: "%@'ya kadar",

        .settingsLanguage: "Dil",
        .settingsLanguagePicker: "Uygulama Dili",
        .settingsLocation: "Konum",
        .settingsSelectCountry: "Ülke Seç",
        .settingsSearchCountry: "Ülke ara",
        .settingsCountryError: "Ülke listesi yüklenemedi.",
        .settingsSelectCity: "Şehir Seç",
        .settingsSearchCity: "Şehir ara",
        .settingsCityError: "Şehir listesi yüklenemedi.",
        .settingsSelectDistrict: "İlçe Seç",
        .settingsSearchDistrict: "İlçe ara",
        .settingsDistrictError: "İlçe listesi yüklenemedi.",
        .settingsSave: "Kaydet",

        .habitNoTasks: "Bu vakitte görev yok",
        .habitNewTask: "Yeni Görev",
        .habitEditTask: "Görevi Düzenle",
        .habitCancel: "İptal",
        .habitSave: "Kaydet",
        .habitTitleField: "Görev Başlığı",
        .habitDateField: "Tarih",
        .habitPeriodField: "Vakit",
        .habitDurationField: "Süre",
        .habitRepeatField: "Tekrar",
        .habitNotesField: "Notlar (isteğe bağlı)",
        .habitTitlePlaceholder: "Örn: Kuran oku, Zikir çek…",
        .habitNotesPlaceholder: "Ek notlar veya hatırlatıcı…",
        .habitCopy: "Kopyala",
        .habitReschedule: "Yeniden Planla",
        .habitTomorrow: "Yarına Planla",
        .habitEdit: "Düzenle",
        .habitDelete: "Sil",
        .habitDeleteTaskTitle: "Görevi Sil",
        .habitDeleteConfirm: "\"%@\" silinecek. Emin misiniz?",
        .habitDeleteRecurringTitle: "Tekrarlayan Görevi Sil",
        .habitDeleteOnlyThis: "Yalnızca Bunu Sil",
        .habitDeleteAllSeries: "Tüm Tekrarları Sil",
        .habitDeleteRecurringMessage: "Bu görevi mi, yoksa tüm tekrarlayan örnekleri mi silmek istiyorsunuz?",
        .habitRescheduleTitle: "Yeniden Planla",
        .habitNewDate: "Yeni Tarih",
        .habitPlanButton: "Planla",

        .repeatNone: "Tekrar yok",
        .repeatDaily: "Günlük",
        .repeatWeekly: "Haftalık",
        .repeatMonthly: "Aylık",
        .repeatYearly: "Yıllık",
        .repeatCustom: "Özel",

        .durationMinutes: "%d dk",
        .duration1h: "1s",
        .duration1h30m: "1s 30dk",
        .duration2h: "2s",
        .durationHours: "%ds",
    ],

    // MARK: English
    .english: [
        .tabHabits: "Habits",
        .tabPrayerTimes: "Prayer Times",
        .tabQibla: "Qibla",
        .tabSettings: "Settings",

        .prayerImsak: "Fajr",
        .prayerGunes: "Sunrise",
        .prayerOgle: "Dhuhr",
        .prayerIkindi: "Asr",
        .prayerAksam: "Maghrib",
        .prayerYatsi: "Isha",

        .contentToday: "TODAY",
        .contentRetry: "Try Again",
        .contentUntil: "until %@",

        .settingsLanguage: "Language",
        .settingsLanguagePicker: "App Language",
        .settingsLocation: "Location",
        .settingsSelectCountry: "Select Country",
        .settingsSearchCountry: "Search country",
        .settingsCountryError: "Could not load country list.",
        .settingsSelectCity: "Select City",
        .settingsSearchCity: "Search city",
        .settingsCityError: "Could not load city list.",
        .settingsSelectDistrict: "Select District",
        .settingsSearchDistrict: "Search district",
        .settingsDistrictError: "Could not load district list.",
        .settingsSave: "Save",

        .habitNoTasks: "No tasks for this period",
        .habitNewTask: "New Task",
        .habitEditTask: "Edit Task",
        .habitCancel: "Cancel",
        .habitSave: "Save",
        .habitTitleField: "Task Title",
        .habitDateField: "Date",
        .habitPeriodField: "Period",
        .habitDurationField: "Duration",
        .habitRepeatField: "Repeat",
        .habitNotesField: "Notes (optional)",
        .habitTitlePlaceholder: "E.g.: Read Quran, Recite dhikr…",
        .habitNotesPlaceholder: "Additional notes or reminders…",
        .habitCopy: "Copy",
        .habitReschedule: "Reschedule",
        .habitTomorrow: "Plan for Tomorrow",
        .habitEdit: "Edit",
        .habitDelete: "Delete",
        .habitDeleteTaskTitle: "Delete Task",
        .habitDeleteConfirm: "\"%@\" will be deleted. Are you sure?",
        .habitDeleteRecurringTitle: "Delete Recurring Task",
        .habitDeleteOnlyThis: "Delete Only This",
        .habitDeleteAllSeries: "Delete All Repeats",
        .habitDeleteRecurringMessage: "Delete this task or all recurring instances?",
        .habitRescheduleTitle: "Reschedule",
        .habitNewDate: "New Date",
        .habitPlanButton: "Schedule",

        .repeatNone: "No repeat",
        .repeatDaily: "Daily",
        .repeatWeekly: "Weekly",
        .repeatMonthly: "Monthly",
        .repeatYearly: "Yearly",
        .repeatCustom: "Custom",

        .durationMinutes: "%d min",
        .duration1h: "1h",
        .duration1h30m: "1h 30m",
        .duration2h: "2h",
        .durationHours: "%dh",
    ],

    // MARK: Arabic
    .arabic: [
        .tabHabits: "عادات",
        .tabPrayerTimes: "أوقات الصلاة",
        .tabQibla: "القبلة",
        .tabSettings: "الإعدادات",

        .prayerImsak: "الفجر",
        .prayerGunes: "الشروق",
        .prayerOgle: "الظهر",
        .prayerIkindi: "العصر",
        .prayerAksam: "المغرب",
        .prayerYatsi: "العشاء",

        .contentToday: "اليوم",
        .contentRetry: "إعادة المحاولة",
        .contentUntil: "حتى %@",

        .settingsLanguage: "اللغة",
        .settingsLanguagePicker: "لغة التطبيق",
        .settingsLocation: "الموقع",
        .settingsSelectCountry: "اختر الدولة",
        .settingsSearchCountry: "بحث عن دولة",
        .settingsCountryError: "تعذّر تحميل قائمة الدول.",
        .settingsSelectCity: "اختر المدينة",
        .settingsSearchCity: "بحث عن مدينة",
        .settingsCityError: "تعذّر تحميل قائمة المدن.",
        .settingsSelectDistrict: "اختر المنطقة",
        .settingsSearchDistrict: "بحث عن منطقة",
        .settingsDistrictError: "تعذّر تحميل قائمة المناطق.",
        .settingsSave: "حفظ",

        .habitNoTasks: "لا توجد مهام في هذا الوقت",
        .habitNewTask: "مهمة جديدة",
        .habitEditTask: "تعديل المهمة",
        .habitCancel: "إلغاء",
        .habitSave: "حفظ",
        .habitTitleField: "عنوان المهمة",
        .habitDateField: "التاريخ",
        .habitPeriodField: "الوقت",
        .habitDurationField: "المدة",
        .habitRepeatField: "التكرار",
        .habitNotesField: "ملاحظات (اختياري)",
        .habitTitlePlaceholder: "مثال: قراءة القرآن، الذكر…",
        .habitNotesPlaceholder: "ملاحظات إضافية أو تذكيرات…",
        .habitCopy: "نسخ",
        .habitReschedule: "إعادة الجدولة",
        .habitTomorrow: "جدولة لغد",
        .habitEdit: "تعديل",
        .habitDelete: "حذف",
        .habitDeleteTaskTitle: "حذف المهمة",
        .habitDeleteConfirm: "سيتم حذف \"%@\". هل أنت متأكد؟",
        .habitDeleteRecurringTitle: "حذف المهمة المتكررة",
        .habitDeleteOnlyThis: "حذف هذه فقط",
        .habitDeleteAllSeries: "حذف جميع التكرارات",
        .habitDeleteRecurringMessage: "هل تريد حذف هذه المهمة أم جميع التكرارات؟",
        .habitRescheduleTitle: "إعادة الجدولة",
        .habitNewDate: "تاريخ جديد",
        .habitPlanButton: "جدولة",

        .repeatNone: "بدون تكرار",
        .repeatDaily: "يومي",
        .repeatWeekly: "أسبوعي",
        .repeatMonthly: "شهري",
        .repeatYearly: "سنوي",
        .repeatCustom: "مخصص",

        .durationMinutes: "%d دقيقة",
        .duration1h: "١ ساعة",
        .duration1h30m: "١س ٣٠د",
        .duration2h: "٢ ساعة",
        .durationHours: "%d ساعة",
    ],

    // MARK: German
    .german: [
        .tabHabits: "Gewohnheiten",
        .tabPrayerTimes: "Gebetszeiten",
        .tabQibla: "Qibla",
        .tabSettings: "Einstellungen",

        .prayerImsak: "Fajr",
        .prayerGunes: "Sonnenaufgang",
        .prayerOgle: "Dhuhr",
        .prayerIkindi: "Asr",
        .prayerAksam: "Maghrib",
        .prayerYatsi: "Isha",

        .contentToday: "HEUTE",
        .contentRetry: "Erneut versuchen",
        .contentUntil: "bis %@",

        .settingsLanguage: "Sprache",
        .settingsLanguagePicker: "App-Sprache",
        .settingsLocation: "Standort",
        .settingsSelectCountry: "Land auswählen",
        .settingsSearchCountry: "Land suchen",
        .settingsCountryError: "Länderliste konnte nicht geladen werden.",
        .settingsSelectCity: "Stadt auswählen",
        .settingsSearchCity: "Stadt suchen",
        .settingsCityError: "Stadtliste konnte nicht geladen werden.",
        .settingsSelectDistrict: "Bezirk auswählen",
        .settingsSearchDistrict: "Bezirk suchen",
        .settingsDistrictError: "Bezirksliste konnte nicht geladen werden.",
        .settingsSave: "Speichern",

        .habitNoTasks: "Keine Aufgaben für diesen Zeitraum",
        .habitNewTask: "Neue Aufgabe",
        .habitEditTask: "Aufgabe bearbeiten",
        .habitCancel: "Abbrechen",
        .habitSave: "Speichern",
        .habitTitleField: "Aufgabentitel",
        .habitDateField: "Datum",
        .habitPeriodField: "Zeitraum",
        .habitDurationField: "Dauer",
        .habitRepeatField: "Wiederholung",
        .habitNotesField: "Notizen (optional)",
        .habitTitlePlaceholder: "Z.B.: Quran lesen, Dhikr…",
        .habitNotesPlaceholder: "Zusätzliche Notizen oder Erinnerungen…",
        .habitCopy: "Kopieren",
        .habitReschedule: "Neu planen",
        .habitTomorrow: "Für morgen planen",
        .habitEdit: "Bearbeiten",
        .habitDelete: "Löschen",
        .habitDeleteTaskTitle: "Aufgabe löschen",
        .habitDeleteConfirm: "\"%@\" wird gelöscht. Sind Sie sicher?",
        .habitDeleteRecurringTitle: "Wiederkehrende Aufgabe löschen",
        .habitDeleteOnlyThis: "Nur diese löschen",
        .habitDeleteAllSeries: "Alle Wiederholungen löschen",
        .habitDeleteRecurringMessage: "Diese Aufgabe oder alle wiederkehrenden Instanzen löschen?",
        .habitRescheduleTitle: "Neu planen",
        .habitNewDate: "Neues Datum",
        .habitPlanButton: "Planen",

        .repeatNone: "Keine Wiederholung",
        .repeatDaily: "Täglich",
        .repeatWeekly: "Wöchentlich",
        .repeatMonthly: "Monatlich",
        .repeatYearly: "Jährlich",
        .repeatCustom: "Benutzerdefiniert",

        .durationMinutes: "%d Min",
        .duration1h: "1h",
        .duration1h30m: "1h 30m",
        .duration2h: "2h",
        .durationHours: "%dh",
    ],

    // MARK: French
    .french: [
        .tabHabits: "Habitudes",
        .tabPrayerTimes: "Heures de prière",
        .tabQibla: "Qibla",
        .tabSettings: "Paramètres",

        .prayerImsak: "Fajr",
        .prayerGunes: "Lever du soleil",
        .prayerOgle: "Dhuhr",
        .prayerIkindi: "Asr",
        .prayerAksam: "Maghrib",
        .prayerYatsi: "Isha",

        .contentToday: "AUJOURD'HUI",
        .contentRetry: "Réessayer",
        .contentUntil: "jusqu'à %@",

        .settingsLanguage: "Langue",
        .settingsLanguagePicker: "Langue de l'app",
        .settingsLocation: "Localisation",
        .settingsSelectCountry: "Choisir un pays",
        .settingsSearchCountry: "Rechercher un pays",
        .settingsCountryError: "Impossible de charger la liste des pays.",
        .settingsSelectCity: "Choisir une ville",
        .settingsSearchCity: "Rechercher une ville",
        .settingsCityError: "Impossible de charger la liste des villes.",
        .settingsSelectDistrict: "Choisir un district",
        .settingsSearchDistrict: "Rechercher un district",
        .settingsDistrictError: "Impossible de charger la liste des districts.",
        .settingsSave: "Enregistrer",

        .habitNoTasks: "Aucune tâche pour cette période",
        .habitNewTask: "Nouvelle tâche",
        .habitEditTask: "Modifier la tâche",
        .habitCancel: "Annuler",
        .habitSave: "Enregistrer",
        .habitTitleField: "Titre de la tâche",
        .habitDateField: "Date",
        .habitPeriodField: "Période",
        .habitDurationField: "Durée",
        .habitRepeatField: "Répétition",
        .habitNotesField: "Notes (optionnel)",
        .habitTitlePlaceholder: "Ex : Lire le Coran, Dhikr…",
        .habitNotesPlaceholder: "Notes supplémentaires ou rappels…",
        .habitCopy: "Copier",
        .habitReschedule: "Reprogrammer",
        .habitTomorrow: "Planifier pour demain",
        .habitEdit: "Modifier",
        .habitDelete: "Supprimer",
        .habitDeleteTaskTitle: "Supprimer la tâche",
        .habitDeleteConfirm: "\"%@\" sera supprimé. Êtes-vous sûr ?",
        .habitDeleteRecurringTitle: "Supprimer la tâche récurrente",
        .habitDeleteOnlyThis: "Supprimer seulement celle-ci",
        .habitDeleteAllSeries: "Supprimer toutes les répétitions",
        .habitDeleteRecurringMessage: "Supprimer cette tâche ou toutes les occurrences récurrentes ?",
        .habitRescheduleTitle: "Reprogrammer",
        .habitNewDate: "Nouvelle date",
        .habitPlanButton: "Planifier",

        .repeatNone: "Pas de répétition",
        .repeatDaily: "Quotidien",
        .repeatWeekly: "Hebdomadaire",
        .repeatMonthly: "Mensuel",
        .repeatYearly: "Annuel",
        .repeatCustom: "Personnalisé",

        .durationMinutes: "%d min",
        .duration1h: "1h",
        .duration1h30m: "1h 30m",
        .duration2h: "2h",
        .durationHours: "%dh",
    ],

    // MARK: Russian
    .russian: [
        .tabHabits: "Привычки",
        .tabPrayerTimes: "Время намаза",
        .tabQibla: "Кибла",
        .tabSettings: "Настройки",

        .prayerImsak: "Фаджр",
        .prayerGunes: "Восход",
        .prayerOgle: "Зухр",
        .prayerIkindi: "Аср",
        .prayerAksam: "Магриб",
        .prayerYatsi: "Иша",

        .contentToday: "СЕГОДНЯ",
        .contentRetry: "Повторить",
        .contentUntil: "до %@",

        .settingsLanguage: "Язык",
        .settingsLanguagePicker: "Язык приложения",
        .settingsLocation: "Местоположение",
        .settingsSelectCountry: "Выбрать страну",
        .settingsSearchCountry: "Поиск страны",
        .settingsCountryError: "Не удалось загрузить список стран.",
        .settingsSelectCity: "Выбрать город",
        .settingsSearchCity: "Поиск города",
        .settingsCityError: "Не удалось загрузить список городов.",
        .settingsSelectDistrict: "Выбрать район",
        .settingsSearchDistrict: "Поиск района",
        .settingsDistrictError: "Не удалось загрузить список районов.",
        .settingsSave: "Сохранить",

        .habitNoTasks: "Нет задач для этого периода",
        .habitNewTask: "Новая задача",
        .habitEditTask: "Изменить задачу",
        .habitCancel: "Отмена",
        .habitSave: "Сохранить",
        .habitTitleField: "Название задачи",
        .habitDateField: "Дата",
        .habitPeriodField: "Период",
        .habitDurationField: "Длительность",
        .habitRepeatField: "Повтор",
        .habitNotesField: "Заметки (необязательно)",
        .habitTitlePlaceholder: "Напр.: Читать Коран, Зикр…",
        .habitNotesPlaceholder: "Дополнительные заметки или напоминания…",
        .habitCopy: "Копировать",
        .habitReschedule: "Перенести",
        .habitTomorrow: "Запланировать на завтра",
        .habitEdit: "Изменить",
        .habitDelete: "Удалить",
        .habitDeleteTaskTitle: "Удалить задачу",
        .habitDeleteConfirm: "\"%@\" будет удалена. Вы уверены?",
        .habitDeleteRecurringTitle: "Удалить повторяющуюся задачу",
        .habitDeleteOnlyThis: "Удалить только эту",
        .habitDeleteAllSeries: "Удалить все повторения",
        .habitDeleteRecurringMessage: "Удалить только эту задачу или все повторяющиеся экземпляры?",
        .habitRescheduleTitle: "Перенести",
        .habitNewDate: "Новая дата",
        .habitPlanButton: "Запланировать",

        .repeatNone: "Без повтора",
        .repeatDaily: "Ежедневно",
        .repeatWeekly: "Еженедельно",
        .repeatMonthly: "Ежемесячно",
        .repeatYearly: "Ежегодно",
        .repeatCustom: "Настраиваемый",

        .durationMinutes: "%d мин",
        .duration1h: "1ч",
        .duration1h30m: "1ч 30м",
        .duration2h: "2ч",
        .durationHours: "%dч",
    ],

    // MARK: Indonesian
    .indonesian: [
        .tabHabits: "Kebiasaan",
        .tabPrayerTimes: "Waktu Shalat",
        .tabQibla: "Kiblat",
        .tabSettings: "Pengaturan",

        .prayerImsak: "Subuh",
        .prayerGunes: "Terbit",
        .prayerOgle: "Zuhur",
        .prayerIkindi: "Ashar",
        .prayerAksam: "Maghrib",
        .prayerYatsi: "Isya",

        .contentToday: "HARI INI",
        .contentRetry: "Coba Lagi",
        .contentUntil: "hingga %@",

        .settingsLanguage: "Bahasa",
        .settingsLanguagePicker: "Bahasa Aplikasi",
        .settingsLocation: "Lokasi",
        .settingsSelectCountry: "Pilih Negara",
        .settingsSearchCountry: "Cari negara",
        .settingsCountryError: "Daftar negara tidak dapat dimuat.",
        .settingsSelectCity: "Pilih Kota",
        .settingsSearchCity: "Cari kota",
        .settingsCityError: "Daftar kota tidak dapat dimuat.",
        .settingsSelectDistrict: "Pilih Kecamatan",
        .settingsSearchDistrict: "Cari kecamatan",
        .settingsDistrictError: "Daftar kecamatan tidak dapat dimuat.",
        .settingsSave: "Simpan",

        .habitNoTasks: "Tidak ada tugas untuk periode ini",
        .habitNewTask: "Tugas Baru",
        .habitEditTask: "Edit Tugas",
        .habitCancel: "Batal",
        .habitSave: "Simpan",
        .habitTitleField: "Judul Tugas",
        .habitDateField: "Tanggal",
        .habitPeriodField: "Waktu",
        .habitDurationField: "Durasi",
        .habitRepeatField: "Pengulangan",
        .habitNotesField: "Catatan (opsional)",
        .habitTitlePlaceholder: "Misal: Baca Quran, Dzikir…",
        .habitNotesPlaceholder: "Catatan tambahan atau pengingat…",
        .habitCopy: "Salin",
        .habitReschedule: "Jadwalkan Ulang",
        .habitTomorrow: "Rencanakan untuk Besok",
        .habitEdit: "Edit",
        .habitDelete: "Hapus",
        .habitDeleteTaskTitle: "Hapus Tugas",
        .habitDeleteConfirm: "\"%@\" akan dihapus. Apakah Anda yakin?",
        .habitDeleteRecurringTitle: "Hapus Tugas Berulang",
        .habitDeleteOnlyThis: "Hapus Hanya Ini",
        .habitDeleteAllSeries: "Hapus Semua Pengulangan",
        .habitDeleteRecurringMessage: "Hapus tugas ini atau semua instansi berulang?",
        .habitRescheduleTitle: "Jadwalkan Ulang",
        .habitNewDate: "Tanggal Baru",
        .habitPlanButton: "Jadwalkan",

        .repeatNone: "Tidak berulang",
        .repeatDaily: "Harian",
        .repeatWeekly: "Mingguan",
        .repeatMonthly: "Bulanan",
        .repeatYearly: "Tahunan",
        .repeatCustom: "Kustom",

        .durationMinutes: "%d mnt",
        .duration1h: "1j",
        .duration1h30m: "1j 30m",
        .duration2h: "2j",
        .durationHours: "%dj",
    ],
]
