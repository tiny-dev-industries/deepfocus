import SwiftUI

struct AppPickerView: View {
    @EnvironmentObject var blockerService: AppBlockerService
    @Environment(\.dismiss) var dismiss

    @State private var apps: [BlockedApp] = []
    @State private var searchText: String = ""
    @State private var showInstalled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Add Apps")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
            }

            // Search
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)

            // Toggle: Running vs All installed
            Picker("", selection: $showInstalled) {
                Text("Running").tag(false)
                Text("All Apps").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: showInstalled) { _ in
                refreshApps()
            }

            // App list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredApps) { app in
                        appRow(app)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 300, height: 400)
        .background(Color.black)
        .onAppear { refreshApps() }
    }

    private func appRow(_ app: BlockedApp) -> some View {
        let isAdded = blockerService.isInActiveList(app)
        return Button {
            if isAdded {
                blockerService.removeFromActiveList(app)
            } else {
                blockerService.addToActiveList(app)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isAdded ? .green : .white.opacity(0.3))

                Text(app.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isAdded ? Color.white.opacity(0.08) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var filteredApps: [BlockedApp] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func refreshApps() {
        if showInstalled {
            apps = AppBlockerService.installedApps()
        } else {
            apps = AppBlockerService.runningGUIApps()
        }
    }
}
