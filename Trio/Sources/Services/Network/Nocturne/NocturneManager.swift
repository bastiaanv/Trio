import Combine
import Foundation
import Swinject
import UIKit

protocol NocturneManager {
    func uploadHealthData() async
}

class BaseNocturneManager: NocturneManager, Injectable {
    @Injected() private var keychain: Keychain!
    @Injected() private var healthkitManager: HealthKitManager!
    @Injected() private var notificationCenter: NotificationCenter!

    @Persisted(key: "nocturneLastUpload") private var lastHealthDataUploaded: Date? = nil

    /// Coalesces and serializes upload runs so no two runs of the same pipeline overlap.
    /// Runs execute `performUpload(for:)`, provided at init. The public `upload*()`
    /// methods and `requestUpload(_:)` go through the serializer; the `performUpload*()`
    /// bodies must not call the awaitable `upload*()` entry points. The serializer
    /// asserts on such a call in debug builds and downgrades it to a fire-and-forget
    /// request in release.
    private var uploadSerializer: NocturneUploadSerializer!
    private var subscriptions = Set<AnyCancellable>()

    private var nocturneAPI: NocturneAPI? {
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

    private func performUpload(for uploadPipeline: NocturneUploadPipeline) async {
        switch uploadPipeline {
        case .healthData: await performUploadHealthData()
        }
    }

    func uploadHealthData() async {
        await uploadSerializer.run(.healthData)
    }

    private func performUploadHealthData() async {
        guard let nocturneAPI else {
            debug(.service, "No nocturne API for upload")
            return
        }

        let fromDate = lastHealthDataUploaded ?? Date.now.addingTimeInterval(.hours(-6))

        let heartRateData = await healthkitManager.loadHeartRate(from: fromDate, to: .now)
        if !heartRateData.isEmpty {
            for chunk in heartRateData.chunks(ofCount: 100) {
                await nocturneAPI.uploadHeartRates(steps: Array(chunk))
            }
        }

        let stepsData = await healthkitManager.loadSteps(from: fromDate, to: .now)
        if !stepsData.isEmpty {
            for chunk in stepsData.chunks(ofCount: 100) {
                await nocturneAPI.uploadSteps(steps: Array(chunk))
            }
        }

        debug(.service, "Nocturne upload completed! count: \(heartRateData.count + stepsData.count)")
        lastHealthDataUploaded = Date.now
    }
}
