import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var excludeList: ExcludeListManager
    @EnvironmentObject var focusMonitor: FocusMonitor

    @State private var showingAppPicker = false
    @State private var installedApps: [AppInfo] = []

    var body: some View {
        VStack(spacing: 0) {
            statusSection
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            excludeListSection
        }
        .frame(minWidth: 520, minHeight: 450)
        .onAppear { reloadApps() }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerSheet(
                installedApps: installedApps,
                excludeList: excludeList,
                isPresented: $showingAppPicker,
                onAppsChanged: { reloadApps() }
            )
        }
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

                Spacer()

                Button(action: browseForApp) {
                    Image(systemName: "doc.badge.plus")
                }
                .help("Browse for an .app file")

                Button(action: { showingAppPicker = true }) {
                    Image(systemName: "plus")
                }
                .help("Add from application list")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            if excludeList.excludedBundleIDs.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "moon.stars")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No apps in exclude list")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Click + to browse apps, or the file icon to locate an .app directly")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(excludeList.excludedBundleIDs, id: \.self) { bundleID in
                        ExcludedAppRow(
                            bundleID: bundleID,
                            installedApps: installedApps,
                            onRemove: { excludeList.remove(bundleID: bundleID) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Browse for .app via Finder

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
                // Add to installed apps list if not already there
                if !installedApps.contains(where: { $0.bundleID == app.bundleID }) {
                    installedApps.append(app)
                    installedApps.sort()
                }
            }
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

// MARK: - App Picker Sheet

struct AppPickerSheet: View {
    let installedApps: [AppInfo]
    @ObservedObject var excludeList: ExcludeListManager
    @Binding var isPresented: Bool
    var onAppsChanged: () -> Void

    @State private var searchText = ""
    @State private var selectedTab = 0

    private var filteredApps: [AppInfo] {
        let available = installedApps.filter { !excludeList.contains(bundleID: $0.bundleID) }
        if searchText.isEmpty {
            return available
        }
        return available.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Application")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Tab picker: Applications / Search Folders
            Picker("", selection: $selectedTab) {
                Text("Applications").tag(0)
                Text("Search Folders").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if selectedTab == 0 {
                appListTab
            } else {
                foldersTab
            }
        }
        .frame(width: 520, height: 480)
    }

    // MARK: - Applications Tab

    private var appListTab: some View {
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

            if installedApps.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Loading applications...")
                    Spacer()
                }
            } else if filteredApps.isEmpty {
                VStack {
                    Spacer()
                    Text("No matching applications")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(filteredApps) { app in
                    HStack {
                        Image(nsImage: InstalledAppsFinder.icon(for: app))
                            .resizable()
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading) {
                            Text(app.name)
                                .fontWeight(.medium)
                            Text(app.bundleID)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Add") {
                            excludeList.add(bundleID: app.bundleID)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Search Folders Tab

    private var foldersTab: some View {
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

            // Default paths (non-removable)
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
                                    onAppsChanged()
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

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Applications Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        excludeList.addFolder(url.path)
        onAppsChanged()
    }
}
