import SwiftUI
import AppKit
import SorterCore

@main struct LocalFileSorterApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup("Local File Sorter") { ContentView(model: model).frame(minWidth: 1080, minHeight: 720) }
            .defaultSize(width: 1240, height: 820)
            .commands { CommandGroup(replacing: .newItem) {} }
    }
}
struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var categories = false
    @State private var confirmSort = false
    @State private var confirmAutomation = false
    @State private var tab = "preview"
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 265)
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                header
                if model.demo {
                    Label("TEMPORARY SAMPLE FILES · Your Downloads are untouched", systemImage: "testtube.2")
                        .font(.callout.weight(.medium)).foregroundStyle(.indigo).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                HStack {
                    Picker("View", selection: $tab) {
                        Text("Preview (\(model.proposals.count))").tag("preview")
                        Text("History (\(model.history.count))").tag("history")
                        Text("Skipped (\(model.skipped.count))").tag("skipped")
                    }.pickerStyle(.segmented).frame(maxWidth: 530)
                    Spacer()
                    if model.busy { ProgressView().controlSize(.small) }
                }
                if tab == "preview" { preview }
                else if tab == "history" { history }
                else { skipped }
                Divider()
                Text(model.status).font(.callout).foregroundStyle(.secondary).textSelection(.enabled).frame(minHeight: 36, alignment: .topLeading)
            }.padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task { if model.demo && !model.hasPreview && !model.busy { model.scan() } }
        .sheet(isPresented: $categories) { CategoriesView(settings: model.settings) { model.saveSettings($0) } }
        .alert("Sort \(model.selectedCount) selected files?", isPresented: $confirmSort) {
            Button("Cancel", role: .cancel) {}
            Button("Sort selected files") { model.sortSelected() }
        } message: { Text("Files will move to the destinations in the preview. Existing files will never be replaced. You can undo completed moves from History.") }
        .alert("Enable automatic sorting for new arrivals?", isPresented: $confirmAutomation) {
            Button("Cancel", role: .cancel) {}
            Button("Enable automation") { model.enableAutomation() }
        } message: { Text("Existing source files are excluded. New files wait for a quiet period and an open-writer check. \(model.allowAIAutomation ? "Rules and on-device AI may move files." : "Only obvious rule matches move automatically; AI suggestions stay in Preview.") Needs Review stays for your approval. Automation stops when you pause or quit; every launch starts paused.") }
        .alert("Needs attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label("Local File Sorter", systemImage: "tray.2.fill").font(.title3.weight(.semibold)).padding(.top, 12)
            Label(model.automation ? "Automation active" : "Preview mode", systemImage: model.automation ? "bolt.circle.fill" : "eye.circle.fill")
                .foregroundStyle(model.automation ? .green : .indigo).font(.headline)
            folder("SOURCE", url: model.settings.source, source: true)
            folder("DESTINATION", url: model.settings.destination, source: false)
            Divider()
            HStack { Text("CATEGORIES").font(.caption.weight(.semibold)).foregroundStyle(.secondary); Spacer(); Button("Edit") { categories = true }.disabled(model.busy || model.automation) }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(model.settings.categories) { category in
                    Label(category.name, systemImage: icon(category.id)).font(.callout)
                }
            }
            Spacer()
            Toggle("Use on-device AI", isOn: Binding(get: { model.settings.useAI }, set: { var s = model.settings; s.useAI = $0; model.saveSettings(s) })).disabled(model.busy || model.automation)
            Text(model.modelStatus).font(.caption).foregroundStyle(.secondary)
            Label("Local processing only", systemImage: "lock.shield").font(.caption.weight(.medium))
            Text("Top-level files only. No launch agent. Automation runs while this app is open.").font(.caption).foregroundStyle(.secondary)
        }.padding(22).background(.quaternary.opacity(0.35))
    }
    private func folder(_ label: String, url: URL, source: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(url.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")).font(.callout).lineLimit(4).textSelection(.enabled)
            Button("Choose folder…") { model.selectFolder(source: source) }.disabled(model.busy || model.automation || model.demo)
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A place for every file.").font(.system(size: 30, weight: .semibold))
            Text("Review destinations before sorting. Keep the original filename, and undo any unchanged file.").foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button { model.scan() } label: { Label("Scan preview", systemImage: "arrow.clockwise") }.disabled(model.busy || !model.canOperate || model.automation)
                Button(model.previewApproved ? "Preview approved" : "Approve preview") { model.approvePreview() }
                    .disabled(!model.hasPreview || model.previewApproved || model.busy || model.automation)
                Spacer()
                if model.automation {
                    Button("Pause automation", systemImage: "pause.fill") { model.pause() }.tint(.orange)
                } else {
                    Button("Enable automation…", systemImage: "bolt") { confirmAutomation = true }.disabled(!model.previewApproved || model.busy)
                }
            }
            Toggle("Allow AI suggestions to move automatically after enabling", isOn: $model.allowAIAutomation)
                .font(.caption).disabled(model.automation || model.busy || !model.settings.useAI)
        }
    }
    private var preview: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Select all") { model.selectAll(true) }.disabled(model.busy || model.automation)
                Button("Clear") { model.selectAll(false) }.disabled(model.busy || model.automation)
                Spacer()
                Button("Sort selected (\(model.selectedCount))…") { confirmSort = true }
                    .buttonStyle(.borderedProminent).disabled(model.selectedCount == 0 || !model.previewApproved || model.busy || model.automation)
            }
            if model.proposals.isEmpty {
                ContentUnavailableView(model.busy ? "Preparing your preview" : "Nothing queued", systemImage: "tray", description: Text(model.busy ? "Waiting for stable files and classifying locally. You can keep this window open." : "Scan to see each file’s proposed destination. No files move during a scan."))
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(model.proposals.enumerated()), id: \.element.id) { index, p in
                            HStack(alignment: .top, spacing: 12) {
                                Toggle("Approve \(p.source.lastPathComponent)", isOn: Binding(get: { model.proposals.indices.contains(index) ? model.proposals[index].approved : false }, set: { if model.proposals.indices.contains(index) { model.proposals[index].approved = $0 } })).labelsHidden().disabled(model.busy || model.automation)
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text(p.source.lastPathComponent).font(.headline).textSelection(.enabled)
                                        Spacer()
                                        Text(p.method).font(.caption).foregroundStyle(.secondary)
                                        Picker("Category", selection: Binding(get: { p.categoryID }, set: { model.changeCategory(index, to: $0) })) { ForEach(model.settings.categories) { Text($0.name).tag($0.id) } }.labelsHidden().frame(width: 145).disabled(model.busy || model.automation)
                                    }
                                    Text("From  \(p.source.path)").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                    Text("To       \(p.destination.path)").font(.caption).textSelection(.enabled)
                                    Text(p.reason).font(.callout).foregroundStyle(p.categoryID == "review" ? Color.orange : Color.secondary).textSelection(.enabled)
                                }
                            }.padding(14).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }
    private var history: some View {
        Group {
            if model.history.isEmpty {
                ContentUnavailableView("No moves yet", systemImage: "clock.arrow.circlepath", description: Text("Completed moves and safe undo actions appear here.")).frame(maxHeight: .infinity)
            } else {
                ScrollView { LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(model.history) { record in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(record.original.lastPathComponent).font(.headline)
                                Text(record.state).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(record.date, style: .date).font(.caption)
                                Button("Undo") { model.undo(record) }.disabled(record.state != "moved" || model.busy)
                            }
                            Text("Original  \(record.original.path)").font(.caption).textSelection(.enabled)
                            Text("Sorted    \(record.destination.path)").font(.caption).textSelection(.enabled)
                            if let restored = record.undoDestination { Text("Restored  \(restored.path)").font(.caption).textSelection(.enabled) }
                            if let note = record.note { Text(note).font(.caption).foregroundStyle(.secondary) }
                        }.padding(14).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    }
                } }
            }
        }
    }
    private var skipped: some View {
        ScrollView { VStack(alignment: .leading, spacing: 12) {
            Text("Skipped files stay in the source folder. Subfolders are not scanned.").foregroundStyle(.secondary)
            ForEach(model.skipped, id: \.self) { Text($0).font(.callout).textSelection(.enabled) }
        }.frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: .infinity)
    }
    private func icon(_ id: String) -> String {
        ["invoices": "doc.text", "work": "briefcase", "research": "text.book.closed", "images": "photo", "installers": "shippingbox", "archives": "archivebox", "review": "questionmark.folder"][id] ?? "folder"
    }
}
struct CategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @State var settings: SorterCore.Settings
    var save: (SorterCore.Settings) -> Void
    @State private var validation: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Sorting categories").font(.title2.weight(.semibold))
            Text("Names become folders. Descriptions guide content classification. Keep a review category for files that do not clearly fit.").foregroundStyle(.secondary)
            ScrollView {
                ForEach($settings.categories) { $category in
                    HStack(alignment: .top) {
                        TextField("Folder name", text: $category.name).frame(width: 155)
                        TextField("What belongs here", text: $category.detail, axis: .vertical).lineLimit(2...3)
                        Button { settings.categories.removeAll { $0.id == category.id } } label: { Image(systemName: "minus.circle") }.disabled(category.id == "review")
                    }.padding(.vertical, 4)
                }
            }
            if let validation { Text(validation).foregroundStyle(.red).font(.caption) }
            HStack {
                Button("Add category") { settings.categories.append(Category(name: "New Category", detail: "Describe which documents belong here.")) }.disabled(settings.categories.count >= 16)
                Spacer(); Button("Cancel") { dismiss() }
                Button("Save categories") {
                    do { try settings.validate(); save(settings); dismiss() } catch { validation = error.localizedDescription }
                }.buttonStyle(.borderedProminent)
            }
        }.padding(26).frame(width: 740, height: 520)
    }
}
