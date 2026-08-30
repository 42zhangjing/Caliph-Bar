import SwiftUI
import AppKit
import CaliphBarCore

struct DetailPanelView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var selection: SelectionModel
    @State private var showSettings = false

    private let background = Color(red: 0.045, green: 0.046, blue: 0.052)

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            if showSettings {
                SettingsView(store: store)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            } else {
                providerCard
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }

            footer
                .padding(.bottom, 11)
        }
        .frame(width: 356)
        .fixedSize(horizontal: false, vertical: true)
        .background(RoundedRectangle(cornerRadius: 24).fill(background))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 8)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("CaliphBar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Button {
                store.refresh()
            } label: {
                Image(systemName: store.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(store.isRefreshing)

            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: showSettings ? "xmark" : "gearshape")
            }
            .buttonStyle(.plain)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white.opacity(0.72))
    }

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            providerTabs

            if let item = store.item(for: selection.selected) {
                HStack(spacing: 8) {
                    BrandMark(provider: item.provider, size: 20)
                    Text(item.provider.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    if let plan = item.planLabel {
                        Text(plan)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    sourceBadge(item.source)
                }

                if item.windows.isEmpty {
                    Text(item.note ?? "Usage unavailable")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.48))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(item.windows) { window in
                        UsageBar(window: window)
                    }
                    if let note = item.note {
                        Text(note)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.36))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.50)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.07)))
    }

    private var providerTabs: some View {
        HStack(spacing: 6) {
            ForEach(ProviderID.allCases, id: \.self) { provider in
                Button {
                    selection.selected = provider
                } label: {
                    HStack(spacing: 6) {
                        BrandMark(provider: provider, size: 16)
                        Text(provider.displayName)
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(selection.selected == provider ? .white : .white.opacity(0.38))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(selection.selected == provider ? Color.white.opacity(0.11) : .clear))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sourceBadge(_ source: UsageSourceKind) -> some View {
        let text: String
        switch source {
        case .live: text = "LIVE"
        case .estimated: text = "ESTIMATED"
        case .stale: text = "STALE"
        case .unavailable: text = "OFFLINE"
        }
        return Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(source == .live ? Color.green.opacity(0.9) : Color.white.opacity(0.48))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.07)))
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(store.isRefreshing ? Color.yellow : Color.white.opacity(0.25))
                .frame(width: 5, height: 5)
            if let date = store.lastUpdated {
                Text("Updated \(date.formatted(date: .omitted, time: .shortened))")
            } else {
                Text("Waiting for first refresh")
            }
        }
        .font(.system(size: 9.5))
        .foregroundStyle(.white.opacity(0.30))
    }
}
