import CoreData
import Foundation

extension CoreDataStack {
    /// One-time migration that carries the legacy per-backend boolean "uploaded" flags
    /// (`isUploadedToNS` / `isUploadedToHealth` / `isUploadedToTidepool`) into generic
    /// `UploadState` records. Because the store only migrates lightweight, the boolean
    /// columns are kept in the model and read here; the app then uses only `UploadState`.
    ///
    /// Idempotent and guarded so it runs once after an upgrade. On a fresh install there
    /// are no uploaded rows, so it's a no-op.
    func backfillUploadStatesIfNeeded() async {
        let doneFlagKey = "didBackfillUploadStates"
        guard UserDefaults.standard.object(forKey: doneFlagKey) == nil else { return }

        let context = newTaskContext()
        context.name = "backfillUploadStates"

        // Maps each entity to the legacy boolean attributes it carried.
        let configurations: [(entity: String, flags: [(attribute: String, backend: UploadBackend)])] = [
            ("GlucoseStored", [
                ("isUploadedToNS", .nightscout),
                ("isUploadedToHealth", .health),
                ("isUploadedToTidepool", .tidepool),
            ]),
            ("CarbEntryStored", [
                ("isUploadedToNS", .nightscout),
                ("isUploadedToHealth", .health),
                ("isUploadedToTidepool", .tidepool),
            ]),
            ("PumpEventStored", [
                ("isUploadedToNS", .nightscout),
                ("isUploadedToHealth", .health),
                ("isUploadedToTidepool", .tidepool),
            ]),
            ("OrefDetermination", [("isUploadedToNS", .nightscout)]),
            ("OverrideStored", [("isUploadedToNS", .nightscout)]),
            ("OverrideRunStored", [("isUploadedToNS", .nightscout)]),
            ("TempTargetStored", [("isUploadedToNS", .nightscout)]),
            ("TempTargetRunStored", [("isUploadedToNS", .nightscout)]),
        ]

        await context.perform {
            for configuration in configurations {
                for flag in configuration.flags {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: configuration.entity)
                    fetchRequest.predicate = NSPredicate(format: "%K == YES", flag.attribute)
                    fetchRequest.fetchBatchSize = 200

                    guard let rows = try? context.fetch(fetchRequest) else { continue }
                    for row in rows {
                        row.markUploaded(to: flag.backend)
                    }
                }
            }

            guard context.hasChanges else { return }
            do {
                try context.save()
                debug(.coreData, "Migrated legacy upload flags into UploadState records. \(DebuggingIdentifiers.succeeded)")
            } catch {
                debug(.coreData, "Failed to backfill upload states: \(error)")
            }
        }

        // Mark done regardless of result so a partial failure doesn't retry in a loop;
        // a manual re-run can be forced by resetting this flag.
        UserDefaults.standard.set(true, forKey: doneFlagKey)
    }
}
