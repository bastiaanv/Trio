import CoreData
import Foundation

public extension UploadState {
    @nonobjc class func fetchRequest() -> NSFetchRequest<UploadState> {
        NSFetchRequest<UploadState>(entityName: "UploadState")
    }

    @NSManaged var backendId: String?
    @NSManaged var uploadedAt: Date?
    @NSManaged var glucoseOwner: GlucoseStored?
    @NSManaged var carbOwner: CarbEntryStored?
    @NSManaged var pumpEventOwner: PumpEventStored?
    @NSManaged var orefDeterminationOwner: OrefDetermination?
    @NSManaged var overrideOwner: OverrideStored?
    @NSManaged var overrideRunOwner: OverrideRunStored?
    @NSManaged var tempTargetOwner: TempTargetStored?
    @NSManaged var tempTargetRunOwner: TempTargetRunStored?
}

extension UploadState: Identifiable {}
