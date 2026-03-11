import SwiftUI

struct BlockerConfigView: View {
    @EnvironmentObject var blockerService: AppBlockerService
    @Binding var showingAppPicker: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text("APP BLOCKER")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Mode picker
            HStack {
                Text("Mode")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Picker("", selection: $blockerService.mode) {
                    Text("Blocklist").tag(BlockerMode.blocklist)
                    Text("Allowlist").tag(BlockerMode.allowlist)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            // App list
            VStack(spacing: 2) {
                Text(blockerService.activeListLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                if blockerService.activeList.isEmpty {
                    Text("No apps configured")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach(blockerService.activeList) { app in
                        HStack(spacing: 6) {
                            Text(app.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                blockerService.removeFromActiveList(app)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(4)
                    }
                }

                // Add app button
                Button {
                    showingAppPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                        Text("Add App...")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.blue.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }
}
