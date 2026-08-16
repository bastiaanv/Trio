import Foundation

extension NocturneConfig {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() private var keychain: Keychain!
        @Injected() private var healthKitManager: HealthKitManager!
        @Injected() private var noctureManager: NocturneManager!

        @Published var url = ""
        @Published var secret = ""
        @Published var message = ""
        @Published var isValidURL = false
        @Published var connecting = false
        @Published var isConnectedToNocturne = false
        @Published var isMissingExtraHealthData = false

        override func subscribe() {
            url = keychain.getValue(String.self, forKey: Config.urlKey) ?? ""
            secret = keychain.getValue(String.self, forKey: Config.secretKey) ?? ""

            isMissingExtraHealthData = !healthKitManager.hasGrantedReadPermissions
            isConnectedToNocturne = nocturneAPI != nil
        }

        private var nocturneAPI: NocturneAPI? {
            guard let urlString = keychain.getValue(String.self, forKey: NocturneConfig.Config.urlKey),
                  let url = URL(string: urlString),
                  let secret = keychain.getValue(String.self, forKey: NocturneConfig.Config.secretKey)
            else {
                return nil
            }
            return NocturneAPI(url: url, secret: secret)
        }

        func testStepsUpload() {
            Task {
                await noctureManager.uploadHealthData()
            }
        }

        func connect() {
            if let checkURL = url.last, checkURL == "/" {
                let fixedURL = url.dropLast()
                url = String(fixedURL)
            }

            guard let url = URL(string: url), self.url.hasPrefix("https://") else {
                message = String(localized: "Invalid URL")
                isValidURL = false
                return
            }

            connecting = true
            isValidURL = true
            message = ""

            provider.checkConnection(url: url, secret: secret.isEmpty ? nil : secret)
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    switch completion {
                    case .finished: break
                    case let .failure(error):
                        self.message = "Error: \(error.localizedDescription)"
                    }
                    self.connecting = false
                } receiveValue: {
                    self.message = String(localized: "Connected!")
                    self.keychain.setValue(self.url, forKey: Config.urlKey)
                    self.keychain.setValue(self.secret, forKey: Config.secretKey)
                    self.connecting = true
                    self.isConnectedToNocturne = self.nocturneAPI != nil
                }
                .store(in: &lifetime)
        }

        func requestPermissions() {
            Task {
                let hasPermissions = try? await healthKitManager.requestReadPermissions()
                if let hasPermissions {
                    await MainActor.run {
                        isMissingExtraHealthData = !hasPermissions
                    }
                }
            }
        }

        func delete() {
            keychain.removeObject(forKey: Config.urlKey)
            keychain.removeObject(forKey: Config.secretKey)
            url = ""
            secret = ""
            isConnectedToNocturne = false
        }
    }
}
