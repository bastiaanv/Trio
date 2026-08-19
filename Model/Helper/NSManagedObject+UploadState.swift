import CoreData
import Foundation

/// Generic upload-state helpers backed by the `UploadState` to-many relationship,
/// which every uploadable entity now carries under the shared key `uploadStates`.
/// Uses KVC so the same code path serves all entities without per-class duplication.
extension NSManagedObject {
    private var allUploadStates: Set<UploadState> {
        (value(forKey: "uploadStates") as? Set<UploadState>) ?? []
    }

    /// Whether this row has already been uploaded to `backend`.
    func isUploaded(to backend: UploadBackend) -> Bool {
        allUploadStates.contains { $0.backendId == backend.rawValue }
    }

    /// Marks this row as uploaded to `backend`. Idempotent — does not create a
    /// duplicate `UploadState` if one already exists.
    func markUploaded(to backend: UploadBackend, at date: Date = .now) {
        guard !isUploaded(to: backend), let context = managedObjectContext else { return }

        let state = UploadState(context: context)
        state.backendId = backend.rawValue
        state.uploadedAt = date

        var states = allUploadStates
        states.insert(state)
        setValue(states, forKey: "uploadStates")
    }

    /// Removes the uploaded marker for `backend` (e.g. when a remote-fetched row is
    /// re-inserted locally and must be re-uploaded later).
    func resetUpload(to backend: UploadBackend) {
        guard let toRemove = allUploadStates.first(where: { $0.backendId == backend.rawValue }) else {
            return
        }
        var states = allUploadStates
        states.remove(toRemove)
        setValue(states, forKey: "uploadStates")
        managedObjectContext?.delete(toRemove)
    }
}

extension NSPredicate {
    /// Rows of the receiving entity that are newer than `date` and are NOT yet
    /// uploaded to `backend`. Uses an indexed `SUBQUERY` on the `uploadStates`
    /// relationship so `backendId` can be pushed down to SQLite.
    static func notYetUploaded(to backend: UploadBackend, since date: Date, dateKey: String) -> NSPredicate {
        NSPredicate(
            format: "%K >= %@ AND SUBQUERY(uploadStates, $state, $state.backendId == %@).@count == 0",
            dateKey,
            date as NSDate,
            backend.rawValue
        )
    }
}
