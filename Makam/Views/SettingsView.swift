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
    @StateObject private var vm = SettingsViewModel()
    @Binding var selectedTab: AppTab

    var body: some View {
        NavigationView {
            SettingsRootView(
                vm: vm,
                onSave: {
                    vm.saveSettings()
                    Task { await prayerViewModel.fetchPrayers() }
                    selectedTab = .prayerTimes
                }
            )
        }
        .navigationViewStyle(.stack)
        .task { await vm.loadCountries() }
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

            List {
                // MARK: Language Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 14))
                            .foregroundStyle(MakamStyle.gold)
                            .frame(width: 22)
                        Picker("", selection: Binding(
                            get: { lang.current },
                            set: { lang.setLanguage($0) }
                        )) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName)
                                    .tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(MakamStyle.sand)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                    }
                    .listRowBackground(MakamStyle.rowBg)
                } header: {
                    Text(lang.str(.settingsLanguage).uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(MakamStyle.sandDim)
                }

                // MARK: Location Section
                Section {
                    NavigationLink(
                        destination: CountryPickerView(vm: vm, onSave: onSave)
                            .task { await vm.loadCountries() }
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(MakamStyle.gold)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.str(.settingsLocation))
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundStyle(MakamStyle.sand)
                                if let district = UserDefaults.standard.savedDistrictName, !district.isEmpty {
                                    Text(district)
                                        .font(.system(size: 12, weight: .light, design: .rounded))
                                        .foregroundStyle(MakamStyle.sandDim)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(MakamStyle.rowBg)
                    .listRowSeparatorTint(MakamStyle.sand.opacity(0.1))
                } header: {
                    Text(lang.str(.settingsLocation).uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(MakamStyle.sandDim)
                }

                // MARK: Notifications Section
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(MakamStyle.gold)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.str(.settingsAzanReminder))
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundStyle(MakamStyle.sand)
                                Text(lang.str(.settingsAzanReminderDetail))
                                    .font(.system(size: 12, weight: .light, design: .rounded))
                                    .foregroundStyle(MakamStyle.sandDim)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .tint(MakamStyle.gold)
                    .listRowBackground(MakamStyle.rowBg)
                    .listRowSeparatorTint(MakamStyle.sand.opacity(0.1))
                    .onChange(of: notificationsEnabled) { newValue in
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
                                    // Permission denied — revert toggle
                                    notificationsEnabled = false
                                    showPermissionAlert = true
                                }
                            }
                        } else {
                            NotificationService.setEnabled(false)
                            NotificationService.cancelAll()
                        }
                    }
                } header: {
                    Text(lang.str(.settingsNotifications).uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(MakamStyle.sandDim)
                }
            }
            .listStyle(.insetGrouped)
            .hideScrollContentBackground()
            .tint(MakamStyle.gold)
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
        .navigationTitle(lang.str(.tabSettings))
        .navigationBarTitleDisplayMode(.inline)
        .applyToolbarStyling()
    }
}

// MARK: - Country Picker

private struct CountryPickerView: View {
    @EnvironmentObject var lang: LanguageManager
    @ObservedObject var vm: SettingsViewModel
    let onSave: () -> Void

    @State private var searchText = ""

    private var filtered: [ImsakiyemCountry] {
        guard !searchText.isEmpty else { return vm.countries }
        return vm.countries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.nameEn ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            MakamStyle.bg.ignoresSafeArea()

            Group {
                if vm.isLoadingCountries {
                    ProgressView()
                        .tint(MakamStyle.gold)
                } else if vm.countries.isEmpty {
                    EmptyStateView(message: lang.str(.settingsCountryError))
                } else {
                    List(filtered) { country in
                        NavigationLink(
                            destination: StatePickerView(
                                vm: vm,
                                country: country,
                                onSave: onSave
                            )
                            .task { await vm.selectCountry(country) }
                        ) {
                            LocationRow(
                                name: country.name,
                                subtitle: country.nameEn,
                                isSelected: vm.selectedCountry?.id == country.id
                            )
                        }
                        .listRowBackground(MakamStyle.rowBg)
                        .listRowSeparatorTint(MakamStyle.sand.opacity(0.1))
                    }
                    .listStyle(.insetGrouped)
                    .hideScrollContentBackground()
                    .searchable(text: $searchText, prompt: lang.str(.settingsSearchCountry))
                    .tint(MakamStyle.gold)
                }
            }
        }
        .navigationTitle(lang.str(.settingsSelectCountry))
        .navigationBarTitleDisplayMode(.inline)
        .applyToolbarStyling()
        .errorBanner(vm.errorMessage)
    }
}

// MARK: - State / City Picker

private struct StatePickerView: View {
    @EnvironmentObject var lang: LanguageManager
    @ObservedObject var vm: SettingsViewModel
    let country: ImsakiyemCountry
    let onSave: () -> Void

    @State private var searchText = ""

    private var filtered: [ImsakiyemState] {
        guard !searchText.isEmpty else { return vm.states }
        return vm.states.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.nameEn ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            MakamStyle.bg.ignoresSafeArea()

            Group {
                if vm.isLoadingStates {
                    ProgressView()
                        .tint(MakamStyle.gold)
                } else if vm.states.isEmpty {
                    EmptyStateView(message: lang.str(.settingsCityError))
                } else {
                    List(filtered) { state in
                        NavigationLink(
                            destination: DistrictPickerView(
                                vm: vm,
                                state: state,
                                onSave: onSave
                            )
                            .task { await vm.selectState(state) }
                        ) {
                            LocationRow(
                                name: state.name,
                                subtitle: state.nameEn,
                                isSelected: vm.selectedState?.id == state.id
                            )
                        }
                        .listRowBackground(MakamStyle.rowBg)
                        .listRowSeparatorTint(MakamStyle.sand.opacity(0.1))
                    }
                    .listStyle(.insetGrouped)
                    .hideScrollContentBackground()
                    .searchable(text: $searchText, prompt: lang.str(.settingsSearchCity))
                    .tint(MakamStyle.gold)
                }
            }
        }
        .navigationTitle(lang.str(.settingsSelectCity))
        .navigationBarTitleDisplayMode(.inline)
        .applyToolbarStyling()
        .errorBanner(vm.errorMessage)
    }
}

// MARK: - District Picker

private struct DistrictPickerView: View {
    @EnvironmentObject var lang: LanguageManager
    @ObservedObject var vm: SettingsViewModel
    let state: ImsakiyemState
    let onSave: () -> Void

    @State private var searchText = ""

    private var filtered: [ImsakiyemDistrict] {
        guard !searchText.isEmpty else { return vm.districts }
        return vm.districts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.nameEn ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            MakamStyle.bg.ignoresSafeArea()

            Group {
                if vm.isLoadingDistricts {
                    ProgressView()
                        .tint(MakamStyle.gold)
                } else if vm.districts.isEmpty {
                    EmptyStateView(message: lang.str(.settingsDistrictError))
                } else {
                    List(filtered) { district in
                        Button {
                            vm.selectDistrict(district)
                        } label: {
                            LocationRow(
                                name: district.name,
                                subtitle: district.nameEn,
                                isSelected: vm.selectedDistrict?.id == district.id
                            )
                        }
                        .listRowBackground(MakamStyle.rowBg)
                        .listRowSeparatorTint(MakamStyle.sand.opacity(0.1))
                    }
                    .listStyle(.insetGrouped)
                    .hideScrollContentBackground()
                    .searchable(text: $searchText, prompt: lang.str(.settingsSearchDistrict))
                    .tint(MakamStyle.gold)
                }
            }
        }
        .navigationTitle(lang.str(.settingsSelectDistrict))
        .navigationBarTitleDisplayMode(.inline)
        .applyToolbarStyling()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(lang.str(.settingsSave)) { onSave() }
                    .disabled(vm.selectedDistrict == nil)
                    .foregroundStyle(
                        vm.selectedDistrict != nil ? MakamStyle.gold : Color.gray
                    )
                    .fontWeight(.semibold)
            }
        }
        .errorBanner(vm.errorMessage)
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
                    .foregroundStyle(MakamStyle.sand)

                if let sub = subtitle, !sub.isEmpty, sub != name {
                    Text(sub)
                        .font(.system(size: 12, weight: .light, design: .rounded))
                        .foregroundStyle(MakamStyle.sandDim)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(MakamStyle.gold)
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
                .foregroundStyle(MakamStyle.gold)
            Text(message)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(MakamStyle.sandDim)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Error Banner Modifier

private struct ErrorBannerModifier: ViewModifier {
    let message: String?

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            if let msg = message {
                Text(msg)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(MakamStyle.white)
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

    /// Hides the scroll content background on iOS 16+; no-op on iOS 15.
    @ViewBuilder
    func hideScrollContentBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }

    /// Applies dark toolbar styling on iOS 16+; no-op on iOS 15.
    @ViewBuilder
    func applyToolbarStyling() -> some View {
        if #available(iOS 16.0, *) {
            self
                .toolbarBackground(MakamStyle.bg, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        } else {
            self
        }
    }
}
