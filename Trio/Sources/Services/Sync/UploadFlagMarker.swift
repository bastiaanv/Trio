import CoreData
import Foundation

/// Marks Core Data rows as uploaded to a backend by inserting an `UploadState`
/// record with that backend's identity. One shared implementation of the
/// fetch-by-id / mark-uploaded / save step every uploader performs after a
/// successful upload.
enum UploadFlagMarker {
    /// Adds an `UploadState` row for `backend` to all `Entity` rows whose `id`
    /// attribute is contained in `ids`, on a fresh background task context.
    ///
    /// - Parameters:
    ///   - ids: Ids of the uploaded payload items, matched against the entity's `id`
    ///     attribute. Passed as `NSArray` so callers keep their existing
    ///     `payload.map(\.id) as NSArray` bridging, whatever the element type.
    ///   - backend: The backend the payload was uploaded to, e.g. `.nightscout`.
    ///   - contextName: Name for the task context; also used in failure logs.
    static func markUploaded<Entity: NSManagedObject>(
        _: Entity.Type,
        ids: NSArray,
        backend: UploadBackend,
        contextName: String
    ) async {
        let context = CoreDataStack.shared.newTaskContext()
        context.name = contextName
        await context.perform {
            let fetchRequest = NSFetchRequest<Entity>(entityName: String(describing: Entity.self))
            fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)

            do {
                let results = try context.fetch(fetchRequest)
                for result in results {
                    result.markUploaded(to: backend)
                }

                guard context.hasChanges else { return }
                try context.save()
            } catch let error as NSError {
                debugPrint(
                    "\(DebuggingIdentifiers.failed) \(contextName) failed to update upload state: \(error.userInfo)"
                )
            }
        }
    }
}
