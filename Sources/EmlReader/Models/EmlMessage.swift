import Foundation

struct EmlMessage: Identifiable {
    let id = UUID()
    let subject: String
    let from: String
    let to: String
    let cc: String
    let date: String
    let bodyPlain: String
    let bodyHTML: String
    let attachments: [EmlAttachment]

    var displayBody: String {
        if !bodyPlain.isEmpty {
            return bodyPlain
        }
        // Strip HTML tags for plain display fallback
        return bodyHTML.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
    }
}

struct EmlAttachment: Identifiable {
    let id = UUID()
    let filename: String
    let mimeType: String
    let data: Data

    var fileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(data.count))
    }

    var fileExtension: String {
        (filename as NSString).pathExtension.lowercased()
    }

    var iconName: String {
        switch fileExtension {
        case "pdf": return "doc.richtext"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff": return "photo"
        case "doc", "docx": return "doc.text"
        case "xls", "xlsx": return "tablecells"
        case "zip", "rar", "7z": return "archivebox"
        case "txt": return "doc.plaintext"
        default: return "paperclip"
        }
    }
}
