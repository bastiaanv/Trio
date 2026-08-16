import Combine
import Foundation

extension NocturneConfig {
    final class Provider: BaseProvider, NocturneConfigProvider {
        func checkConnection(url: URL, secret: String?) -> AnyPublisher<Void, Error> {
            NocturneAPI(url: url, secret: secret).checkConnection()
        }
    }
}
