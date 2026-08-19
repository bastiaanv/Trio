import Foundation

/// Identifies a destination that Trio can upload records to.
///
/// Instead of a boolean column per backend (the former `isUploadedToNS`,
/// `isUploadedToHealth`, `isUploadedToTidepool`), a row's upload state is now
/// tracked generically through `UploadState` records whose `backendId` matches
/// one of these raw values. Adding a new backend is therefore a single enum case
/// and never requires a Core Data schema change.
enum UploadBackend: String, CaseIterable, Codable {
    case nightscout = "ns"
    case health = "health"
    case tidepool = "tidepool"
    case nocturne = "nocturne"
}
