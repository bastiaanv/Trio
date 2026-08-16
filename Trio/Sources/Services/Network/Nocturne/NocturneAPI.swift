import Combine
import Foundation

class NocturneAPI {
    private enum Config {
        static let checkConnectionPath = "api/v4/glucose/sensor"
        static let stepsPath = "/api/v4/StepCount"
        static let heartRatesPath = "/api/v4/HeartRate"
        static let carbsPath = "/api/v4/nutrition/carbs"
        static let retryCount = 1
        static let timeout: TimeInterval = 60
    }

    init(url: URL, secret: String? = nil) {
        // https://diakit.nl
        self.url = url
        // noc_C6X8oOHbeRgGG3nHcg0cGc3tApUPDwpfuz5FSBkPPpg
        self.secret = secret?.nonEmpty
    }

    let url: URL
    let secret: String?

    private let service = NetworkService()

    @Injected() private var settingsManager: SettingsManager!
}

extension NocturneAPI {
    func checkConnection() -> AnyPublisher<Void, Swift.Error> {
        var components = URLComponents()
        components.scheme = url.scheme
        components.host = url.host
        components.port = url.port
        components.path = Config.checkConnectionPath

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = Config.timeout

        if let secret {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        return service.run(request)
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func uploadSteps(steps: [NocturneUpsertStepCount]) async {
        var components = URLComponents()
        components.scheme = url.scheme
        components.host = url.host
        components.port = url.port
        components.path = Config.stepsPath

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.timeoutInterval = Config.timeout
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let secret {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        do {
            let encodedBody = try JSONCoding.encoder.encode(steps)
            request.httpBody = encodedBody

            _ = try await URLSession.shared.data(for: request)
        } catch {
            warning(.service, "Failed to upload steps: \(error.localizedDescription)")
        }
    }

    func uploadHeartRates(heartRates: [NocturneUpsertHeartRate]) async {
        var components = URLComponents()
        components.scheme = url.scheme
        components.host = url.host
        components.port = url.port
        components.path = Config.heartRatesPath

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.timeoutInterval = Config.timeout
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let secret {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        do {
            let encodedBody = try JSONCoding.encoder.encode(heartRates)
            request.httpBody = encodedBody

            _ = try await URLSession.shared.data(for: request)
        } catch {
            warning(.service, "Failed to upload heart rates: \(error.localizedDescription)")
        }
    }

    func uploadCarbs(carbs: [NocturneUpsertCarb]) async throws {
        var components = URLComponents()
        components.scheme = url.scheme
        components.host = url.host
        components.port = url.port
        components.path = Config.carbsPath

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.timeoutInterval = Config.timeout
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let secret {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        let encodedBody = try JSONCoding.encoder.encode(carbs)
        request.httpBody = encodedBody

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, 200 ..< 300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
    }
}

protocol BaseNocturneUpsert {
    /// Internal only
    var date: Date { get set }

    /// ISO-8601 date-time
    var timestamp: String { get set }

    /// UTC offset in minutes
    var utcOffset: Int? { get set }

    /// An id of this device
    var device: String? { get set }

    /// The name of the source, this will always be Trio
    var app: String? { get set }

    /// The data source, for steps this will be com.apple.health, otherwise this will be org.nightscout.trio
    var dataSource: String? { get set }
    var syncIdentifier: String? { get set }
}

struct NocturneUpsertStepCount: BaseNocturneUpsert, Encodable {
    /// Step count
    let metric: Int

    /// Unknown property
    let source: Int

    var date: Date
    var timestamp: String
    var utcOffset: Int?
    var device: String?
    var app: String?
    var dataSource: String?
    var syncIdentifier: String?
}

struct NocturneUpsertHeartRate: BaseNocturneUpsert, Encodable {
    /// The accuracy of the sensor
    let accuracy: Int?

    /// The actual heart rate measurement
    let bpm: Int

    var date: Date
    var timestamp: String
    var utcOffset: Int?
    var device: String?
    var app: String?
    var dataSource: String?
    var syncIdentifier: String?
}

struct NocturneUpsertCarb: BaseNocturneUpsert, Encodable {
    ///  Internal only
    let id: String?

    /// The actual carbs
    let carbs: Double

    /// Minutes from bolus time to expected carb absorption start (pre-bolus offset)
    let carbTime: Int?

    /// Expected carb absorption duration in minutes.
    let absorptionTime: Int?

    /// Fat consumed in grams, when the source reports macros. Native fields replace the synthesized FPU fake-carb series legacy uploaders emit for Nightscout.
    let fatGrams: Double?

    /// Protein consumed in grams, when the source reports macros.
    let proteinGrams: Double?

    var date: Date
    var timestamp: String
    var utcOffset: Int?
    var device: String?
    var app: String?
    var dataSource: String?
    var syncIdentifier: String?
}
