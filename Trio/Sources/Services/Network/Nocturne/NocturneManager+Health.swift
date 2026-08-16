import Foundation

extension BaseNocturneManager {
    func performUploadHealthData() async {
        guard let nocturneAPI else {
            debug(.service, "No nocturne API for upload")
            return
        }

        let fromDate = lastHealthDataUploaded ?? Date.now.addingTimeInterval(.hours(-6))

        let heartRateData = await healthkitManager.loadHeartRate(from: fromDate, to: .now)
        if !heartRateData.isEmpty {
            let mappedData = mapNocturneProperties(from: heartRateData)
            for chunk in mappedData.chunks(ofCount: 100) {
                await nocturneAPI.uploadHeartRates(heartRates: Array(chunk))
            }
        }

        let stepsData = await healthkitManager.loadSteps(from: fromDate, to: .now)
        if !stepsData.isEmpty {
            let mappedData = mapNocturneProperties(from: stepsData)
            for chunk in mappedData.chunks(ofCount: 100) {
                await nocturneAPI.uploadSteps(steps: Array(chunk))
            }
        }

        debug(.service, "Nocturne upload completed! count: \(heartRateData.count + stepsData.count)")
        lastHealthDataUploaded = Date.now
    }
}
