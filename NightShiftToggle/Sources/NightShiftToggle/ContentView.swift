import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var excludeList: ExcludeListManager
    @EnvironmentObject var focusMonitor: FocusMonitor

    @State private var installedApps: [AppInfo] = []
    @State private var searchText = ""
    @State private var selectedTab = 0
    // 2.5 app rows as default height (~36pt per row + padding)
    private static let defaultExcludeListHeight: CGFloat = 98
    @State private var excludeListHeight: CGFloat = defaultExcludeListHeight

    private var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return installedApps
        }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusSection
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Exclude list (pinned at top)
            excludeListSection

            Divider()

            // Tab picker: Applications / Folders to Search
            Picker("", selection: $selectedTab) {
                Text("Applications").tag(0)
                Text("Folders to Search").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Tab content
            if selectedTab == 0 {
                appListSection
            } else {
                foldersSection
            }
        }
        .frame(minWidth: 520, minHeight: 550)
        .onAppear { reloadApps() }
    }

    private func reloadApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = InstalledAppsFinder.findAll(extraPaths: excludeList.additionalAppFolders)
            DispatchQueue.main.async {
                self.installedApps = apps
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(focusMonitor.nightShiftOverridden ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.headline)
                }

                if !focusMonitor.currentAppName.isEmpty {
                    Text("Active app: \(focusMonitor.currentAppName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
    }

    private var statusText: String {
        if focusMonitor.nightShiftOverridden {
            return "Night Shift disabled (excluded app in focus)"
        } else {
            return "Night Shift following normal schedule"
        }
    }

    // MARK: - Exclude List Section

    private var excludeListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Exclude List")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Text("Night Shift disabled when these apps are in focus")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            if !excludeList.excludedBundleIDs.isEmpty {
                List {
                    ForEach(excludeList.excludedBundleIDs, id: \.self) { bundleID in
                        ExcludedAppRow(
                            bundleID: bundleID,
                            installedApps: installedApps,
                            onRemove: { excludeList.remove(bundleID: bundleID) }
                        )
                    }
                }
                .frame(height: excludeListHeight)

                // Drag handle to resize exclude list
                ExcludeListResizeHandle(height: $excludeListHeight)
            } else {
                // Empty state — same height as populated list so content below doesn't shift
                VStack {
                    Spacer()
                    Text("No apps excluded yet — add apps below")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: Self.defaultExcludeListHeight)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Applications Section

    private var appListSection: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search applications...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Manually add option — always available
            Button(action: browseForApp) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 24, height: 24)
                        .foregroundColor(.secondary)

                    Text("Manually Add Application")
                        .fontWeight(.medium)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            // App list / loading / empty
            if installedApps.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    ProgressView("Loading applications...")
                    Text("Applications are indexed the first time the app is opened and when new folders are added. This may take a few minutes.\nIf you don't want to wait, you can use the Manually Add Application option in the meantime.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredApps.isEmpty {
                VStack {
                    Spacer()
                    Text("No matching applications")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredApps) { app in
                        let isExcluded = excludeList.contains(bundleID: app.bundleID)
                        HStack {
                            Image(nsImage: InstalledAppsFinder.icon(for: app))
                                .resizable()
                                .frame(width: 24, height: 24)
                                .opacity(isExcluded ? 0.4 : 1)

                            VStack(alignment: .leading) {
                                Text(app.name)
                                    .fontWeight(.medium)
                                Text(app.bundleID)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .opacity(isExcluded ? 0.4 : 1)

                            Spacer()

                            if isExcluded {
                                Button("Added") {}
                                    .buttonStyle(.bordered)
                                    .disabled(true)
                            } else {
                                Button("Add") {
                                    excludeList.add(bundleID: app.bundleID)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    // MARK: - Folders Section

    private var foldersSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Additional application folders are scanned for .app bundles.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: addFolder) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            List {
                Section("Default Paths") {
                    ForEach(InstalledAppsFinder.defaultSearchPaths, id: \.self) { path in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                            Text(path)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("built-in")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                if !excludeList.additionalAppFolders.isEmpty {
                    Section("Custom Paths") {
                        ForEach(excludeList.additionalAppFolders, id: \.self) { path in
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.accentColor)
                                Text(path)
                                Spacer()
                                Button(action: {
                                    excludeList.removeFolder(path)
                                    reloadApps()
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.title = "Select an Application"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            if let app = InstalledAppsFinder.appInfo(from: url) {
                excludeList.add(bundleID: app.bundleID)
            }
        }
        reloadApps()
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Applications Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        excludeList.addFolder(url.path)
        reloadApps()
    }
}

// MARK: - Exclude List Resize Handle

struct ExcludeListResizeHandle: View {
    @Binding var height: CGFloat
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.secondary.opacity(isDragging ? 0.6 : 0.3))
                    .frame(width: 36, height: 3)
            )
            .contentShape(Rectangle().size(width: 520, height: 12).offset(CGSize(width: 0, height: -4)))
            .cursor(.resizeUpDown)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        isDragging = true
                        let newHeight = height + value.translation.height
                        height = max(44, min(newHeight, 400))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - Excluded App Row

struct ExcludedAppRow: View {
    let bundleID: String
    let installedApps: [AppInfo]
    let onRemove: () -> Void

    var body: some View {
        HStack {
            if let app = installedApps.first(where: { $0.bundleID == bundleID }) {
                Image(nsImage: InstalledAppsFinder.icon(for: app))
                    .resizable()
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading) {
                    Text(app.name)
                        .fontWeight(.medium)
                    Text(bundleID)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Image(systemName: "app")
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading) {
                    Text(bundleID)
                        .fontWeight(.medium)
                }
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Remove from exclude list")
        }
        .padding(.vertical, 2)
    }
}
