import SwiftUI

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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var prayerViewModel: PrayerViewModel
    @StateObject private var vm = SettingsViewModel()

    var body: some View {
        NavigationStack {
            CountryPickerView(
                vm: vm,
                onSave: {
                    vm.saveSettings()
                    Task { await prayerViewModel.fetchPrayers() }
                    dismiss()
                },
                onCancel: { dismiss() }
            )
        }
        .task { await vm.loadCountries() }
    }
}

// MARK: - Country Picker

private struct CountryPickerView: View {
    @ObservedObject var vm: SettingsViewModel
    let onSave: () -> Void
    let onCancel: () -> Void

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
                    EmptyStateView(message: "Ülke listesi yüklenemedi.")
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
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Ülke ara")
                    .tint(MakamStyle.gold)
                }
            }
        }
        .navigationTitle("Ülke Seç")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MakamStyle.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("İptal", action: onCancel)
                    .foregroundStyle(MakamStyle.gold)
            }
        }
        .errorBanner(vm.errorMessage)
    }
}

// MARK: - State / City Picker

private struct StatePickerView: View {
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
                    EmptyStateView(message: "Şehir listesi yüklenemedi.")
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
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Şehir ara")
                    .tint(MakamStyle.gold)
                }
            }
        }
        .navigationTitle("Şehir Seç")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MakamStyle.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .errorBanner(vm.errorMessage)
    }
}

// MARK: - District Picker

private struct DistrictPickerView: View {
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
                    EmptyStateView(message: "İlçe listesi yüklenemedi.")
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
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "İlçe ara")
                    .tint(MakamStyle.gold)
                }
            }
        }
        .navigationTitle("İlçe Seç")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MakamStyle.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Kaydet") { onSave() }
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
}
