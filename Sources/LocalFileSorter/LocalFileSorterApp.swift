import SwiftUI
import AppKit
import SorterCore

@main struct LocalFileSorterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window("Local File Sorter", id: "main") {
            ContentView(model: model).frame(minWidth: 980, minHeight: 680)
        }
        .defaultSize(width: 1140, height: 780)
        .commands { CommandGroup(replacing: .newItem) {} }
        MenuBarExtra(model.demo ? "File Sorter Samples" : "File Sorter", systemImage: model.automation ? "tray.and.arrow.down.fill" : "tray") {
            SorterMenu(model: model)
        }
    }
}
private enum Page: String, CaseIterable, Identifiable {
    case automation = "Downloads", history = "History", review = "Existing files", settings = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self { case .review: "tray.full"; case .history: "clock.arrow.circlepath"; case .automation: "bolt"; case .settings: "gearshape" }
    }
}
struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var page: Page = .automation
    @State private var categories = false
    @State private var confirmSort = false
    @State private var reviewOnly = false
    private var locked: Bool { model.busy || model.automation }
    private var reviewCount: Int { model.proposals.filter { $0.categoryID == "review" }.count }

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 205)
            Divider()
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(page.rawValue).font(.system(size: 28, weight: .semibold))
                        Text(subtitle).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if page == .review && (model.hasPreview || !model.proposals.isEmpty) {
                        Button("Scan again", systemImage: "arrow.clockwise") { model.scan() }.disabled(locked)
                    }
                }
                if model.demo {
                    Label("Sample files only — your Downloads are untouched", systemImage: "testtube.2")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Group {
                    switch page {
                    case .review: review
                    case .history: history
                    case .automation: automation
                    case .settings: settings
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Divider()
                HStack(alignment: .top, spacing: 9) {
                    if model.busy { ProgressView().controlSize(.small) }
                    else { Image(systemName: "info.circle").foregroundStyle(.secondary) }
                    Text(model.status).font(.callout).foregroundStyle(.secondary).lineLimit(3).textSelection(.enabled)
                }.frame(minHeight: 34, alignment: .topLeading)
            }.padding(26)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $categories) { CategoriesView(settings: model.settings) { model.saveSettings($0) } }
        .sheet(isPresented: $confirmSort) { sortConfirmation }
        .alert("Needs attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var subtitle: String {
        switch page {
        case .review: return "Optionally sort files that were already in your Downloads."
        case .history: return "See completed moves and restore files."
        case .automation: return "Finished downloads go straight into the right folder."
        case .settings: return "Choose your folders and organize your categories."
        }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 25) {
            Label("File Sorter", systemImage: "tray.2.fill").font(.title3.weight(.semibold)).padding(.horizontal, 10).padding(.top, 12)
            VStack(spacing: 5) {
                ForEach(Page.allCases) { item in
                    Button { page = item } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.icon).frame(width: 20)
                            Text(item.rawValue)
                            Spacer(minLength: 0)
                        }.font(.callout.weight(page == item ? .semibold : .regular)).padding(11)
                            .contentShape(Rectangle())
                            .background(page == item ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(page == item ? Color.accentColor : .primary)
                    }.buttonStyle(.plain)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Label(model.automation ? "Automatic sorting is on" : "Automatic sorting is off", systemImage: model.automation ? "bolt.circle.fill" : "pause.circle")
                    .font(.caption).foregroundStyle(model.automation ? Color.green : .secondary)
                if model.automation { Button("Pause sorting") { model.pause() } }
                Divider()
                Label("Everything stays on this Mac", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 10)
        }.padding(14).background(.quaternary.opacity(0.35))
    }
    private var folderRoute: some View {
        HStack(spacing: 18) {
            routeLabel("FROM", model.settings.source)
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            routeLabel("SORT INTO", model.settings.destination)
            Spacer()
            Button("Change…") { page = .settings }
        }.padding(16).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }
    private func routeLabel(_ label: String, _ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Label(url.lastPathComponent, systemImage: "folder").font(.callout.weight(.medium)).help(url.path)
        }
    }
    private var review: some View {
        VStack(alignment: .leading, spacing: 16) {
            folderRoute
            HStack(spacing: 12) {
                step("1", "Scan", active: !model.hasPreview)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                step("2", "Review", active: model.hasPreview && model.selectedCount == 0)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                step("3", "Sort", active: model.hasPreview && model.selectedCount > 0)
            }
            if model.scanning {
                empty("Scanning your files", icon: "doc.text.magnifyingglass", detail: "Waiting for downloads to finish, then reading documents on this Mac.") {
                    Button("Cancel scan") { model.cancelScan() }
                }
            } else if !model.hasPreview && model.proposals.isEmpty {
                empty("Start with a preview", icon: "tray.and.arrow.down", detail: "Scan \(model.settings.source.lastPathComponent) to see suggested folders. Scanning never moves files.") {
                    Button("Scan files", systemImage: "magnifyingglass") { model.scan() }.buttonStyle(.borderedProminent).controlSize(.large).disabled(locked || !model.canOperate)
                }
            } else {
                HStack {
                    Picker("Show files", selection: $reviewOnly) {
                        Text("All files (\(model.proposals.count))").tag(false)
                        Text("Needs review (\(reviewCount))").tag(true)
                    }.pickerStyle(.segmented).frame(maxWidth: 345)
                    Spacer()
                    Button("Select all") {
                        for i in model.proposals.indices where !reviewOnly || model.proposals[i].categoryID == "review" { model.proposals[i].approved = true }
                    }.disabled(locked || model.proposals.isEmpty)
                    Button("Clear") { model.selectAll(false) }.disabled(locked || model.selectedCount == 0)
                }
                if model.proposals.isEmpty || reviewOnly && reviewCount == 0 {
                    empty(reviewOnly ? "No files need extra review" : "All caught up", icon: "checkmark.circle", detail: reviewOnly ? "Switch to All files to see other suggestions." : "Scan again when you add more files. Completed moves are in History.") { EmptyView() }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(model.proposals.filter { !reviewOnly || $0.categoryID == "review" }) { proposal in
                                ProposalRow(proposal: proposal, categories: model.settings.categories, locked: locked,
                                    selected: Binding(get: { model.proposals.first { $0.id == proposal.id }?.approved ?? false }, set: { value in if let i = model.proposals.firstIndex(where: { $0.id == proposal.id }) { model.proposals[i].approved = value } }),
                                    changeCategory: { id in if let i = model.proposals.firstIndex(where: { $0.id == proposal.id }) { model.changeCategory(i, to: id) } })
                            }
                        }
                    }
                }
                if !model.skipped.isEmpty {
                    DisclosureGroup("\(model.skipped.count) skipped — left in the source folder") {
                        ScrollView { VStack(alignment: .leading, spacing: 6) { ForEach(model.skipped, id: \.self) { Text($0).font(.caption).textSelection(.enabled) } }.frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 110)
                    }.font(.callout).foregroundStyle(.secondary)
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.selectedCount == 0 ? "Select files to sort" : "\(model.selectedCount) selected").font(.headline)
                        Text("Nothing moves until you confirm.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Sort selected…", systemImage: "folder.badge.plus") { confirmSort = true }
                        .buttonStyle(.borderedProminent).controlSize(.large).disabled(model.selectedCount == 0 || locked || !model.hasPreview)
                }
            }
        }
    }
    private func step(_ number: String, _ title: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Text(number).font(.caption.weight(.semibold)).frame(width: 23, height: 23).background(active ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08), in: Circle())
            Text(title).font(.callout.weight(active ? .semibold : .regular))
        }.foregroundStyle(active ? Color.accentColor : .secondary)
    }
    private func empty<Actions: View>(_ title: String, icon: String, detail: String, @ViewBuilder actions: () -> Actions) -> some View {
        VStack(spacing: 13) {
            Image(systemName: icon).font(.system(size: 37, weight: .light)).foregroundStyle(.secondary)
            Text(title).font(.title2.weight(.semibold))
            Text(detail).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 380)
            actions().padding(.top, 5)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var sortConfirmation: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Move \(model.selectedCount) \(model.selectedCount == 1 ? "file" : "files")?").font(.title2.weight(.semibold))
            Text("Review these destinations, then approve the move. Existing files are never replaced. You can undo moves from History.").foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(model.proposals.filter(\.approved)) { proposal in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(proposal.source.lastPathComponent).font(.headline)
                            Text(proposal.destination.path).font(.caption).textSelection(.enabled)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Divider()
                    }
                }
            }.frame(maxHeight: 300)
            HStack {
                Button("Cancel", role: .cancel) { confirmSort = false }
                Spacer()
                Button("Approve & sort") {
                    confirmSort = false; model.approvePreview(); model.sortSelected()
                }.buttonStyle(.borderedProminent).disabled(model.selectedCount == 0 || locked || !model.hasPreview)
            }
        }.padding(26).frame(width: 600)
    }
    private var history: some View {
        Group {
            if model.history.isEmpty {
                empty("No files moved yet", icon: "clock.arrow.circlepath", detail: "After you sort files, their history and Undo buttons appear here.") { EmptyView() }
            } else {
                ScrollView { LazyVStack(spacing: 12) {
                    ForEach(model.history) { record in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: record.state == "undone" ? "arrow.uturn.backward.circle" : "doc")
                                Text(record.original.lastPathComponent).font(.headline)
                                Spacer()
                                Text(historyState(record.state)).font(.caption).foregroundStyle(.secondary)
                                Button("Undo move") { model.undo(record) }.disabled(record.state != "moved" || model.busy)
                            }
                            Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            if let note = record.note { Text(note).font(.callout).foregroundStyle(.secondary) }
                            DisclosureGroup("Locations") {
                                VStack(alignment: .leading, spacing: 8) {
                                    pathLine("Original location", record.original)
                                    pathLine("Sorted location", record.destination)
                                    if let restored = record.undoDestination { pathLine("Restored to", restored) }
                                }.padding(.top, 8)
                            }.font(.caption)
                        }.padding(16).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    }
                } }
            }
        }
    }
    private var automation: some View {
        VStack(alignment: .leading, spacing: 24) {
            folderRoute
            HStack(alignment: .top, spacing: 18) {
                Image(systemName: model.automation ? "checkmark.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 44)).foregroundStyle(model.automation ? Color.green : .secondary)
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.automation ? "Your downloads sort themselves" : "Automatic sorting is paused")
                        .font(.title2.weight(.semibold))
                    Text(model.automation ? "Download a file as usual. Once it finishes, it moves into Sorted Files automatically. No scan or approval needed." : "Resume to automatically sort new downloads. Files that were present at first setup stay untouched.")
                        .foregroundStyle(.secondary)
                    Button(model.automation ? "Pause sorting" : "Resume automatic sorting") {
                        if model.automation { model.pause() } else { model.enableAutomation() }
                    }.controlSize(.large).disabled(!model.automation && (model.busy || !model.canOperate))
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 14) {
                Label("Documents are classified on this Mac with Apple Intelligence.", systemImage: "cpu")
                Label("Uncertain or unreadable files go into Needs Review automatically.", systemImage: "questionmark.folder")
                Label("Original filenames stay the same. Undo is available in History.", systemImage: "arrow.uturn.backward")
                Label("Close this window to keep sorting in the menu bar.", systemImage: "menubar.rectangle")
            }.font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("Open Sorted Files", systemImage: "folder") { model.reveal(model.settings.destination) }
                Button("View history") { page = .history }
            }
            Text(model.demo ? "This sample app watches only its temporary folder. Your actual Downloads are untouched." : "Pause is remembered across restarts. Quit stops sorting until the app is opened again or you log in.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Folders").font(.title3.weight(.semibold))
                    settingsFolder("Scan files in", model.settings.source, source: true)
                    Divider()
                    settingsFolder("Put sorted files in", model.settings.destination, source: false)
                    Text(model.demo ? "Sample mode uses temporary folders. Open the main app to choose your own folders." : "Only files directly inside the source folder are scanned. Subfolders are left alone.").font(.caption).foregroundStyle(.secondary)
                }.padding(20).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Categories").font(.title3.weight(.semibold))
                        Text(model.settings.categories.map(\.name).joined(separator: " · ")).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit categories…") { categories = true }.disabled(locked)
                }
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Use Apple Intelligence for documents", isOn: Binding(get: { model.settings.useAI }, set: { var s = model.settings; s.useAI = $0; model.saveSettings(s) })).disabled(locked)
                    Text("Classifies documents on this Mac. When AI is off or unavailable, documents go to Needs Review; file-type rules still work.").font(.callout).foregroundStyle(.secondary)
                    Label(model.modelStatus, systemImage: "cpu").font(.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: 720, alignment: .leading)
        }
    }
    private func settingsFolder(_ label: String, _ url: URL, source: Bool) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(label).font(.headline)
                Text(url.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Spacer()
            Button("Choose…") { model.selectFolder(source: source) }.disabled(locked || model.demo)
        }
    }
    private func historyState(_ state: String) -> String {
        ["moved": "Sorted", "undone": "Restored", "cancelled": "Not moved", "pending": "Checking move", "undoPending": "Checking restore", "attention": "Needs attention"][state] ?? state
    }
}
private func pathLine(_ label: String, _ url: URL) -> some View {
    VStack(alignment: .leading, spacing: 3) {
        Text(label).font(.caption.weight(.semibold))
        Text(url.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
    }.frame(maxWidth: .infinity, alignment: .leading)
}
private struct ProposalRow: View {
    let proposal: Proposal
    let categories: [SorterCore.Category]
    let locked: Bool
    @Binding var selected: Bool
    var changeCategory: (String) -> Void
    private var category: String { categories.first { $0.id == proposal.categoryID }?.name ?? "Needs Review" }
    private var collision: Bool { proposal.destination.deletingLastPathComponent().lastPathComponent != category }
    private var explanation: String {
        if proposal.method == "Fallback" { return "Couldn’t classify this file. Choose a folder or scan again." }
        if proposal.method == "On-device AI" { return "Document content suggests \(category)." }
        return proposal.reason
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 13) {
                Toggle("Select \(proposal.source.lastPathComponent)", isOn: $selected).labelsHidden().disabled(locked).padding(.top, 3)
                VStack(alignment: .leading, spacing: 5) {
                    Text(proposal.source.lastPathComponent).font(.headline).lineLimit(1).truncationMode(.middle).help(proposal.source.path)
                    Text(explanation).font(.callout).foregroundStyle(proposal.categoryID == "review" ? Color.orange : .secondary).lineLimit(2)
                    if collision { Label("Name already exists — a separate folder keeps both files", systemImage: "doc.on.doc").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 8)
                VStack(alignment: .leading, spacing: 4) {
                    Text("MOVE TO").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Picker("Move \(proposal.source.lastPathComponent) to", selection: Binding(get: { proposal.categoryID }, set: changeCategory)) {
                        ForEach(categories) { Text($0.name).tag($0.id) }
                    }.labelsHidden().frame(width: 160).disabled(locked)
                }
            }
            DisclosureGroup("Details & full paths") {
                VStack(alignment: .leading, spacing: 10) {
                    pathLine("Current location", proposal.source)
                    pathLine("Proposed destination", proposal.destination)
                    Text(proposal.reason).font(.callout).textSelection(.enabled)
                    Text(proposal.method).font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 8)
            }.font(.caption).foregroundStyle(.secondary).padding(.leading, 30)
        }.padding(15).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
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
