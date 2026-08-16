import Foundation
import CoreData

extension BaseNocturneManager {
    func performUploadCarbs() async {
        do {
            try await uploadCarbs(carbs: carbsStorage.getCarbsNotYetUploadedToNocturne())
            try await uploadCarbs(carbs: carbsStorage.getFPUsNotYetUploadedToNocturne())
        } catch {
            debug(
                .nightscout,
                "\(DebuggingIdentifiers.failed) failed to upload carbs with error: \(error)"
            )
        }
    }
    
    private func uploadCarbs(carbs: [NocturneUpsertCarb]) async {
        guard let nocturneAPI, !carbs.isEmpty else {
            return
        }
        
        do {
            let mappedCarbs = mapNocturneProperties(from: carbs)
            for chunk in mappedCarbs.chunks(ofCount: 100) {
                try await nocturneAPI.uploadCarbs(carbs: Array(chunk))
            }
            
            await updateCarbsAsUploaded(carbs)
            
            debug(.nightscout, "Nocturne carbs uploaded")
        } catch {
            debug(.nightscout, String(describing: error))
        }
    }
    
    private func updateCarbsAsUploaded(_ carbs: [NocturneUpsertCarb]) async {
        let context = CoreDataStack.shared.newTaskContext()
        context.name = "updateCarbsAsUploadedNocturne"
        await context.perform {
            let ids = carbs.map(\.id) as NSArray
            let fetchRequest: NSFetchRequest<CarbEntryStored> = CarbEntryStored.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)

            do {
                let results = try context.fetch(fetchRequest)
                for result in results {
                    result.isUploadedToNocturne = true
                }

                guard context.hasChanges else { return }
                try context.save()
            } catch let error as NSError {
                debugPrint(
                    "\(DebuggingIdentifiers.failed) \(#file) \(#function) Failed to update isUploadedToNocturne: \(error.userInfo)"
                )
            }
        }
    }
}
