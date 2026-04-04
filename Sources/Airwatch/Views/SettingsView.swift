import SwiftUI

/// Preferences pane. Two sections:
///   1. Refresh cadence (segmented picker over allowed intervals).
///   2. Menu-bar fields (toggle + drag-to-reorder).
struct SettingsView: View {
    @EnvironmentObject var preferences: Preferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                unitsSection
                refreshSection
                fieldsSection
            }
            .padding(24)
        }
        .frame(width: 440, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Units

    private var unitsSection: some View {
        Card {
            SectionHeader(icon: "ruler", title: "Units",
                          subtitle: "Imperial shows feet, knots, and °F. Metric shows meters, km/h, and °C.")

            Picker("", selection: $preferences.units) {
                ForEach(UnitSystem.allCases) { system in
                    Text(system.displayName).tag(system)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Refresh

    private var refreshSection: some View {
        Card {
            SectionHeader(icon: "arrow.clockwise", title: "Refresh Interval",
                          subtitle: "How often to poll the airline API for new flight data.")

            Picker("", selection: $preferences.refreshInterval) {
                ForEach(Preferences.refreshIntervalOptions, id: \.self) { seconds in
                    Text(label(forSeconds: seconds)).tag(seconds)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private func label(forSeconds s: Int) -> String {
        s < 60 ? "\(s)s" : "\(s / 60)m"
    }

    // MARK: - Menu bar fields

    private var fieldsSection: some View {
        Card {
            SectionHeader(icon: "menubar.rectangle", title: "Menu Bar Display",
                          subtitle: "Pick what shows next to the plane icon. Drag to reorder. The popover always shows everything.")

            VStack(spacing: 0) {
                ForEach(Array(FlightField.allCases.enumerated()), id: \.element.id) { idx, field in
                    FieldRow(field: field)
                    if idx < FlightField.allCases.count - 1 {
                        Divider().padding(.leading, 36)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if preferences.menuBarFields.count > 1 {
                Text("Order")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                List {
                    ForEach(preferences.menuBarFields) { field in
                        HStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.tertiary)
                            Image(systemName: field.iconName)
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            Text(field.displayName)
                            Spacer()
                        }
                    }
                    .onMove { indices, newOffset in
                        preferences.menuBarFields.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(preferences.menuBarFields.count) * 28 + 8)
            }
        }
    }
}

// MARK: - Components

/// A single row in the field toggle list.
private struct FieldRow: View {
    @EnvironmentObject var preferences: Preferences
    let field: FlightField

    private var isOn: Binding<Bool> {
        Binding(
            get: { preferences.menuBarFields.contains(field) },
            set: { _ in preferences.toggle(field) }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: field.iconName)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            Text(field.displayName)
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// Rounded card container with subtle background.
private struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

