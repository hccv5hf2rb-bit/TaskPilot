import SwiftUI

@main
struct TaskPilotApp: App {
    @StateObject private var store = AgentStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundScheduler.shared.register()
        BackgroundScheduler.shared.scheduleNext()
    }

    var body: some Scene {
        WindowGroup {
            TaskListView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                AgentStore.shared.save()
                BackgroundScheduler.shared.scheduleNext()
            }
        }
    }
}
