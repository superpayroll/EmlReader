import Foundation

enum EmlParserError: LocalizedError {
    case fileNotReadable
    case invalidFormat
    case encodingError

    var errorDescription: String? {
        switch self {
        case .fileNotReadable: return "The file could not be read."
        case .invalidFormat: return "The file is not a valid EML format."
        case .encodingError: return "The file encoding could not be determined."
        }
    }
}

struct EmlParser {

    static func parse(fileURL: URL) throws -> EmlMessage {
        guard let rawData = try? Data(contentsOf: fileURL) else {
            throw EmlParserError.fileNotReadable
        }

        guard let content = String(data: rawData, encoding: .utf8)
                ?? String(data: rawData, encoding: .ascii) else {
            throw EmlParserError.encodingError
        }

        let (headers, body) = splitHeadersAndBody(content)

        let subject = decodeHeader(extractHeader("Subject", from: headers))
        let from = decodeHeader(extractHeader("From", from: headers))
        let to = decodeHeader(extractHeader("To", from: headers))
        let cc = decodeHeader(extractHeader("Cc", from: headers))
        let date = extractHeader("Date", from: headers)
        let contentType = extractHeader("Content-Type", from: headers)

        var bodyPlain = ""
        var bodyHTML = ""
        var attachments: [EmlAttachment] = []

        if let boundary = extractBoundary(from: contentType) {
            // Multipart message
            let parts = splitMultipart(body: body, boundary: boundary)
            for part in parts {
                processPart(part, bodyPlain: &bodyPlain, bodyHTML: &bodyHTML, attachments: &attachments)
            }
        } else if contentType.lowercased().contains("text/html") {
            bodyHTML = decodeBody(body, headers: headers)
        } else {
            bodyPlain = decodeBody(body, headers: headers)
        }

        return EmlMessage(
            subject: subject,
            from: from,
            to: to,
            cc: cc,
            date: date,
            bodyPlain: bodyPlain,
            bodyHTML: bodyHTML,
            attachments: attachments
        )
    }

    // MARK: - Header Parsing

    private static func splitHeadersAndBody(_ content: String) -> (String, String) {
        // Headers and body are separated by a blank line
        if let range = content.range(of: "\r\n\r\n") {
            let headers = String(content[content.startIndex..<range.lowerBound])
            let body = String(content[range.upperBound...])
            return (headers, body)
        } else if let range = content.range(of: "\n\n") {
            let headers = String(content[content.startIndex..<range.lowerBound])
            let body = String(content[range.upperBound...])
            return (headers, body)
        }
        return (content, "")
    }

    private static func extractHeader(_ name: String, from headers: String) -> String {
        // Unfold headers (continuation lines start with whitespace)
        let unfolded = headers
            .replacingOccurrences(of: "\r\n ", with: " ")
            .replacingOccurrences(of: "\r\n\t", with: " ")
            .replacingOccurrences(of: "\n ", with: " ")
            .replacingOccurrences(of: "\n\t", with: " ")

        let lines = unfolded.components(separatedBy: .newlines)
        let prefix = name.lowercased() + ":"

        for line in lines {
            if line.lowercased().hasPrefix(prefix) {
                return line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    private static func decodeHeader(_ value: String) -> String {
        // Decode RFC 2047 encoded words: =?charset?encoding?text?=
        var result = value
        let pattern = "=\\?([^?]+)\\?([BbQq])\\?([^?]*)\\?="
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }

        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let charsetRange = Range(match.range(at: 1), in: result),
                  let encodingRange = Range(match.range(at: 2), in: result),
                  let textRange = Range(match.range(at: 3), in: result) else { continue }

            let charset = String(result[charsetRange])
            let encoding = String(result[encodingRange]).uppercased()
            let encodedText = String(result[textRange])

            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(charset as CFString)
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)

            var decoded: String?
            if encoding == "B" {
                if let data = Data(base64Encoded: encodedText) {
                    decoded = String(data: data, encoding: String.Encoding(rawValue: nsEncoding))
                }
            } else if encoding == "Q" {
                let unescaped = encodedText
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "=([0-9A-Fa-f]{2})", with: "", options: .regularExpression)
                // Decode quoted-printable
                decoded = decodeQuotedPrintableString(encodedText.replacingOccurrences(of: "_", with: " "),
                                                       encoding: String.Encoding(rawValue: nsEncoding))
                    ?? unescaped
            }

            if let decoded = decoded {
                result.replaceSubrange(fullRange, with: decoded)
            }
        }

        return result
    }

    // MARK: - Body Parsing

    private static func extractBoundary(from contentType: String) -> String? {
        guard contentType.lowercased().contains("multipart") else { return nil }

        let pattern = "boundary=\"?([^\";\\s]+)\"?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: contentType, range: NSRange(contentType.startIndex..., in: contentType)),
              let range = Range(match.range(at: 1), in: contentType) else { return nil }

        return String(contentType[range])
    }

    private static func splitMultipart(body: String, boundary: String) -> [String] {
        let delimiter = "--" + boundary
        let parts = body.components(separatedBy: delimiter)

        // Skip preamble (first) and closing delimiter (last ends with --)
        return parts.dropFirst().filter { !$0.hasPrefix("--") && !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func processPart(_ part: String, bodyPlain: inout String, bodyHTML: inout String, attachments: inout [EmlAttachment]) {
        let (partHeaders, partBody) = splitHeadersAndBody(part)

        let partContentType = extractHeader("Content-Type", from: partHeaders)
        let contentDisposition = extractHeader("Content-Disposition", from: partHeaders)
        let transferEncoding = extractHeader("Content-Transfer-Encoding", from: partHeaders)

        // Check for nested multipart
        if let nestedBoundary = extractBoundary(from: partContentType) {
            let nestedParts = splitMultipart(body: partBody, boundary: nestedBoundary)
            for nestedPart in nestedParts {
                processPart(nestedPart, bodyPlain: &bodyPlain, bodyHTML: &bodyHTML, attachments: &attachments)
            }
            return
        }

        let isAttachment = contentDisposition.lowercased().contains("attachment")
            || (!contentDisposition.isEmpty && contentDisposition.lowercased().contains("filename"))

        if isAttachment {
            if let attachment = parseAttachment(partHeaders: partHeaders, partBody: partBody, contentType: partContentType, transferEncoding: transferEncoding) {
                attachments.append(attachment)
            }
        } else if partContentType.lowercased().contains("text/html") {
            bodyHTML = decodeBody(partBody, transferEncoding: transferEncoding)
        } else if partContentType.lowercased().contains("text/plain") || partContentType.isEmpty {
            bodyPlain = decodeBody(partBody, transferEncoding: transferEncoding)
        } else if partContentType.lowercased().hasPrefix("image/") || partContentType.lowercased().hasPrefix("application/") {
            // Inline images and other binary content treated as attachments
            if let attachment = parseAttachment(partHeaders: partHeaders, partBody: partBody, contentType: partContentType, transferEncoding: transferEncoding) {
                attachments.append(attachment)
            }
        }
    }

    private static func parseAttachment(partHeaders: String, partBody: String, contentType: String, transferEncoding: String) -> EmlAttachment? {
        let filename = extractFilename(from: partHeaders)
        let mimeType = contentType.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespaces) ?? "application/octet-stream"

        let cleanBody = partBody.trimmingCharacters(in: .whitespacesAndNewlines)

        let data: Data?
        if transferEncoding.lowercased().contains("base64") {
            data = Data(base64Encoded: cleanBody, options: .ignoreUnknownCharacters)
        } else {
            data = cleanBody.data(using: .utf8)
        }

        guard let attachmentData = data, !attachmentData.isEmpty else { return nil }

        return EmlAttachment(
            filename: filename.isEmpty ? "untitled" : filename,
            mimeType: mimeType,
            data: attachmentData
        )
    }

    private static func extractFilename(from headers: String) -> String {
        // Try Content-Disposition filename first
        let dispositionPatterns = [
            "filename\\*=[^;]*''([^;\\s]+)",   // RFC 5987 encoded
            "filename=\"([^\"]+)\"",             // Quoted
            "filename=([^;\\s]+)"                // Unquoted
        ]

        let fullHeaders = headers
            .replacingOccurrences(of: "\r\n ", with: " ")
            .replacingOccurrences(of: "\n ", with: " ")

        for pattern in dispositionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: fullHeaders, range: NSRange(fullHeaders.startIndex..., in: fullHeaders)),
               let range = Range(match.range(at: 1), in: fullHeaders) {
                let filename = String(fullHeaders[range])
                return filename.removingPercentEncoding ?? filename
            }
        }

        // Try Content-Type name parameter
        let namePatterns = [
            "name=\"([^\"]+)\"",
            "name=([^;\\s]+)"
        ]

        for pattern in namePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: fullHeaders, range: NSRange(fullHeaders.startIndex..., in: fullHeaders)),
               let range = Range(match.range(at: 1), in: fullHeaders) {
                return String(fullHeaders[range])
            }
        }

        return ""
    }

    // MARK: - Content Decoding

    private static func decodeBody(_ body: String, headers: String = "", transferEncoding: String = "") -> String {
        let encoding = transferEncoding.isEmpty
            ? extractHeader("Content-Transfer-Encoding", from: headers)
            : transferEncoding

        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        switch encoding.lowercased() {
        case "base64":
            if let data = Data(base64Encoded: cleanBody, options: .ignoreUnknownCharacters),
               let decoded = String(data: data, encoding: .utf8) {
                return decoded
            }
            return cleanBody
        case "quoted-printable":
            return decodeQuotedPrintable(cleanBody)
        default:
            return cleanBody
        }
    }

    private static func decodeQuotedPrintable(_ input: String) -> String {
        var result = input
        // Remove soft line breaks
        result = result.replacingOccurrences(of: "=\r\n", with: "")
        result = result.replacingOccurrences(of: "=\n", with: "")

        // Decode =XX hex sequences
        let pattern = "=([0-9A-Fa-f]{2})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }

        var output = Data()
        var currentIndex = result.startIndex

        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        for match in matches {
            guard let fullRange = Range(match.range, in: result),
                  let hexRange = Range(match.range(at: 1), in: result) else { continue }

            // Append text before this match
            if currentIndex < fullRange.lowerBound {
                if let data = String(result[currentIndex..<fullRange.lowerBound]).data(using: .utf8) {
                    output.append(data)
                }
            }

            // Decode hex byte
            let hex = String(result[hexRange])
            if let byte = UInt8(hex, radix: 16) {
                output.append(byte)
            }

            currentIndex = fullRange.upperBound
        }

        // Append remaining text
        if currentIndex < result.endIndex {
            if let data = String(result[currentIndex...]).data(using: .utf8) {
                output.append(data)
            }
        }

        return String(data: output, encoding: .utf8) ?? result
    }

    private static func decodeQuotedPrintableString(_ input: String, encoding: String.Encoding) -> String? {
        var data = Data()
        var index = input.startIndex

        while index < input.endIndex {
            let char = input[index]
            if char == "=" {
                let nextIndex = input.index(index, offsetBy: 1, limitedBy: input.endIndex) ?? input.endIndex
                let afterIndex = input.index(index, offsetBy: 2, limitedBy: input.endIndex) ?? input.endIndex

                if nextIndex < input.endIndex && afterIndex <= input.endIndex {
                    let hex = String(input[nextIndex..<afterIndex])
                    if let byte = UInt8(hex, radix: 16) {
                        data.append(byte)
                        index = afterIndex
                        continue
                    }
                }
            }

            if let charData = String(char).data(using: .utf8) {
                data.append(charData)
            }
            index = input.index(after: index)
        }

        return String(data: data, encoding: encoding)
    }
}
