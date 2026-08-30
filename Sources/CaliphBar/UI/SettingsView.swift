import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Launch at login", isOn: $store.launchAtLogin)
            Toggle("Notify once at 90% used", isOn: $store.notificationsEnabled)
            Toggle("Show floating edge pill", isOn: $store.pillVisible)

            Divider().overlay(Color.white.opacity(0.09))

            VStack(alignment: .leading, spacing: 8) {
                Text("Claude fallback estimate")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Only used when exact OAuth usage is unavailable and there is no fresh live reading to preserve.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)

                Stepper(value: $store.claudeSessionBudget, in: 5...200, step: 5) {
                    HStack {
                        Text("5-hour budget")
                        Spacer()
                        Text("$\(Int(store.claudeSessionBudget))")
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                Stepper(value: $store.claudeWeeklyBudget, in: 50...2000, step: 50) {
                    HStack {
                        Text("Weekly budget")
                        Spacer()
                        Text("$\(Int(store.claudeWeeklyBudget))")
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }

            Divider().overlay(Color.white.opacity(0.09))

            VStack(alignment: .leading, spacing: 7) {
                Button("Repair Claude Keychain Access") {
                    store.repairClaudeKeychainAccess()
                }
                .buttonStyle(.bordered)
                if let message = store.credentialRepairMessage {
                    Text(message)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(.green)
        .font(.system(size: 12))
        .foregroundStyle(.white)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.42)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07)))
    }
}
