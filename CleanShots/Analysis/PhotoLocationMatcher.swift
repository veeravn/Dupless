import CoreLocation
import Foundation
import MapKit

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

/// Reverse-geocodes photo coordinates to place names via MapKit's
/// `MKReverseGeocodingRequest` — a network call to Apple's location service
/// (the iOS 26 replacement for the deprecated `CLGeocoder`). Results are cached
/// by rounded coordinate (a trip's photos share one place). This is the only
/// networked piece of the scan pipeline and runs only behind the opt-in
/// `AppSettings.locationMatchingEnabled`.
actor PhotoLocationService {
    private var cache: [String: [String]] = [:]

    /// Human-readable place fields (POI name, address, city, region) for a
    /// coordinate, or empty when geocoding fails / is offline.
    func placeFields(latitude: Double, longitude: Double) async -> [String] {
        let key = Self.key(latitude, longitude)
        if let cached = cache[key] { return cached }
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let fields = await Self.reverseGeocode(location)
        cache[key] = fields
        return fields
    }

    /// ~100 m precision: enough to collapse a venue's photos into one geocode.
    private static func key(_ lat: Double, _ lon: Double) -> String {
        String(format: "%.3f,%.3f", lat, lon)
    }

    /// MapKit's reverse-geocode getter is main-actor isolated, so run it there and
    /// hand only the Sendable `[String]` back to the actor — `MKMapItem` itself is
    /// not Sendable and must not cross the boundary.
    @MainActor
    private static func reverseGeocode(_ location: CLLocation) async -> [String] {
        guard let request = MKReverseGeocodingRequest(location: location),
              let mapItems = try? await request.mapItems else { return [] }
        return mapItems.flatMap(fields(from:))
    }

    private static func fields(from item: MKMapItem) -> [String] {
        var fields: [String] = []
        if let name = item.name { fields.append(name) }
        if let address = item.address {
            fields.append(address.fullAddress)
            if let short = address.shortAddress { fields.append(short) }
        }
        if let rep = item.addressRepresentations {
            if let city = rep.cityName { fields.append(city) }
            if let region = rep.regionName { fields.append(region) }
        }
        return fields
    }
}
