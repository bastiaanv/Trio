import CoreData
import SwiftUI
import Swinject

extension NocturneConfig {
    struct RootView: BaseView {
        let resolver: Resolver
        let displayClose: Bool
        @StateObject var state = StateModel()

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            ZStack {
                List {
                    Section(
                        header: Text("Nocturne Integration"),
                        content: {
                            HStack {
                                TextField("URL", text: $state.url)
                                    .disableAutocorrection(true)
                                    .textContentType(.URL)
                                    .autocapitalization(.none)
                                    .keyboardType(.URL)

                                if state.message.isNotEmpty && !state.isValidURL {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                            SecureField("API secret", text: $state.secret)
                                .disableAutocorrection(true)
                                .autocapitalization(.none)
                                .textContentType(.password)
                                .keyboardType(.asciiCapable)

                            if !state.isConnectedToNocturne {
                                Button {
                                    state.connect()
                                } label: {
                                    Text("Connect to Nocturne")
                                        .font(.title3) }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .buttonStyle(.bordered)
                                    .disabled(state.url.isEmpty && state.connecting)
                            } else {
                                Button(role: .destructive) {
                                    state.delete()
                                } label: {
                                    Text("Disconnect and Remove")
                                        .font(.title3)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .buttonStyle(.bordered)
                                .tint(Color.loopRed)

                                Button(action: { state.testStepsUpload() }) {
                                    Text("Test step upload")
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .buttonStyle(.bordered)
                            }
                        }
                    ).listRowBackground(Color.chart)

                    if state.isMissingExtraHealthData {
                        Section(
                            header: Text("Extra health data"),
                            content: {
                                Text(
                                    "Trio is missing extra permission to upload steps count, heart rates and sleep data to Nocturne. Please enable these permissions in Settings."
                                )

                                Button(action: { state.requestPermissions() }) {
                                    Text("Request permission")
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .buttonStyle(.bordered)
                            }
                        ).listRowBackground(Color.chart)
                    }
                }
                .listSectionSpacing(sectionSpacing)
            }
            .navigationBarTitle("Nocturne")
            .navigationBarTitleDisplayMode(.automatic)
            .scrollContentBackground(.hidden).background(appState.trioBackgroundColor(for: colorScheme))
            .onAppear(perform: configureView)
        }
    }
}
