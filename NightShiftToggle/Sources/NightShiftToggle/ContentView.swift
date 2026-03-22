import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var excludeList: ExcludeListManager
    @EnvironmentObject var focusMonitor: FocusMonitor

    @State private var showingAppPicker = false
    @State private var installedApps: [AppInfo] = []

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusSection
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Exclude list
            excludeListSection
        }
        .frame(minWidth: 480, minHeight: 400)
        .onAppear {
            // Load installed apps in background
            DispatchQueue.global(qos: .userInitiated).async {
                let apps = InstalledAppsFinder.findAll()
                DispatchQueue.main.async {
                    self.installedApps = apps
                }
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerSheet(
                installedApps: installedApps,
                excludeList: excludeList,
                isPresented: $showingAppPicker
            )
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

                Text("Night Shift will be disabled when these apps are in focus")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { showingAppPicker = true }) {
                    Image(systemName: "plus")
                }
                .help("Add application")
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
                    Text("Click + to add apps that should disable Night Shift when in focus")
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

    @State private var searchText = ""

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
        .frame(width: 500, height: 450)
    }
}
