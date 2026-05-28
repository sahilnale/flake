import SwiftUI
import MapKit
import Combine

// MARK: - Expanded RSVP view (shown when user taps a Move bubble in iMessage)

struct MoveRSVPExtensionView: View {
    let move: Move
    /// Supabase user ID of the person viewing this — used to look up their existing RSVP.
    /// Nil briefly on first open while the async auth check completes.
    let currentUserID: UUID?
    let onRSVP: (RSVPStatus) -> Void

    @State private var selected: RSVPStatus? = nil
    @Environment(\.flakeTheme) private var theme

    // ── Derived ──────────────────────────────────────────────────────────────

    /// The current user's existing RSVP (from Supabase UUID).
    private var myExistingStatus: RSVPStatus? {
        guard let uid = currentUserID else { return nil }
        return move.rsvps[uid]
    }

    /// RSVPs from people other than the current user.
    private var othersRSVPs: [UUID: RSVPStatus] {
        guard let uid = currentUserID else { return move.rsvps }
        return move.rsvps.filter { $0.key != uid }
    }

    private var lockedInCount: Int { move.rsvps.values.filter { $0 == .lockedIn }.count }
    private var maybeCount:    Int { move.rsvps.values.filter { $0 == .sendingIt }.count }
    private var outCount:      Int { move.rsvps.values.filter { $0 == .flaked }.count }
    private var totalRSVPs:    Int { move.rsvps.count }

    private var flakePenalty: Int { move.flakePenalty(for: currentUserID ?? UUID()) }

    // ── Body ─────────────────────────────────────────────────────────────────

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
                        statusBadge
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

                    // Date + location
                    HStack(spacing: 6) {
                        Text(formattedDate(move.date))
                        if !move.location.isEmpty {
                            Text("·").foregroundStyle(Color.white.opacity(0.3))
                            Text(move.location)
                        }
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(0.3)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .lineLimit(1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)

                    // ── RSVP picker ──────────────────────────────────────────
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
                    .padding(.bottom, 22)

                    // ── Tally ────────────────────────────────────────────────
                    if totalRSVPs > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("responses")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.5))
                                .padding(.horizontal, 20)

                            HStack(spacing: 8) {
                                TallyPill(label: "yes", count: lockedInCount, color: theme.good)
                                TallyPill(label: "maybe", count: maybeCount, color: theme.g3)
                                TallyPill(label: "out", count: outCount, color: theme.bad)
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 16)
                    }

                    // Extra bottom padding so confirm button doesn't overlap
                    Spacer().frame(height: 88)
                }
            }

            // ── Confirm button — always pinned to bottom ─────────────────────
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.flakeBG.opacity(0), Color.flakeBG],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 28)

                if currentUserID == nil {
                    // Still loading Supabase session — show spinner
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("signing in…")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .background(Color.flakeBG)
                } else {
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
        }
        .onAppear { selected = myExistingStatus }
        // If currentUserID arrives after the view appears, sync the selection
        .onChange(of: currentUserID) { _, uid in
            if selected == nil, let uid, let status = move.rsvps[uid] {
                selected = status
            }
        }
    }

    // ── Sub-views ─────────────────────────────────────────────────────────

    @ViewBuilder
    private var statusBadge: some View {
        if let status = myExistingStatus {
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

    private var confirmLabel: String {
        guard let s = selected else { return "pick one above" }
        return myExistingStatus == nil ? "confirm · \(s.label)" : "change to · \(s.label)"
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

// MARK: - Tally pill

private struct TallyPill: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text("\(count)")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(count > 0 ? color : Color.white.opacity(0.3))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(count > 0 ? color.opacity(0.1) : Color.white.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(count > 0 ? color.opacity(0.3) : Color.white.opacity(0.07), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    .stroke(isSelected ? color.opacity(0.6) : Color.white.opacity(0.08),
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Participant model (kept for backward compat — no longer used in RSVP view)

struct MessageParticipant: Identifiable, Hashable {
    let id: UUID
    var label: String
    var isMe: Bool
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
                    } else {
                        // No groups in cache yet — nudge user to open the main app
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.g3)
                            Text("open flake first to load your groups")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.55))
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
            if selectedGroup == nil { selectedGroup = groups.first }
        }
    }
}

// MARK: - Sub-views

private struct FlakeTextField: View {
    let placeholder: String
    @Binding var text: String

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
                    .onChange(of: text) { _, value in search.update(value) }
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
        completions = trimmed.isEmpty ? [] : { completer.queryFragment = trimmed; return [] }()
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async { self.completions = completer.results }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { self.completions = [] }
    }
}
