import Combine
import Foundation

class NocturneAPI {
    private enum Config {
        static let checkConnectionPath = "api/v4/glucose/sensor"
        static let stepsPath = "/api/v4/StepCount"
        static let heartRatesPath = "/api/v4/HeartRate"
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

    func uploadSteps(steps: [UpsertStepCountRequest]) async {
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

    func uploadHeartRates(steps: [UpsertHeartRateRequest]) async {
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
            let encodedBody = try JSONCoding.encoder.encode(steps)
            request.httpBody = encodedBody

            let (data, response) = try await URLSession.shared.data(for: request)
            debug(
                .service,
                "Upload heartrates: \((response as? HTTPURLResponse)?.statusCode ?? -1) data: \(String(data: data, encoding: .utf8) ?? "")"
            )
        } catch {
            warning(.service, "Failed to upload heart rates: \(error.localizedDescription)")
        }
    }
}

struct UpsertStepCountRequest: Codable {
    let timestamp: String // ISO-8601 date-time
    let utcOffset: Int? // UTC offset in minutes
    let metric: Int // step count
    let source: Int // HKSource identifier hash
    let device: String?
    let app: String? // Will always be Trio
    let dataSource: String? // For steps, this will always be com.apple.health
    let syncIdentifier: String?
}

struct UpsertHeartRateRequest: Encodable {
    let timestamp: String // ISO-8601 date-time
    let utcOffset: Int? // UTC offset in minutes
    let accuracy: Int?
    let bpm: Int
    let device: String?
    let app: String? // Will always be Trio
    let dataSource: String? // For heart rates, this will always be com.apple.health
    let syncIdentifier: String?
}
