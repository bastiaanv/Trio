import CoreData
import Foundation

extension NSPredicate {
    static var fpusForChart: NSPredicate {
        let date = Date.oneDayAgo
        return NSPredicate(format: "isFPU == true AND date >= %@", date as NSDate)
    }

    static var carbsForChart: NSPredicate {
        let date = Date.oneDayAgo
        return NSPredicate(format: "isFPU == false AND date >= %@ AND carbs > 0", date as NSDate)
    }

    static func carbsForChart(since date: Date) -> NSPredicate {
        NSPredicate(format: "isFPU == false AND date >= %@ AND carbs > 0", date as NSDate)
    }

    static func fpusForChart(since date: Date) -> NSPredicate {
        NSPredicate(format: "isFPU == true AND date >= %@", date as NSDate)
    }

    static var carbsForStats: NSPredicate {
        let date = Date.threeMonthsAgo
        return NSPredicate(format: "date >= %@ AND isFPU == %@", date as NSDate, false as NSNumber)
    }

    static var carbsNotYetUploadedToNightscout: NSPredicate {
        NSPredicate(
            format: "%@ AND isFPU == %@ AND carbs > 0",
            NSPredicate.notYetUploaded(to: .nightscout, since: Date.oneDayAgo, dateKey: "date"),
            false as NSNumber
        )
    }

    static var carbsNotYetUploadedToHealth: NSPredicate {
        NSPredicate.notYetUploaded(to: .health, since: Date.oneDayAgo, dateKey: "date")
    }

    static var carbsNotYetUploadedToTidepool: NSPredicate {
        NSPredicate.notYetUploaded(to: .tidepool, since: Date.oneDayAgo, dateKey: "date")
    }

    static var fpusNotYetUploadedToNightscout: NSPredicate {
        NSPredicate(
            format: "%@ AND isFPU == %@",
            NSPredicate.notYetUploaded(to: .nightscout, since: Date.oneDayAgo, dateKey: "date"),
            true as NSNumber
        )
    }
}

extension CarbEntryStored {
    static func fetch(
        _ predicate: NSPredicate = .predicateForOneDayAgo,
        fetchLimit: Int = 100,
        ascending: Bool = false
    ) -> NSFetchRequest<CarbEntryStored> {
        let request = CarbEntryStored.fetchRequest() as NSFetchRequest<CarbEntryStored>
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CarbEntryStored.date, ascending: ascending)]
        request.fetchLimit = fetchLimit
        request.predicate = predicate
        return request
    }
}
