import Foundation
import PDFKit
import Vision
import AppKit

public struct ExtractedText: Sendable {
    public var text: String
    public var note: String
    public var complete: Bool
}
public enum TextExtractor {
    public static let plainExtensions: Set<String> = ["txt", "md", "markdown", "csv", "tsv", "log", "json", "yaml", "yml", "tex"]
    public static let documentExtensions: Set<String> = plainExtensions.union(["pdf", "docx", "xlsx", "pptx", "doc", "rtf", "odt"])
    public static func extract(_ url: URL) throws -> ExtractedText {
        let fp = try Fingerprint(url)
        guard fp.size <= 30_000_000 else { throw SorterError.message("Document exceeds 30 MB extraction limit; review manually.") }
        let ext = url.pathExtension.lowercased()
        if plainExtensions.contains(ext) {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16)
            guard let text, !text.contains("\0") else { throw SorterError.message("Unsupported text encoding or binary content.") }
            return bounded(text, note: "Local text")
        }
        if ext == "pdf" { return try pdf(url) }
        if ["doc", "rtf", "odt"].contains(ext) {
            return bounded(try LocalProcess.run("/usr/bin/textutil", ["-convert", "txt", "-stdout", url.path]), note: "Local textutil")
        }
        if ["docx", "xlsx", "pptx"].contains(ext) {
            let entries = try LocalProcess.run("/usr/bin/unzip", ["-Z1", url.path], limit: 500_000).components(separatedBy: .newlines)
            let selected = entries.filter { path in
                if ext == "docx" { return path == "word/document.xml" || path.hasPrefix("word/header") && path.hasSuffix(".xml") || path.hasPrefix("word/footer") && path.hasSuffix(".xml") }
                if ext == "pptx" { return path.hasPrefix("ppt/slides/slide") && path.hasSuffix(".xml") || path.hasPrefix("ppt/notesSlides/notesSlide") && path.hasSuffix(".xml") }
                return path == "xl/sharedStrings.xml" || path.hasPrefix("xl/worksheets/sheet") && path.hasSuffix(".xml")
            }.sorted()
            guard !selected.isEmpty, selected.count <= 100 else { throw SorterError.message("Office document is empty, encrypted, unsupported or too large.") }
            var text = ""
            for entry in selected {
                // Read selected ZIP members to stdout; never expand paths to disk.
                let xml = try LocalProcess.run("/usr/bin/unzip", ["-p", url.path, entry])
                guard !xml.localizedCaseInsensitiveContains("<!DOCTYPE"), !xml.localizedCaseInsensitiveContains("<!ENTITY") else { throw SorterError.message("Office XML contains unsupported entity declarations.") }
                let delegate = OfficeXMLText(); let parser = XMLParser(data: Data(xml.utf8))
                parser.shouldResolveExternalEntities = false; parser.delegate = delegate
                guard parser.parse() else { throw SorterError.message("Invalid Office XML.") }
                text += delegate.text + "\n"
                if text.count > 6000 { return bounded(text, note: "Local Office XML; text capped") }
            }
            return bounded(text, note: "Local Office XML (text only)")
        }
        throw SorterError.message("Unsupported document type.")
    }
    private static func bounded(_ text: String, note: String) -> ExtractedText {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return ExtractedText(text: String(clean.prefix(6000)), note: note, complete: clean.count <= 6000)
    }
    private static func pdf(_ url: URL) throws -> ExtractedText {
        guard let doc = PDFDocument(url: url), !doc.isLocked, doc.pageCount > 0 else { throw SorterError.message("PDF is unreadable, empty or password-protected.") }
        var text = ""; var usedOCR = false; var missingPage = false
        let count = min(doc.pageCount, 8)
        for index in 0..<count {
            guard let page = doc.page(at: index) else { missingPage = true; continue }
            let embedded = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if embedded.filter({ $0.isLetter || $0.isNumber }).count >= 30 { text += embedded + "\n" }
            else {
                usedOCR = true
                let rect = page.bounds(for: .mediaBox)
                guard rect.width > 0, rect.height > 0 else { missingPage = true; continue }
                let scale = min(2.5, 2200 / max(rect.width, rect.height))
                guard let context = CGContext(data: nil, width: max(1, Int(rect.width * scale)), height: max(1, Int(rect.height * scale)), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw SorterError.message("Cannot render PDF for local OCR.") }
                context.setFillColor(NSColor.white.cgColor); context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
                context.scaleBy(x: scale, y: scale); context.translateBy(x: -rect.minX, y: -rect.minY); page.draw(with: .mediaBox, to: context)
                guard let image = context.makeImage() else { throw SorterError.message("Cannot render scanned PDF.") }
                let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.usesLanguageCorrection = true; request.automaticallyDetectsLanguage = true
                try VNImageRequestHandler(cgImage: image).perform([request])
                let recognized = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                if recognized.isEmpty { missingPage = true }
                text += recognized + "\n"
            }
            if text.count > 6000 { break }
        }
        var result = bounded(text, note: usedOCR ? "PDFKit + local Vision OCR" : "PDFKit text")
        result.complete = result.complete && doc.pageCount <= count && !missingPage
        return result
    }
}
private final class OfficeXMLText: NSObject, XMLParserDelegate {
    var text = ""; var collecting = false
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        collecting = ["t", "v"].contains(elementName.components(separatedBy: ":").last ?? "")
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if collecting { text += string } }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if collecting { text += " " }; collecting = false
        if ["p", "row"].contains(elementName.components(separatedBy: ":").last ?? "") { text += "\n" }
    }
}
