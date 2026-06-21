import CoreLocation
import Foundation

/// Decides whether a place query (e.g. "mall of america") matches the
/// human-readable fields of a reverse-geocoded location. Pure and unit-tested;
/// the geocoding itself lives in `PhotoLocationService`.
struct PhotoLocationMatcher: Sendable {
    /// True when every query token (3+ letters) appears in some place field, so
    /// "mall of america" matches an area-of-interest "Mall of America" while a
    /// lone token like "mall" alone wouldn't pull in unrelated places. An empty
    /// query matches everything.
    func matches(query: String, placeFields: [String]) -> Bool {
        let tokens = query.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 }
        guard !tokens.isEmpty else { return true }
        let haystack = placeFields.map { $0.lowercased() }
        return tokens.allSatisfy { token in
            haystack.contains { $0.contains(token) }
        }
    }
}

/// Reverse-geocodes photo coordinates to place names, on a network call to
/// Apple's geocoder. Results are cached by rounded coordinate (a trip's photos
/// share one place), and calls are serialized — `CLGeocoder` rejects concurrent
/// or rapid requests. This is the only networked piece of the scan pipeline and
/// runs only behind the opt-in `AppSettings.locationMatchingEnabled`.
actor PhotoLocationService {
    private let geocoder = CLGeocoder()
    private var cache: [String: [String]] = [:]

    /// Human-readable place fields (POI name, areas of interest, locality, …) for
    /// a coordinate, or empty when geocoding fails / is offline.
    func placeFields(latitude: Double, longitude: Double) async -> [String] {
        let key = Self.key(latitude, longitude)
        if let cached = cache[key] { return cached }
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let placemarks = (try? await geocoder.reverseGeocodeLocation(location)) ?? []
        let fields = placemarks.flatMap(Self.fields(from:))
        cache[key] = fields
        return fields
    }

    /// ~100 m precision: enough to collapse a venue's photos into one geocode.
    private static func key(_ lat: Double, _ lon: Double) -> String {
        String(format: "%.3f,%.3f", lat, lon)
    }

    private static func fields(from placemark: CLPlacemark) -> [String] {
        var fields: [String] = []
        if let name = placemark.name { fields.append(name) }
        if let aoi = placemark.areasOfInterest { fields.append(contentsOf: aoi) }
        if let sub = placemark.subLocality { fields.append(sub) }
        if let locality = placemark.locality { fields.append(locality) }
        if let admin = placemark.administrativeArea { fields.append(admin) }
        if let thoroughfare = placemark.thoroughfare { fields.append(thoroughfare) }
        return fields
    }
}
