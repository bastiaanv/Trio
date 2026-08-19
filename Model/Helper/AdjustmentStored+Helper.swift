import CoreData
import Foundation

extension NSPredicate {
    static var lastActiveAdjustmentNotYetUploadedToNightscout: NSPredicate {
        NSPredicate(
            format: "%@ AND enabled == %@",
            NSPredicate.notYetUploaded(to: .nightscout, since: Date.oneDayAgo, dateKey: "date"),
            true as NSNumber
        )
    }
}
