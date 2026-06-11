import ActivityKit
import SwiftUI
import Swinject

extension LiveActivitySettings {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        @State private var shouldDisplayHintLockScreen: Bool = false
        @State var hintDetent = PresentationDetent.large
        @State var selectedVerboseHint: AnyView?
        @State var hintLabel: String?
        @State private var decimalPlaceholder: Decimal = 0.0
        @State private var booleanPlaceholder: Bool = false

        @State private var systemLiveActivitySetting: Bool = {
            if #available(iOS 16.2, *) {
                ActivityAuthorizationInfo().areActivitiesEnabled
            } else {
                false
            }
        }()

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            List {
                if !systemLiveActivitySetting {
                    Section(
                        header: Text("Display Live Data From Trio"),
                        content: {
                            Text("Live Activities must be enabled under iOS Settings to allow Trio to display live data.")
                        }
                    ).listRowBackground(Color.chart)

                    Section {
                        Button {
                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                        }
                        label: { Label("Open iOS Settings", systemImage: "gear.circle").font(.title3).padding() }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .buttonStyle(.bordered)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    SettingInputSection(
                        decimalValue: $decimalPlaceholder,
                        booleanValue: $state.useLiveActivity,
                        shouldDisplayHint: $shouldDisplayHintLockScreen,
                        selectedVerboseHint: Binding(
                            get: { selectedVerboseHint },
                            set: {
                                selectedVerboseHint = $0.map { AnyView($0) }
                                hintLabel = String(localized: "Enable Live Activity")
                            }
                        ),
                        units: state.units,
                        type: .boolean,
                        label: String(localized: "Enable Live Activity"),
                        miniHint: String(localized: "Display customizable data on Lock Screen and Dynamic Island."),
                        verboseHint: VStack(alignment: .leading, spacing: 10) {
                            Text("Default: OFF").bold()
                            VStack(alignment: .leading, spacing: 10) {
                                Text(
                                    "With Live Activities enabled, Trio displays your choice of the following current data on your iPhone's Lock Screen and in the Dynamic Island:"
                                )
                                VStack(alignment: .leading) {
                                    Text("• Current Glucose Reading")
                                    Text("• IOB: Insulin On Board")
                                    Text("• COB: Carbohydrates On Board")
                                    Text("• Last Updated: Time of Last Loop Cycle")
                                    Text("• Glucose Trend Chart")
                                }.font(.footnote)
                                Text(
                                    "It allows you to refer to live information at a glance and perform quick actions in your diabetes management."
                                )
                            }
                        },
                        headerText: String(localized: "Display Live Data From Trio")
                    )

                    if state.useLiveActivity {
                        Section {
                            LiveActivityStyle(
                                label: String(localized: "Lock Screen Widget Style"),
                                labelSimple: String(
                                    localized: "Trio's Simple Lock Screen Widget displays current glucose reading, trend arrow, delta and the timestamp of the current reading."
                                ),
                                labelDetailed: String(
                                    localized: "The Detailed Lock Screen Widget offers users a glucose chart as well as the ability to customize the information provided in the Detailed Widget using the following options:"
                                ),
                                setting: $state.lockScreenView,
                                addExtras: true
                            )

                            if state.lockScreenView == .detailed {
                                HStack {
                                    NavigationLink(
                                        "Widget Configuration",
                                        destination: LiveActivityWidgetConfiguration(
                                            resolver: resolver,
                                            state: state
                                        )
                                    ).foregroundStyle(Color.accentColor)
                                }
                            }
                        }.listRowBackground(Color.chart)

                        if #available(iOS 18.0, *) {
                            Section {
                                LiveActivityStyle(
                                    label: String(localized: "WatchOS Widget Style"),
                                    labelSimple: String(
                                        localized: "Trio's Simple WatchOS Widget displays current glucose reading, trend arrow, delta and the timestamp of the current reading."
                                    ),
                                    labelDetailed: String(
                                        localized: "The Detailed WatchOS Screen Widget offers users a glucose chart as well as the current glucose, delta and the timestamp of current reading."
                                    ),
                                    setting: $state.smartStackView
                                )
                            }.listRowBackground(Color.chart)
                        }

                        if #available(iOS 26.0, *) {
                            Section {
                                LiveActivityStyle(
                                    label: String(localized: "CarPlay Widget Style"),
                                    labelSimple: String(
                                        localized: "Trio's Simple Carplay Widget displays current glucose reading, trend arrow, delta and the timestamp of the current reading."
                                    ),
                                    labelDetailed: String(
                                        localized: "The Detailed Carplay Screen Widget offers users a glucose chart as well as the current glucose, delta and the timestamp of current reading."
                                    ),
                                    setting: $state.carPlaykView
                                )
                            }.listRowBackground(Color.chart)
                        }
                    }
                }
            }
            .listSectionSpacing(sectionSpacing)
            .onReceive(resolver.resolve(LiveActivityManager.self)!.$systemEnabled, perform: {
                self.systemLiveActivitySetting = $0
            })
            .sheet(isPresented: $shouldDisplayHintLockScreen) {
                SettingInputHintView(
                    hintDetent: $hintDetent,
                    shouldDisplayHint: $shouldDisplayHintLockScreen,
                    hintLabel: hintLabel ?? "",
                    hintText: selectedVerboseHint ?? AnyView(EmptyView()),
                    sheetTitle: String(localized: "Help", comment: "Help sheet title")
                )
            }
            .scrollContentBackground(.hidden).background(appState.trioBackgroundColor(for: colorScheme))
            .onAppear(perform: configureView)
            .navigationTitle("Live Activity")
            .navigationBarTitleDisplayMode(.automatic)
            .settingsHighlightScroll()
        }

        @ViewBuilder func LiveActivityStyle(
            label: String,
            labelSimple: String,
            labelDetailed: String,
            setting: Binding<LockScreenView>,
            addExtras: Bool = false
        ) -> some View {
            VStack {
                Picker(
                    selection: setting,
                    label: Text(label)
                ) {
                    ForEach(LockScreenView.allCases) { selection in
                        Text(selection.displayName).tag(selection)
                    }
                }.padding(.top)

                HStack(alignment: .center) {
                    Text(
                        "Select simple or detailed style. See hint for more details."
                    )
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    Spacer()
                    Button(
                        action: {
                            hintLabel = label
                            selectedVerboseHint =
                                AnyView(
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Default: Simple").bold()
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text("Simple:").bold()
                                            Text(labelSimple)
                                        }
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text("Detailed:").bold()
                                            Text(labelDetailed)

                                            if addExtras {
                                                VStack(alignment: .leading) {
                                                    Text("• Current Glucose Reading")
                                                    Text("• IOB: Insulin On Board")
                                                    Text("• COB: Carbohydrates On Board")
                                                    Text("• Last Updated: Time of Last Loop Cycle")
                                                }.font(.footnote)
                                            }
                                        }
                                    }
                                )
                            shouldDisplayHintLockScreen.toggle()
                        },
                        label: {
                            HStack {
                                Image(systemName: "questionmark.circle")
                            }
                        }
                    ).buttonStyle(BorderlessButtonStyle())
                }.padding(.top)
            }.padding(.bottom)
        }
    }
}
