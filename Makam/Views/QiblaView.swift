import SwiftUI
import CoreLocation

// MARK: - QiblaViewModel

@MainActor
final class QiblaViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {

    // Kaaba coordinates
    private let kaabaLat =  21.4225 * .pi / 180
    private let kaabaLon =  39.8262 * .pi / 180
    private let kaabaLocation = CLLocation(latitude: 21.4225, longitude: 39.8262)

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    /// Bearing from user to Kaaba, measured clockwise from true north (degrees).
    @Published var qiblaBearing: Double = 0
    /// Device heading (true north = 0°). Nil until the first reading arrives.
    @Published var deviceHeading: Double? = nil
    /// Compass heading accuracy in degrees. Negative = invalid/uncalibrated.
    @Published var headingAccuracy: Double = -1
    /// Distance from user to Kaaba in metres. Nil until location is known.
    @Published var distanceToKaaba: Double? = nil
    /// Human-readable city/country from reverse geocoding.
    @Published var locationLabel: String? = nil
    @Published var status: Status = .idle

    enum Status {
        case idle, requesting, denied, locating, ready
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 1           // update every 1° change
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            status = .requesting
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        default:
            status = .denied
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.beginUpdates()
            case .denied, .restricted:
                self.status = .denied
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.qiblaBearing = self.bearing(from: loc.coordinate)
            self.distanceToKaaba = loc.distance(from: self.kaabaLocation)
            if self.status == .locating { self.status = .ready }
            self.reverseGeocode(loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            self.headingAccuracy = newHeading.headingAccuracy
            guard newHeading.headingAccuracy >= 0 else { return }
            self.deviceHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        }
    }

    // MARK: Private

    private func beginUpdates() {
        status = .locating
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let place = placemarks?.first else { return }
            let city    = place.locality ?? place.administrativeArea ?? ""
            let country = place.country ?? ""
            let label   = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
            Task { @MainActor in self.locationLabel = label.isEmpty ? nil : label }
        }
    }

    /// Great-circle bearing from `coord` to Kaaba (degrees, clockwise from true north).
    private func bearing(from coord: CLLocationCoordinate2D) -> Double {
        let lat1 = coord.latitude  * .pi / 180
        let lon1 = coord.longitude * .pi / 180
        let dLon = kaabaLon - lon1

        let y = sin(dLon) * cos(kaabaLat)
        let x = cos(lat1) * sin(kaabaLat) - sin(lat1) * cos(kaabaLat) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}

// MARK: - QiblaView

struct QiblaView: View {
    @StateObject private var vm = QiblaViewModel()

    /// Angle to rotate the compass rose so qibla arrow points at current direction.
    /// When deviceHeading is nil we show a static north-up compass.
    private var needleAngle: Double {
        guard let heading = vm.deviceHeading else { return vm.qiblaBearing }
        return vm.qiblaBearing - heading
    }

    /// True when compass calibration is poor (accuracy > 20° or unknown).
    private var needsCalibration: Bool {
        vm.headingAccuracy < 0 || vm.headingAccuracy > 20
    }

    /// Distance formatted as "1 234 km" or "850 m".
    private var distanceText: String? {
        guard let d = vm.distanceToKaaba else { return nil }
        if d >= 1000 {
            let km = d / 1000
            return String(format: km >= 10 ? "%.0f km" : "%.1f km", km)
        } else {
            return String(format: "%.0f m", d)
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.10).ignoresSafeArea()

            VStack(spacing: 36) {
                header

                switch vm.status {
                case .idle, .requesting:
                    permissionPrompt
                case .denied:
                    deniedPrompt
                case .locating:
                    loadingView
                case .ready:
                    compassView
                }

                Spacer()
            }
            .padding(.top, 56)
        }
        .onAppear { vm.start() }
    }

    // MARK: Sub-views

    private var header: some View {
        VStack(spacing: 4) {
            Text("Kıble")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Makam.sand)
            Text("Kabe yönü")
                .font(.subheadline)
                .foregroundColor(Makam.sand.opacity(0.5))
        }
    }

    private var permissionPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.circle")
                .font(.system(size: 64))
                .foregroundColor(Makam.gold.opacity(0.7))
            Text("Kıble yönünü hesaplamak için\nkonum iznine ihtiyaç duyulmaktadır.")
                .multilineTextAlignment(.center)
                .foregroundColor(Makam.sand.opacity(0.7))
                .padding(.horizontal, 32)
        }
    }

    private var deniedPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 64))
                .foregroundColor(Makam.gold.opacity(0.5))
            Text("Konum izni verilmedi.\nAyarlar'dan izin veriniz.")
                .multilineTextAlignment(.center)
                .foregroundColor(Makam.sand.opacity(0.7))
                .padding(.horizontal, 32)
            Button("Ayarları Aç") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .foregroundColor(Makam.gold)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Makam.gold)
            Text("Konum alınıyor…")
                .foregroundColor(Makam.sand.opacity(0.6))
                .font(.subheadline)
        }
    }

    private var compassView: some View {
        VStack(spacing: 20) {
            // Location label
            if let label = vm.locationLabel {
                Label(label, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundColor(Makam.sand.opacity(0.75))
            }

            // Calibration warning
            if needsCalibration {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Pusula kalibrasyonu gerekiyor")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(10)
            }

            ZStack {
                // Outer ring
                Circle()
                    .stroke(Makam.gold.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 280, height: 280)

                // Cardinal labels (fixed)
                cardinalLabels

                // Compass rose rotates so qibla arrow points at true direction
                ZStack {
                    // Tick marks
                    ForEach(0..<72) { i in
                        let major = i % 9 == 0
                        Rectangle()
                            .fill(Makam.sand.opacity(major ? 0.6 : 0.2))
                            .frame(width: major ? 2 : 1, height: major ? 12 : 6)
                            .offset(y: -122)
                            .rotationEffect(.degrees(Double(i) * 5))
                    }

                    // Qibla arrow
                    VStack(spacing: 0) {
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Makam.gold)
                        Text("☪︎")
                            .font(.system(size: 22))
                            .foregroundColor(Makam.gold)
                            .offset(y: 4)
                    }
                    .offset(y: -54)
                }
                .rotationEffect(.degrees(needleAngle))
                .animation(.easeOut(duration: 0.3), value: needleAngle)

                // Center dot
                Circle()
                    .fill(Makam.gold)
                    .frame(width: 10, height: 10)
            }

            // Bearing label
            VStack(spacing: 4) {
                Text(String(format: "%.1f°", vm.qiblaBearing))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(Makam.sand)
                Text("Kuzeyden saat yönünde")
                    .font(.caption)
                    .foregroundColor(Makam.sand.opacity(0.5))
            }

            // Distance to Kaaba
            if let dist = distanceText {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .foregroundColor(Makam.gold.opacity(0.8))
                    Text("Kabe'ye mesafe: \(dist)")
                        .font(.subheadline)
                        .foregroundColor(Makam.sand.opacity(0.75))
                }
            }
        }
    }

    private var cardinalLabels: some View {
        ZStack {
            ForEach(["K", "D", "G", "B"].indices, id: \.self) { i in
                let angle = Double(i) * 90
                let rad   = (angle - 90) * .pi / 180
                let r     = 118.0
                Text(["K", "D", "G", "B"][i])
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(i == 0 ? Makam.gold : Makam.sand.opacity(0.5))
                    .offset(x: r * cos(rad), y: r * sin(rad))
            }
        }
    }
}
