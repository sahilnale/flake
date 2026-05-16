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

    private var isGroupLeader: Bool {
        move.creatorID == currentParticipantID
    }

    private var flakePenalty: Int {
        move.flakePenalty(for: currentParticipantID)
    }

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()

            // Ombre bg
            RadialGradient(colors: [theme.g2.opacity(0.7), .clear], center: .init(x: 0.5, y: 0.5), startRadius: 0, endRadius: 300)
                .blur(radius: 20)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("flake.")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .italic()
                        .foregroundStyle(theme.gradient2)
                    Spacer()
                    Text(existingStatus == nil ? "a move" : "change RSVP")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Move title
                VStack(alignment: .leading, spacing: 4) {
                    Text(move.title)
                        .font(.system(size: 42, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(theme.gradient2)
                    Text(formattedDate(move.date))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .tracking(0.4)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

                HStack(spacing: 10) {
                    Text("★")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.g3)
                    Text(isGroupLeader ? "you started this · +25 if you hold · −\(flakePenalty) if you flake" : "group leader gets +25 pts, but loses more for flaking")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                    Spacer()
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(everyoneResponded ? "everyone responded" : "the lineup")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                        Spacer()
                        Text("\(respondedCount)/\(participants.count)")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(everyoneResponded ? theme.good : Color.white.opacity(0.42))
                    }

                    VStack(spacing: 0) {
                        ForEach(participants) { participant in
                            ParticipantRow(participant: participant, status: move.rsvps[participant.id])
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)

                // Options
                VStack(spacing: 8) {
                    ExtRSVPButton(emoji: "⚡", label: "lock in",    pts: "+15 pts", isPrimary: true,  selected: selected == .lockedIn)  { selected = .lockedIn  }
                    ExtRSVPButton(emoji: "🤞", label: "sending it", pts: "+5 if you show", isPrimary: false, selected: selected == .sendingIt) { selected = .sendingIt }
                    ExtRSVPButton(emoji: "💀", label: "flake",      pts: "−\(flakePenalty) pts",  isPrimary: false, selected: selected == .flaked)    { selected = .flaked    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                // Confirm
                Button {
                    if let s = selected { onRSVP(s) }
                } label: {
                    HStack {
                        Text(selected.map { "\(existingStatus == nil ? "confirm" : "change to") · \($0.label)" } ?? "pick one")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text("→").font(.system(size: 18))
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(selected != nil ? AnyShapeStyle(theme.gradient2) : AnyShapeStyle(Color.white.opacity(0.1)))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(selected == nil)
                .padding(.horizontal, 20)

                Spacer()

                Text("open the ranks in the flake app to see the leaderboard →")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .tracking(0.3)
                    .foregroundStyle(Color.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            selected = existingStatus
        }
    }

    private var existingStatus: RSVPStatus? {
        move.rsvps[currentParticipantID]
    }

    private var respondedCount: Int {
        participants.filter { move.rsvps[$0.id] != nil }.count
    }

    private var everyoneResponded: Bool {
        !participants.isEmpty && respondedCount == participants.count
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE MMM d · h:mma"
        return f.string(from: date).lowercased()
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
    let onCreate: (Move) -> Void

    @State private var title = ""
    @State private var location = ""
    @State private var date = Date().addingTimeInterval(86400 * 3)

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            RadialGradient(colors: [theme.g1.opacity(0.5), .clear], center: .init(x: 0.5, y: 0), startRadius: 0, endRadius: 250)
                .blur(radius: 20).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("new move.")
                    .font(.system(size: 36, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(theme.gradient2)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 20)

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

                Button {
                    let move = Move(id: UUID(), title: title, subtitle: "", location: location,
                                    date: date, creatorID: UUID(), rsvps: [:], groupID: UUID())
                    onCreate(move)
                } label: {
                    HStack {
                        Text("send move")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text("→").font(.system(size: 18))
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(title.isEmpty || location.isEmpty ? AnyShapeStyle(Color.white.opacity(0.1)) : AnyShapeStyle(theme.gradient2))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(title.isEmpty || location.isEmpty)
                .padding(.horizontal, 20)

                Spacer()
            }
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
