import SwiftUI

@main
struct EmlReaderApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    appState.openFile(at: url)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open EML File...") {
                    appState.showOpenPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var currentMessage: EmlMessage?
    @Published var errorMessage: String?

    func openFile(at url: URL) {
        do {
            let message = try EmlParser.parse(fileURL: url)
            DispatchQueue.main.async {
                self.currentMessage = message
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to open file: \(error.localizedDescription)"
            }
        }
    }

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "eml")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            openFile(at: url)
        }
    }
}
