import Foundation
import CoreServices

/// Eligibility is decided before extraction or AI. Unrelated assets never become fallback moves.
public enum DocumentPolicy {
    public static let documents: Set<String> = ["pdf", "doc", "docx", "rtf", "odt", "xlsx", "pptx", "txt", "md", "markdown"]
    public static let images: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "gif", "webp"]
    public static let browsers: Set<String> = ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "com.brave.Browser", "com.microsoft.edgemac", "company.thebrowser.Browser", "com.operasoftware.Opera"]
    public static func skipReason(_ url: URL, settings: Settings, automatic: Bool) -> String? {
        let ext = url.pathExtension.lowercased()
        guard documents.contains(ext) || settings.includeImages && images.contains(ext) else {
            return "Outside document scope (models, datasets, code, installers and compressed downloads stay here)"
        }
        if automatic && settings.browserDownloadsOnly {
            guard let values = try? url.resourceValues(forKeys: [.quarantinePropertiesKey]),
                  let agent = values.quarantineProperties?[kLSQuarantineAgentBundleIdentifierKey as String] as? String,
                  browsers.contains(agent) else {
                return "Download origin is not a recognized browser; left untouched"
            }
        }
        return nil
    }
}
