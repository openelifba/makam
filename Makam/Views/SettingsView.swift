import SwiftUI
import UserNotifications

// MARK: - Design Tokens (mirrors ContentView's Makam namespace)

private enum MakamStyle {
    static let sand     = Color(red: 0.910, green: 0.835, blue: 0.690)
    static let sandDim  = Color(red: 0.910, green: 0.835, blue: 0.690).opacity(0.45)
    static let gold     = Color(red: 0.780, green: 0.620, blue: 0.340)
    static let bg       = Color(red: 0.08,  green: 0.08,  blue: 0.10)
    static let rowBg    = Color(red: 0.12,  green: 0.12,  blue: 0.15)
    static let white    = Color.white
}

// MARK: - Settings Root

struct SettingsView: View {
    @EnvironmentObject var prayerViewModel: PrayerViewModel
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var vm: SettingsViewModel
    @State private var navReset = UUID()
    @Binding var selectedTab: AppTab

    var body: some View {
        NavigationView {
            SettingsRootView(
                vm: vm,
                onSave: {
                    vm.saveSettings()
                    Task { await prayerViewModel.fetchPrayers() }
                    navReset = UUID()
                    selectedTab = .prayerTimes
                }
            )
        }
        .navigationViewStyle(.stack)
        .id(navReset)
        .onAppear { Task { await vm.loadCountries() } }
    }
}

// MARK: - Settings Root View

private struct SettingsRootView: View {
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var prayerViewModel: PrayerViewModel
    @ObservedObject var vm: SettingsViewModel
    let onSave: () -> Void

    @State private var notificationsEnabled: Bool = NotificationService.isEnabled()
    @State private var showPermissionAlert = false

    var body: some View {
        ZStack {
            MakamStyle.bg.ignoresSafeArea()

            listContent
        }
        .navigationBarTitle(lang.str(.tabSettings), displayMode: .inline)
        .background(MakamStyle.bg.ignoresSafeArea())
        .alert("", isPresented: $showPermissionAlert) {
            Button("OK", role: .cancel) { }
            Button(lang.str(.tabSettings)) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(lang.str(.settingsNotificationPermissionMessage))
        }
    }

    private var listContent: some View {
        List {
            // MARK: Language Section
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(MakamStyle.gold)
                        .frame(width: 22)
                    Picker("", selection: Binding(
                        get: { lang.current },
                        set: { newValue in
                            lang.setLanguage(newValue)
                            Analytics.logEvent(
                                "language_changed",
                                metadata: ["language": String(describing: newValue)]
                            )
                        }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName)
                                .tag(language)
                        }
                    }
                    .labelsHidden()
                    .accentColor(MakamStyle.sand)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                }
                .listRowBackground(MakamStyle.rowBg)
            } header: {
                Text(lang.str(.settingsLanguage).uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(MakamStyle.sandDim)
            }

            // MARK: Location Section
            Section {
                NavigationLink(
                    destination: CountryPickerView(vm: vm, onSave: onSave)
                        .onAppear { Task { await vm.loadCountries() } }
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(MakamStyle.gold)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lang.str(.settingsLocation))
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(MakamStyle.sand)
                            if let district = UserDefaults.standard.savedDistrictName, !district.isEmpty {
                                Text(district)
                                    .font(.system(size: 12, weight: .light, design: .rounded))
                                    .foregroundColor(MakamStyle.sandDim)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(MakamStyle.rowBg)
            } header: {
                Text(lang.str(.settingsLocation).uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(MakamStyle.sandDim)
            }

            // MARK: Notifications Section
            Section {
                Toggle(isOn: $notificationsEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 14))
                            .foregroundColor(MakamStyle.gold)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lang.str(.settingsAzanReminder))
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(MakamStyle.sand)
                            Text(lang.str(.settingsAzanReminderDetail))
                                .font(.system(size: 12, weight: .light, design: .rounded))
                                .foregroundColor(MakamStyle.sandDim)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .accentColor(MakamStyle.gold)
                .listRowBackground(MakamStyle.rowBg)
                .compatOnChange(of: notificationsEnabled) { newValue in
                    if newValue {
                        Task {
                            let granted = await NotificationService.requestAuthorization()
                            if granted {
                                NotificationService.setEnabled(true)
                                if let schedule = prayerViewModel.schedule {
                                    NotificationService.scheduleNotifications(
                                        for: schedule,
                                        language: lang.current
                                    )
                                }
                            } else {
                                notificationsEnabled = false
                                showPermissionAlert = true
                            }
                            Analytics.logEvent(
                                "notifications_toggled",
                                metadata: [
                                    "enabled": granted ? "true" : "false",
                                    "permissionGranted": granted ? "true" : "false",
                                ]
                            )
                        }
                    } else {
                        NotificationService.setEnabled(false)
                        NotificationService.cancelAll()
                        Analytics.logEvent(
                            "notifications_toggled",
                            metadata: ["enabled": "false", "permissionGranted": "true"]
                        )
                    }
                }
            } header: {
                Text(lang.str(.settingsNotifications).uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(MakamStyle.sandDim)
            }
        }
        .listStyle(GroupedListStyle())
        .background(MakamStyle.bg)
        .accentColor(MakamStyle.gold)
        .onAppear {
            UITableView.appearance().backgroundColor = .clear
        }
    }
}

// MARK: - Country Picker

private struct CountryPickerView: View {
    @EnvironmentObject var lang: LanguageManager
    @ObservedObject var vm: SettingsViewModel
    let onSave: () -> Void

    @State private var searchText = ""

    private var filtered: [EzanVaktiUlke] {
        guard !searchText.isEmpty else { return vm.countries }
        return vm.countries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.nameEn.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            MakamStyle.bg.ignoresSafeArea()

            Group {
                if vm.isLoadingCountries {
                    ActivityIndicatorView(color: UIColor(MakamStyle.gold))
                } else if vm.countries.isEmpty {
                    EmptyStateView(message: lang.str(.settingsCountryError))
                } else {
                    countryList
                }
            }
        }
        .navigationBarTitle(lang.str(.settingsSelectCountry), displayMode: .inline)
        .background(MakamStyle.bg.ignoresSafeArea())
        .errorBanner(vm.errorMessage)
    }

    private var countryList: some View {
        Group {
            if #available(iOS 15, *) {
                List(filtered) { country in
                    countryRow(country)
                }
                .listStyle(GroupedListStyle())
                .background(MakamStyle.bg)
                .searchable(text: $searchText, prompt: lang.str(.settingsSearchCountry))
                .accentColor(MakamStyle.gold)
                .onAppear { UITableView.appearance().backgroundColor = .clear }
            } else {
                List(filtered) { country in
                    countryRow(country)
                }
                .listStyle(GroupedListStyle())
                .background(MakamStyle.bg)
                .accentColor(MakamStyle.gold)
                .onAppear { UITableView.appearance().backgroundColor = .clear }
            }
        }
    }

    private func countryRow(_ country: EzanVaktiUlke) -> some View {
        NavigationLink(
            destination: CityPickerView(
                vm: vm,
                country: country,
                onSave: onSave
            )
            .onAppear { Task { await vm.selectCountry(country) } }
        ) {
            LocationRow(
                name: country.name,
                subtitle: country.nameEn,
                isSelected: vm.selectedCountry?.id == country.id
            )
        }
        .listRowBackground(MakamStyle.rowBg)
    }
}

// MARK: - City Picker

private struct CityPickerView: View {
    @EnvironmentObject var lang: LanguageManager
    @ObservedObject var vm: SettingsViewModel
    let country: EzanVaktiUlke
    let onSave: () -> Void

    @State private var searchText = ""

    private var filtered: [EzanVaktiSehir] {
        guard !searchText.isEmpty else { return vm.cities }
        return vm.cities.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.nameEn.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            MakamStyle.bg.ignoresSafeArea()

            Group {
                if vm.isLoadingCities {
                    ActivityIndicatorView(color: UIColor(MakamStyle.gold))
                } else if vm.cities.isEmpty {
                    EmptyStateView(message: lang.str(.settingsCityError))
                } else {
                    cityList
                }
            }
        }
        .navigationBarTitle(lang.str(.settingsSelectCity), displayMode: .inline)
        .background(MakamStyle.bg.ignoresSafeArea())
        .errorBanner(vm.errorMessage)
    }

    private var cityList: some View {
        Group {
            if #available(iOS 15, *) {
                List(filtered) { city in
                    cityRow(city)
                }
                .listStyle(GroupedListStyle())
                .background(MakamStyle.bg)
                .searchable(text: $searchText, prompt: lang.str(.settingsSearchCity))
                .accentColor(MakamStyle.gold)
                .onAppear { UITableView.appearance().backgroundColor = .clear }
            } else {
                List(filtered) { city in
                    cityRow(city)
                }
                .listStyle(GroupedListStyle())
                .background(MakamStyle.bg)
                .accentColor(MakamStyle.gold)
                .onAppear { UITableView.appearance().backgroundColor = .clear }
            }
        }
    }

    private func cityRow(_ city: EzanVaktiSehir) -> some View {
        NavigationLink(
            destination: DistrictPickerView(
                vm: vm,
                city: city,
                onSave: onSave
            )
            .onAppear { Task { await vm.selectCity(city) } }
        ) {
            LocationRow(
                name: city.name,
                subtitle: city.nameEn,
                isSelected: vm.selectedCity?.id == city.id
            )
        }
        .listRowBackground(MakamStyle.rowBg)
    }
}

// MARK: - District Picker

private struct DistrictPickerView: View {
    @EnvironmentObject var lang: LanguageManager
    @ObservedObject var vm: SettingsViewModel
    let city: EzanVaktiSehir
    let onSave: () -> Void

    @State private var searchText = ""

    private var filtered: [EzanVaktiIlce] {
        guard !searchText.isEmpty else { return vm.districts }
        return vm.districts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.nameEn.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            MakamStyle.bg.ignoresSafeArea()

            Group {
                if vm.isLoadingDistricts {
                    ActivityIndicatorView(color: UIColor(MakamStyle.gold))
                } else if vm.districts.isEmpty {
                    EmptyStateView(message: lang.str(.settingsDistrictError))
                } else {
                    districtList
                }
            }
        }
        .navigationBarTitle(lang.str(.settingsSelectDistrict), displayMode: .inline)
        .background(MakamStyle.bg.ignoresSafeArea())
        .navigationBarItems(trailing:
            Button(lang.str(.settingsSave)) { onSave() }
                .disabled(vm.selectedDistrict == nil)
                .foregroundColor(vm.selectedDistrict != nil ? MakamStyle.gold : Color.gray)
        )
        .errorBanner(vm.errorMessage)
    }

    private var districtList: some View {
        Group {
            if #available(iOS 15, *) {
                List(filtered) { district in
                    districtRow(district)
                }
                .listStyle(GroupedListStyle())
                .background(MakamStyle.bg)
                .searchable(text: $searchText, prompt: lang.str(.settingsSearchDistrict))
                .accentColor(MakamStyle.gold)
                .onAppear { UITableView.appearance().backgroundColor = .clear }
            } else {
                List(filtered) { district in
                    districtRow(district)
                }
                .listStyle(GroupedListStyle())
                .background(MakamStyle.bg)
                .accentColor(MakamStyle.gold)
                .onAppear { UITableView.appearance().backgroundColor = .clear }
            }
        }
    }

    private func districtRow(_ district: EzanVaktiIlce) -> some View {
        Button {
            vm.selectDistrict(district)
            Analytics.logEvent(
                "location_changed",
                metadata: [
                    "countryName": vm.selectedCountry?.name ?? "",
                    "cityName": vm.selectedCity?.name ?? "",
                    "districtName": district.name,
                ]
            )
        } label: {
            LocationRow(
                name: district.name,
                subtitle: district.nameEn,
                isSelected: vm.selectedDistrict?.id == district.id
            )
        }
        .listRowBackground(MakamStyle.rowBg)
    }
}

// MARK: - Shared Sub-Views

private struct LocationRow: View {
    let name: String
    let subtitle: String?
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(MakamStyle.sand)

                if let sub = subtitle, !sub.isEmpty, sub != name {
                    Text(sub)
                        .font(.system(size: 12, weight: .light, design: .rounded))
                        .foregroundColor(MakamStyle.sandDim)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(MakamStyle.gold)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EmptyStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(MakamStyle.gold)
            Text(message)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(MakamStyle.sandDim)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Error Banner Modifier

private struct ErrorBannerModifier: ViewModifier {
    let message: String?

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let msg = message {
                Text(msg)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(MakamStyle.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.75))
                    .transition(.move(edge: .bottom))
            }
        }
    }
}

private extension View {
    func errorBanner(_ message: String?) -> some View {
        modifier(ErrorBannerModifier(message: message))
    }
}
