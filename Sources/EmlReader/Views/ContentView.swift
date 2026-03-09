import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if let message = appState.currentMessage {
                MessageView(message: message)
            } else {
                WelcomeView()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .alert("Error", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
            guard let urlData = data as? Data,
                  let path = String(data: urlData, encoding: .utf8),
                  let url = URL(string: path),
                  url.pathExtension.lowercased() == "eml" else { return }

            DispatchQueue.main.async {
                appState.openFile(at: url)
            }
        }
        return true
    }
}

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.open")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("EmlReader")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Open an .eml file to view its contents")
                .font(.title3)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Button("Open EML File...") {
                    appState.showOpenPanel()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("or drag and drop an .eml file here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 10)
        }
        .padding(40)
    }
}
