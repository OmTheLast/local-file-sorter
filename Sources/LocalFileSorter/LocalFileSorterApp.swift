import SwiftUI
import AppKit
import SorterCore

@main struct LocalFileSorterApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup("Local File Sorter") {
            ContentView(model: model).frame(minWidth: 980, minHeight: 680)
        }
        .defaultSize(width: 1140, height: 780)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}
private enum Page: String, CaseIterable, Identifiable {
    case review = "Review files", history = "History", automation = "Automatic sorting", settings = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self { case .review: "tray.full"; case .history: "clock.arrow.circlepath"; case .automation: "bolt"; case .settings: "gearshape" }
    }
}
struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var page: Page = .review
    @State private var categories = false
    @State private var confirmSort = false
    @State private var confirmAutomation = false
    @State private var reviewedAutomation = false
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
        .task { if model.demo && !model.hasPreview && !model.busy { model.scan() } }
        .onChange(of: model.hasPreview) { _, _ in reviewedAutomation = false }
        .sheet(isPresented: $categories) { CategoriesView(settings: model.settings) { model.saveSettings($0) } }
        .sheet(isPresented: $confirmSort) { sortConfirmation }
        .alert("Turn on automatic sorting?", isPresented: $confirmAutomation) {
            Button("Cancel", role: .cancel) {}
            Button("Turn on") { model.approvePreview(); model.enableAutomation() }
        } message: {
            Text("New arrivals in \(model.settings.source.lastPathComponent) will be sorted while this app is open. Existing files and Needs Review items stay for you to review. \(model.allowAIAutomation ? "Document suggestions may also move automatically." : "Document suggestions wait for your approval.")")
        }
        .alert("Needs attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var subtitle: String {
        switch page {
        case .review: return "Choose which files to move and where they belong."
        case .history: return "See completed moves and restore files."
        case .automation: return "Choose how to handle new files after you review a preview."
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label(model.automation ? "Automatic sorting is on" : "Automatic sorting is off", systemImage: model.automation ? "bolt.circle.fill" : "pause.circle")
                    .font(.title2.weight(.semibold)).foregroundStyle(model.automation ? Color.green : .primary)
                Text("New files in \(model.settings.source.lastPathComponent) can be sorted while this app is open. Files already there remain yours to review.").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    Text("What should move automatically?").font(.headline)
                    Picker("Automatic sorting scope", selection: $model.allowAIAutomation) {
                        Text("Images, installers and archives only").tag(false)
                        Text("Also include AI document suggestions").tag(true)
                    }.pickerStyle(.radioGroup).disabled(locked || !model.settings.useAI)
                    Text("Needs Review files always wait for you. Document suggestions use Apple Intelligence on this Mac.").font(.callout).foregroundStyle(.secondary)
                    if !model.settings.useAI { Text("Turn on Apple Intelligence in Settings to include document suggestions.").font(.caption).foregroundStyle(.secondary) }
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                if model.automation {
                    Button("Pause automatic sorting", systemImage: "pause") { model.pause() }.controlSize(.large)
                } else if !model.hasPreview {
                    Label("Start by scanning and reviewing your files.", systemImage: "1.circle").font(.headline)
                    Button("Go to Review files") { page = .review }
                } else {
                    Toggle("I have reviewed the current preview", isOn: $reviewedAutomation).disabled(model.busy)
                    Button("Turn on automatic sorting…", systemImage: "bolt") { confirmAutomation = true }
                        .buttonStyle(.borderedProminent).controlSize(.large).disabled(!reviewedAutomation || model.busy)
                }
                Text("Downloads must finish before they move. You can pause anytime, and automatic sorting is always off when you reopen the app.").font(.callout).foregroundStyle(.secondary)
            }.frame(maxWidth: 650, alignment: .leading)
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
                    Text("Reads document text on this Mac to suggest a category. You can still sort by file type and choose folders manually when it is off.").font(.callout).foregroundStyle(.secondary)
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
