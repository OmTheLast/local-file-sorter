import SwiftUI
import AppKit
import SorterCore

struct SetupView: View {
    @ObservedObject var model: AppModel
    @State var draft: SorterCore.Settings
    @State private var reviewExisting = true
    @State private var automatic = true
    @State private var validation: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set up document sorting").font(.title2.bold())
            Text("Choose where documents come from and where their category folders belong.").foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    folder("Source folder", source: true)
                    folder("Destination folder", source: false)
                    Text("Example: \(draft.destination.appendingPathComponent(draft.categories.first?.name ?? "Invoices").path)").font(.caption).foregroundStyle(.secondary)
                    Text("Category folders are created directly inside your destination. No extra Sorted Files folder is added.").font(.callout)
                    Divider()
                    Toggle("Review existing documents now", isOn: $reviewExisting)
                    Text("Includes unchanged documents previously moved by this app. You select and approve their destinations before anything moves.").font(.caption).foregroundStyle(.secondary)
                    Toggle("Automatically sort new downloads after review", isOn: $automatic)
                    Toggle("Only automate downloads from recognized browsers", isOn: $draft.browserDownloadsOnly)
                    Text("Recommended: terminal downloads and files with unknown origins stay untouched. Older documents can still be reviewed manually.").font(.caption).foregroundStyle(.secondary)
                    Toggle("Include photos and images", isOn: $draft.includeImages)
                    Toggle("Use on-device Apple Intelligence", isOn: $draft.useAI)
                    Text(model.modelStatus).font(.caption).foregroundStyle(.secondary)
                    Text("Model weights, datasets, code/config files, installers, compressed downloads and subfolders are excluded.").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Text("Categories").font(.headline)
                    ForEach($draft.categories) { $category in
                        HStack(alignment: .top) {
                            VStack {
                                TextField("Folder name", text: $category.name)
                                TextField("What belongs here", text: $category.detail)
                            }
                            if category.id == "review" { Text("Fallback").font(.caption).foregroundStyle(.orange) }
                            else { Button("Remove", systemImage: "minus.circle") { draft.categories.removeAll { $0.id == category.id } }.labelStyle(.iconOnly) }
                        }
                    }
                    Button("Add category") { draft.categories.append(Category(name: "New Category", detail: "Describe the documents that belong here.")) }.disabled(draft.categories.count >= 16)
                    Text("Uncertain documents go to \(draft.review.name), with their reason in History.").font(.caption)
                }.padding(.trailing, 8)
            }
            if let validation { Text(validation).foregroundStyle(.red).font(.callout) }
            if let error = model.error { Text(error).foregroundStyle(.red).font(.callout) }
            if model.busy { Text("Waiting for the current operation to stop…").font(.caption) }
            HStack {
                Button("Cancel", role: .cancel) { model.showSetup = false }
                Spacer()
                Button(reviewExisting ? "Save & review documents" : "Save settings") {
                    do { try draft.validate(); model.error = nil; model.finishSetup(draft, reviewExisting: reviewExisting, automatic: automatic) }
                    catch { validation = error.localizedDescription }
                }.buttonStyle(.borderedProminent).disabled(model.busy)
            }
        }.padding(24).frame(width: 660, height: 650)
    }
    private func folder(_ title: String, source: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button("Choose…") {
                    let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
                    panel.directoryURL = source ? draft.source : draft.destination
                    panel.prompt = "Choose folder"
                    if panel.runModal() == .OK, let url = panel.url {
                        if source { draft.source = url } else { draft.destination = url }
                    }
                }.disabled(model.demo)
            }
            Text((source ? draft.source : draft.destination).path).font(.callout).textSelection(.enabled)
        }
    }
}

struct MoveLocationsView: View {
    let record: MoveRecord
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(record.original.lastPathComponent).font(.title3.bold())
            location("Original location", record.original)
            location("Sorted location", record.destination)
            if let restored = record.undoDestination { location("Restored location", restored) }
            Text("Reason: \(record.reason)").font(.callout).textSelection(.enabled)
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 650)
    }
    private func location(_ title: String, _ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(url.path).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Show file in Finder") { model.reveal(url) }.disabled(!FileManager.default.fileExists(atPath: url.path))
                Button("Open containing folder") { model.openFolder(url.deletingLastPathComponent()) }.disabled(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
            }
            if !FileManager.default.fileExists(atPath: url.path) { Text("No file currently at this location.").font(.caption).foregroundStyle(.secondary) }
        }
    }
}
