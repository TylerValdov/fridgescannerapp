
//
//  NearbyStoresView.swift
//  fridgescannerapp
//
//  Find grocery stores on an interactive map and view store information.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

// Requests the device location only when the user opens the map or taps Near Me.
final class GroceryLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = "Location Services are off. Search by city or ZIP code instead."
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            errorMessage = nil
            manager.requestLocation()

        case .denied, .restricted:
            errorMessage = "Location access is unavailable. Search by city or ZIP code, or enable access in Settings."

        @unknown default:
            errorMessage = "Location is unavailable. Search by city or ZIP code."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways ||
            manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        location = locations.last
        errorMessage = nil
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        errorMessage = "We couldn't get your location. Search by city or ZIP code instead."
    }
}

private struct GroceryStore: Identifiable {
    let id = UUID()
    let item: MKMapItem

    var name: String {
        item.name ?? "Grocery Store"
    }

    var coordinate: CLLocationCoordinate2D {
        item.placemark.coordinate
    }

    var address: String {
        let place = item.placemark

        let street = [
            place.subThoroughfare,
            place.thoroughfare
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        let city = [
            place.locality,
            place.administrativeArea,
            place.postalCode
        ]
        .compactMap { $0 }
        .joined(separator: ", ")

        return [street, city]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

struct NearbyStoresView: View {
    @StateObject private var locationManager = GroceryLocationManager()

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var stores: [GroceryStore] = []
    @State private var selectedStore: GroceryStore?

    @State private var locationQuery = ""
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var hasLoadedNearbyStores = false
    @State private var activeSearchID = UUID()

    var body: some View {
        VStack(spacing: 0) {

            // Search by city or ZIP code.
            HStack(spacing: 8) {
                TextField("City or ZIP code", text: $locationQuery)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit {
                        Task {
                            await searchByLocation()
                        }
                    }

                Button("Search") {
                    Task {
                        await searchByLocation()
                    }
                }
                .disabled(
                    locationQuery.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty || isSearching
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            // Interactive map with grocery store pins.
            ZStack(alignment: .top) {
                Map(position: $cameraPosition) {
                    UserAnnotation()

                    ForEach(stores) { store in
                        Annotation(
                            store.name,
                            coordinate: store.coordinate
                        ) {
                            Button {
                                selectedStore = store
                            } label: {
                                Image(systemName: "basket.fill")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(.blue, in: Circle())
                                    .shadow(radius: 3)
                            }
                            .accessibilityLabel(
                                "Details for \(store.name)"
                            )
                        }
                    }
                }
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    visibleRegion = context.region
                }

                if isSearching {
                    ProgressView("Finding grocery stores...")
                        .padding(12)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // List of grocery stores found by the search.
            if !stores.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nearby Stores (\(stores.count))")
                        .font(.headline)
                        .padding(.horizontal)

                    List(stores) { store in
                        Button {
                            selectedStore = store
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "basket.fill")
                                    .foregroundStyle(.blue)

                                VStack(
                                    alignment: .leading,
                                    spacing: 4
                                ) {
                                    Text(store.name)
                                        .font(
                                            .subheadline.weight(.semibold)
                                        )
                                        .foregroundStyle(.primary)

                                    if !store.address.isEmpty {
                                        Text(
                                            store.address.replacingOccurrences(
                                                of: "\n",
                                                with: ", "
                                            )
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                    .frame(height: 230)
                }
                .padding(.top, 8)
            }

            // Display location or search errors.
            if let message = errorMessage ?? locationManager.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            // Location and map search controls.
            HStack {
                Button {
                    locationManager.requestLocation()

                    if let location = locationManager.location {
                        Task {
                            await searchNear(location)
                        }
                    }
                } label: {
                    Label("Near Me", systemImage: "location")
                }

                Spacer()

                Button {
                    if let region = visibleRegion {
                        Task {
                            await searchStores(in: region)
                        }
                    }
                } label: {
                    Label(
                        "Search This Area",
                        systemImage: "magnifyingglass"
                    )
                }
                .disabled(visibleRegion == nil || isSearching)
            }
            .buttonStyle(.bordered)
            .padding(12)
        }
        .navigationTitle("Grocery Stores")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedStore) { store in
            storeDetails(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if !hasLoadedNearbyStores {
                locationManager.requestLocation()
            }
        }
        .onReceive(locationManager.$location) { location in
            guard let location else {
                return
            }

            // Load stores near the user when location access is first granted.
            if !hasLoadedNearbyStores {
                hasLoadedNearbyStores = true

                Task {
                    await searchNear(location)
                }
            }
        }
    }

    // Search for grocery stores near the device's location.
    private func searchNear(_ location: CLLocation) async {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 10000,
            longitudinalMeters: 10000
        )

        cameraPosition = .region(region)
        visibleRegion = region

        await searchStores(in: region)
    }

    // Find a city or ZIP code and then search for grocery stores there.
    private func searchByLocation() async {
        let query = locationQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !query.isEmpty else {
            return
        }

        // Prevent a device-location update from replacing a manual search.
        hasLoadedNearbyStores = true

        // Ignore results from older searches.
        let requestID = UUID()
        activeSearchID = requestID
        isSearching = true
        errorMessage = nil

        defer {
            if activeSearchID == requestID {
                isSearching = false
            }
        }

        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query

            let response = try await MKLocalSearch(
                request: request
            ).start()

            guard activeSearchID == requestID else {
                return
            }

            guard let place = response.mapItems.first else {
                errorMessage = "That location wasn't found. Try another city or ZIP code."
                return
            }

            let region = MKCoordinateRegion(
                center: place.placemark.coordinate,
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            )

            cameraPosition = .region(region)
            visibleRegion = region

            await searchStores(in: region)
        } catch {
            guard activeSearchID == requestID else {
                return
            }

            errorMessage = "Could not find that location. Check your connection and try again."
        }
    }

    // Search Apple Maps for grocery stores in the selected region.
    private func searchStores(
        in region: MKCoordinateRegion
    ) async {
        let requestID = UUID()
        activeSearchID = requestID
        isSearching = true
        errorMessage = nil

        defer {
            if activeSearchID == requestID {
                isSearching = false
            }
        }

        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "grocery store"
            request.region = region
            request.resultTypes = .pointOfInterest

            let response = try await MKLocalSearch(
                request: request
            ).start()

            guard activeSearchID == requestID else {
                return
            }

            stores = response.mapItems.map {
                GroceryStore(item: $0)
            }

            if stores.isEmpty {
                errorMessage = "No grocery stores found here. Move the map and search again."
            }
        } catch {
            guard activeSearchID == requestID else {
                return
            }

            stores = []
            errorMessage = "Unable to load stores. Check your connection and try again."
        }
    }

    // Information sheet displayed when a grocery store is selected.
    private func storeDetails(
        _ store: GroceryStore
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(store.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Label(
                    "Grocery Store",
                    systemImage: "basket"
                )
                .foregroundStyle(.secondary)

                if !store.address.isEmpty {
                    Label(
                        store.address,
                        systemImage: "mappin.and.ellipse"
                    )
                }

                if let phone = store.item.phoneNumber,
                   !phone.isEmpty {
                    Label(phone, systemImage: "phone")
                }

                if let website = store.item.url,
                   ["http", "https"].contains(
                       website.scheme?.lowercased() ?? ""
                   ) {
                    Link(destination: website) {
                        Label(
                            "Visit Website",
                            systemImage: "globe"
                        )
                    }
                }

                Button {
                    store.item.openInMaps(
                        launchOptions: [
                            MKLaunchOptionsDirectionsModeKey:
                                MKLaunchOptionsDirectionsModeDriving
                        ]
                    )
                } label: {
                    Label(
                        "Get Directions",
                        systemImage: "car.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Text(
                    "Store information comes from Apple Maps. Item availability is not verified."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(24)
        }
    }
}
