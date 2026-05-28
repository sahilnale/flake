import SwiftUI
import MapKit
import Combine

// MARK: - Expanded RSVP view (shown when user taps a Move bubble in iMessage)

struct MoveRSVPExtensionView: View {
    let move: Move
    let participants: [MessageParticipant]
    let currentParticipantID: UUID
    let onRSVP: (RSVPStatus) -> Void

    @State private var selected: RSVPStatus? = nil
    @Environment(\.flakeTheme) private var theme

    private var existingStatus: RSVPStatus? { move.rsvps[currentParticipantID] }
    private var isGroupLeader: Bool { move.creatorID == currentParticipantID }
    private var flakePenalty: Int { move.flakePenalty(for: currentParticipantID) }
    private var respondedCount: Int { participants.filter { move.rsvps[$0.id] != nil }.count }
    private var everyoneResponded: Bool { !participants.isEmpty && respondedCount == participants.count }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.flakeBG.ignoresSafeArea()
            RadialGradient(colors: [theme.g1.opacity(0.22), .clear],
                           center: .init(x: 0.5, y: 0), startRadius: 0, endRadius: 280)
                .ignoresSafeArea()

            // ── Scrollable content ───────────────────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Header
                    HStack {
                        Text("flake.")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .italic()
                            .foregroundStyle(theme.gradient2)
                        Spacer()
                        if let status = existingStatus {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(rsvpColor(status))
                                    .frame(width: 6, height: 6)
                                Text("you're \(status.label)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                        } else {
                            Text("tap to rsvp")
                                .font(.system(size: 10, design: .monospaced))
                                .tracking(0.5)
                                .foregroundStyle(Color.white.opacity(0.35))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 12)

                    // Move title
                    Text(move.title)
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 4)

                    Text(formattedDate(move.date))
                        .font(.system(size: 11, design: .monospaced))
                        .tracking(0.3)
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // ── RSVP picker — 3 equal chips ──────────────────────────
                    HStack(spacing: 8) {
                        RSVPChip(emoji: "⚡", label: "lock in",
                                 pts: "+15", color: theme.good,
                                 isSelected: selected == .lockedIn) { selected = .lockedIn }
                        RSVPChip(emoji: "🤞", label: "sending it",
                                 pts: "+5", color: theme.g3,
                                 isSelected: selected == .sendingIt) { selected = .sendingIt }
                        RSVPChip(emoji: "💀", label: "flake",
                                 pts: "−\(flakePenalty)", color: theme.bad,
                                 isSelected: selected == .flaked) { selected = .flaked }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // ── Lineup ───────────────────────────────────────────────
                    HStack {
                        Text(everyoneResponded ? "everyone responded" : "the lineup")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                        Spacer()
                        Text("\(respondedCount) of \(participants.count) responded")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(everyoneResponded ? theme.good : Color.white.opacity(0.35))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                    VStack(spacing: 0) {
                        ForEach(participants) { p in
                            ParticipantRow(participant: p, status: move.rsvps[p.id])
                        }
                    }
                    .padding(.horizontal, 20)

                    // Extra bottom padding so confirm button doesn't overlap last row
                    Spacer().frame(height: 88)
                }
            }

            // ── Confirm button — always pinned to bottom ─────────────────────
            VStack(spacing: 0) {
                // Fade out the content behind the button
                LinearGradient(
                    colors: [Color.flakeBG.opacity(0), Color.flakeBG],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 28)

                Button {
                    guard let s = selected else { return }
                    onRSVP(s)
                } label: {
                    HStack {
                        Text(confirmLabel)
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text("→").font(.system(size: 18))
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(selected != nil
                        ? AnyShapeStyle(theme.gradient2)
                        : AnyShapeStyle(Color.white.opacity(0.08)))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(selected == nil)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .background(Color.flakeBG)
            }
        }
        .onAppear { selected = existingStatus }
    }

    private var confirmLabel: String {
        guard let s = selected else { return "pick one above" }
        return existingStatus == nil ? "confirm · \(s.label)" : "change to · \(s.label)"
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE MMM d · h:mma"
        return f.string(from: date).lowercased()
    }

    private func rsvpColor(_ status: RSVPStatus) -> Color {
        switch status {
        case .lockedIn:  return theme.good
        case .sendingIt: return theme.g3
        case .flaked:    return theme.bad
        case .silent:    return Color.white.opacity(0.3)
        }
    }
}

// MARK: - RSVP chip (3-across picker)

private struct RSVPChip: View {
    let emoji: String
    let label: String
    let pts: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text(pts)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isSelected ? color : Color.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected
                ? AnyShapeStyle(color.opacity(0.18))
                : AnyShapeStyle(Color.white.opacity(0.05)))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color.opacity(0.6) : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct MessageParticipant: Identifiable, Hashable {
    let id: UUID
    var label: String
    var isMe: Bool
}

private struct ParticipantRow: View {
    let participant: MessageParticipant
    let status: RSVPStatus?
    @Environment(\.flakeTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            Text(participant.isMe ? "u" : initials(for: participant.label))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(participant.isMe ? AnyShapeStyle(theme.gradient2) : AnyShapeStyle(Color.white.opacity(0.1)))
                .clipShape(Circle())

            Text(participant.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            Text(status?.label ?? "no RSVP")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(status == nil ? Color.white.opacity(0.06) : statusColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Color.white.opacity(0.06).frame(height: 1)
        }
    }

    private var statusColor: Color {
        switch status {
        case .lockedIn: return theme.good
        case .sendingIt: return theme.g3
        case .flaked: return theme.bad
        case .silent, nil: return Color.white.opacity(0.45)
        }
    }

    private func initials(for label: String) -> String {
        label.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map { String($0) }
            .joined()
            .lowercased()
    }
}

// MARK: - Create move view (when user starts a new move from iMessage)

struct CreateMoveView: View {
    /// Groups the current user belongs to (from SharedGroupStore)
    var groups: [SharedGroupStore.Entry] = []
    /// Supabase user ID of the person creating the move
    var currentUserID: UUID?
    /// Callback: (move, groupEntry) — groupEntry is nil only when groups is empty
    let onCreate: (Move, SharedGroupStore.Entry?) -> Void

    @State private var title = ""
    @State private var location = ""
    @State private var date = Date().addingTimeInterval(86400 * 3)
    @State private var selectedGroup: SharedGroupStore.Entry? = nil

    @Environment(\.flakeTheme) private var theme

    private var canSend: Bool { !title.isEmpty && !location.isEmpty }

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            RadialGradient(colors: [theme.g1.opacity(0.5), .clear], center: .init(x: 0.5, y: 0), startRadius: 0, endRadius: 250)
                .blur(radius: 20).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("new move.")
                        .font(.system(size: 36, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(theme.gradient2)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 20)

                    // ── Group picker (only shown when >1 group) ──────────────
                    if groups.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("which group?")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .tracking(0.5)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.white.opacity(0.45))
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(groups) { entry in
                                        Button {
                                            selectedGroup = entry
                                        } label: {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(entry.name)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(.white)
                                                    .lineLimit(1)
                                                Text("\(entry.memberCount) members")
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundStyle(Color.white.opacity(0.5))
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(selectedGroup?.id == entry.id
                                                ? AnyShapeStyle(LinearGradient(colors: [theme.g1.opacity(0.25), theme.g2.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                : AnyShapeStyle(Color.white.opacity(0.06)))
                                            .overlay(RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedGroup?.id == entry.id ? theme.g1.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 14)
                    } else if let only = groups.first {
                        // Single group — show a subtle label
                        HStack(spacing: 6) {
                            Text("group:")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.4))
                            Text(only.name)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(theme.g1)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }

                    // ── Move details ─────────────────────────────────────────
                    VStack(spacing: 12) {
                        FlakeTextField(placeholder: "what's the move?", text: $title)
                        MessageLocationSearchField(text: $location)
                        DatePicker("when?", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .colorScheme(.dark)
                            .padding(16)
                            .background(Color.white.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    HStack(spacing: 10) {
                        Text("★")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.g3)
                        Text("starting the move makes you group leader · +25 pts")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    let needsGroup = groups.count > 1 && selectedGroup == nil
                    Button {
                        guard canSend && !needsGroup else { return }
                        let groupEntry = selectedGroup ?? groups.first
                        let groupID   = groupEntry?.id ?? UUID()
                        let creatorID = currentUserID ?? UUID()
                        let move = Move(
                            id: UUID(),
                            title: title,
                            subtitle: "",
                            location: location,
                            date: date,
                            creatorID: creatorID,
                            rsvps: [creatorID: .lockedIn],
                            groupID: groupID
                        )
                        onCreate(move, groupEntry)
                    } label: {
                        HStack {
                            Text(needsGroup ? "pick a group first" : "send move")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            if !needsGroup { Text("→").font(.system(size: 18)) }
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(!canSend || needsGroup
                            ? AnyShapeStyle(Color.white.opacity(0.1))
                            : AnyShapeStyle(theme.gradient2))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .disabled(!canSend || needsGroup)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
        }
        .onAppear {
            // Auto-select the only group if there's just one
            if selectedGroup == nil { selectedGroup = groups.first }
        }
    }
}

// MARK: - Sub-views

private struct ExtRSVPButton: View {
    let emoji: String
    let label: String
    let pts: String
    let isPrimary: Bool
    let selected: Bool
    let action: () -> Void

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(emoji).font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(pts)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .tracking(0.4)
                        .foregroundStyle(isPrimary ? theme.good : Color.white.opacity(0.4))
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.g1)
                }
            }
            .padding(16)
            .background(selected ? AnyShapeStyle(LinearGradient(colors: [theme.g1.opacity(0.18), theme.g2.opacity(0.1)], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? theme.g1 : Color.white.opacity(0.08), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

private struct FlakeTextField: View {
    let placeholder: String
    @Binding var text: String
    @Environment(\.flakeTheme) private var theme

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .padding(16)
            .background(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MessageLocationSearchField: View {
    @Binding var text: String
    @StateObject private var search = MessageLocationSearchModel()
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "map")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
                TextField("search Apple Maps", text: $text)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.words)
                    .focused($focused)
                    .onChange(of: text) { _, value in
                        search.update(value)
                    }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if focused && !search.completions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(search.completions.prefix(4).enumerated()), id: \.offset) { _, completion in
                        Button {
                            text = [completion.title, completion.subtitle]
                                .filter { !$0.isEmpty }
                                .joined(separator: " · ")
                            focused = false
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.white.opacity(0.48))
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.flakeBG.opacity(0.98))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.top, 6)
            }
        }
    }
}

private final class MessageLocationSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var completions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            completions = []
        } else {
            completer.queryFragment = trimmed
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.completions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.completions = []
        }
    }
}
