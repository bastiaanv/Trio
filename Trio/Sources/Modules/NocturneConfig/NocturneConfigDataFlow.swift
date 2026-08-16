import Combine
import Foundation

enum NocturneConfig {
    enum Config {
        static let urlKey = "NocturneConfig.url"
        static let secretKey = "NocturneConfig.secret"
    }
}

protocol NocturneConfigProvider: Provider {
    func checkConnection(url: URL, secret: String?) -> AnyPublisher<Void, Error>
}
