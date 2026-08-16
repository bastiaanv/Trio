import Combine
import Foundation
import Swinject
import UIKit

protocol NocturneManager {
    func uploadHealthData() async
//    func uploadCarbs() async
}

class BaseNocturneManager: NocturneManager, Injectable {
    @Injected() private var keychain: Keychain!
    @Injected() var pumpHistoryStorage: PumpHistoryStorage!
    @Injected() var carbsStorage: CarbsStorage!
    @Injected() var healthkitManager: HealthKitManager!
    @Injected() private var notificationCenter: NotificationCenter!

    @Persisted(key: "nocturneLastUpload") var lastHealthDataUploaded: Date? = nil

    /// Coalesces and serializes upload runs so no two runs of the same pipeline overlap.
    /// Runs execute `performUpload(for:)`, provided at init. The public `upload*()`
    /// methods and `requestUpload(_:)` go through the serializer; the `performUpload*()`
    /// bodies must not call the awaitable `upload*()` entry points. The serializer
    /// asserts on such a call in debug builds and downgrades it to a fire-and-forget
    /// request in release.
    private var uploadSerializer: NocturneUploadSerializer!
    private var subscriptions = Set<AnyCancellable>()
    
    private static let NocturneAppName = "Trio"
    private static let NocturneAppSource = "org.nightscout.trio"

    var nocturneAPI: NocturneAPI? {
        guard let urlString = keychain.getValue(String.self, forKey: NocturneConfig.Config.urlKey),
              let url = URL(string: urlString),
              let secret = keychain.getValue(String.self, forKey: NocturneConfig.Config.secretKey)
        else {
            return nil
        }
        return NocturneAPI(url: url, secret: secret)
    }

    init(resolver: Resolver) {
        injectServices(resolver)

        uploadSerializer = NocturneUploadSerializer { [weak self] pipeline in
            await self?.performUpload(for: pipeline)
        }

        // Only upload data from HealthKit if the app is in the foreground
        // Only then Apple allows us to query HealthKit data (write is always allowed)
        notificationCenter
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task(priority: .utility) { await self.uploadHealthData() }
            }
            .store(in: &subscriptions)
    }
    
    /// Request an upload for a pipeline (enqueue work). Safe to call from anywhere.
    /// Bursts of requests coalesce: at most one run follows the one currently in flight.
    func requestUpload(_ uploadPipeline: NocturneUploadPipeline) {
        Task(priority: .utility) { [weak self] in
            await self?.uploadSerializer.request(uploadPipeline)
        }
    }

    private func performUpload(for uploadPipeline: NocturneUploadPipeline) async {
        switch uploadPipeline {
        case .healthData: await performUploadHealthData()
//        case .carbs: await performUploadCarbs()
        }
    }

    func uploadHealthData() async {
        await uploadSerializer.run(.healthData)
    }
    
//    func uploadCarbs() async {
//        await uploadSerializer.run(.carbs)
//    }
    
    func mapNocturneProperties<T: BaseNocturneUpsert>(from properties: [T]) -> [T] {
        let iso8601 = ISO8601DateFormatter()
        let tzOffsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let deviceId = UIDevice.current.identifierForVendor?.uuidString
        
        return properties.map { item in
            var localItem = item
            localItem.timestamp = iso8601.string(from: item.date)
            localItem.utcOffset = tzOffsetMinutes
            localItem.device = deviceId
            localItem.app = Self.NocturneAppName
            
            if item.dataSource == nil {
                localItem.dataSource = Self.NocturneAppSource
            }
            
            return localItem
        }
    }
}
