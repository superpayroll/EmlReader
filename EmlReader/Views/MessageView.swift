import SwiftUI
import WebKit

struct MessageView: View {
    let message: EmlMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header area
            VStack(alignment: .leading, spacing: 8) {
                Text(message.subject.isEmpty ? "(No Subject)" : message.subject)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .textSelection(.enabled)

                HeaderRow(label: "From", value: message.from)
                HeaderRow(label: "To", value: message.to)
                if !message.cc.isEmpty {
                    HeaderRow(label: "Cc", value: message.cc)
                }
                if !message.date.isEmpty {
                    HeaderRow(label: "Date", value: message.date)
                }
            }
            .padding()

            Divider()

            // Attachments bar
            if !message.attachments.isEmpty {
                AttachmentsBar(attachments: message.attachments)
                Divider()
            }

            // Body
            if !message.bodyHTML.isEmpty {
                HTMLBodyView(html: message.bodyHTML)
            } else {
                ScrollView {
                    Text(message.displayBody)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
    }
}

struct HeaderRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)

            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }
}

struct AttachmentsBar: View {
    let attachments: [EmlAttachment]
    @State private var savingAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "paperclip")
                    .foregroundColor(.secondary)
                Text("\(attachments.count) attachment\(attachments.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Save All...") {
                    saveAllAttachments()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(attachments) { attachment in
                        AttachmentChip(attachment: attachment)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func saveAllAttachments() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Save All Here"

        if panel.runModal() == .OK, let directory = panel.url {
            for attachment in attachments {
                let fileURL = directory.appendingPathComponent(attachment.filename)
                try? attachment.data.write(to: fileURL)
            }
        }
    }
}

struct AttachmentChip: View {
    let attachment: EmlAttachment
    @State private var isHovering = false

    var body: some View {
        Button(action: { saveAttachment() }) {
            HStack(spacing: 6) {
                Image(systemName: attachment.iconName)
                    .font(.caption)

                VStack(alignment: .leading, spacing: 1) {
                    Text(attachment.filename)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(attachment.fileSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? Color.accentColor.opacity(0.1) : Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("Click to save \(attachment.filename)")
    }

    private func saveAttachment() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = attachment.filename
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            try? attachment.data.write(to: url)
        }
    }
}

struct HTMLBodyView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.isElementFullscreenEnabled = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let styledHTML = """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.5;
                    color: #333;
                    padding: 16px;
                    margin: 0;
                    word-wrap: break-word;
                }
                @media (prefers-color-scheme: dark) {
                    body { color: #e0e0e0; }
                    a { color: #58a6ff; }
                }
                img { max-width: 100%; height: auto; }
                table { max-width: 100%; }
            </style>
        </head>
        <body>
        \(html)
        </body>
        </html>
        """
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
}
