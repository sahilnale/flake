import SwiftUI
import MapKit
import Combine

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        ZStack(alignment: .bottom) {
            Color.flakeBG.ignoresSafeArea()

            Group {
                if state.authStatus == .restoringSession || state.isBootstrappingData {
                    SessionRestoreView()
                } else if state.shouldShowAuthGate {
                    AuthGateView()
                } else if let feature = state.featureScreen {
                    switch feature {
                    case .groups: GroupsView()
                    case .recap: RecapView()
                    }
                } else {
                    switch state.selectedTab {
                    case .home:   HomeView()
                    case .ranks:  LeaderboardView()
                    case .roasts: RoastsView()
                    case .you:    ProfileView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if state.featureScreen == nil && !state.shouldShowAuthGate && !state.isBootstrappingData {
                FlakeNavBar(selected: $state.selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            // Sync error banner — only shown when signed in (not an auth error)
            if state.authStatus == .signedIn, let msg = state.authErrorMessage {
                SyncErrorBanner(message: msg) {
                    state.authErrorMessage = nil
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(99)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .sheet(isPresented: $state.rsvpSheetVisible) {
            RSVPView()
                .environment(state)
                .environment(\.flakeTheme, state.theme)
        }
        .sheet(isPresented: $state.voteSheetVisible) {
            VoteView()
                .environment(state)
                .environment(\.flakeTheme, state.theme)
        }
        .sheet(isPresented: $state.createMoveSheetVisible) {
            CreateMoveSheet()
                .environment(state)
                .environment(\.flakeTheme, state.theme)
        }
        .sheet(isPresented: $state.calendarSheetVisible) {
            EventCalendarSheet()
                .environment(state)
                .environment(\.flakeTheme, state.theme)
        }
        .sheet(isPresented: $state.excusedRequestSheetVisible) {
            RequestExcusedAbsenceSheet()
                .environment(state)
                .environment(\.flakeTheme, state.theme)
        }
        .sheet(isPresented: $state.attendanceSheetVisible) {
            AttendanceSettlementSheet()
                .environment(state)
                .environment(\.flakeTheme, state.theme)
        }
    }
}

private struct AttendanceSettlementSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var attendance: [UUID: AttendanceStatus] = [:]

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            OmbreBackground(style: .split)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    EyebrowLabel(text: "settle points · \(state.activeMove.location)", color: theme.g3)
                        .padding(.bottom, 14)

                    (Text("who\n").font(.display(52)) + Text("showed?").font(.display(52)).italic().foregroundStyle(theme.gradient2))
                        .foregroundStyle(.white)
                        .lineSpacing(-5)
                        .padding(.bottom, 12)

                    Text("RSVPs are promises. This is the final attendance check that applies points.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineSpacing(3)
                        .padding(.bottom, 18)

                    VStack(spacing: 0) {
                        ForEach(state.activeFriends) { member in
                            AttendanceMemberRow(
                                member: member,
                                selection: Binding(
                                    get: { attendance[member.id] ?? .showed },
                                    set: { attendance[member.id] = $0 }
                                ),
                                points: state.pointDelta(for: member.id, in: state.activeMove, attendance: attendance[member.id] ?? .showed),
                                isExcused: state.isExcused(member.id, for: state.activeMove)
                            )
                        }
                    }
                    .padding(.bottom, 20)

                    Button {
                        state.settleActiveMove(attendance: attendance)
                        dismiss()
                    } label: {
                        HStack {
                            Text("settle move")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text("→").font(.system(size: 18))
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(theme.gradient2)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    Button("cancel") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(14)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.flakeBG)
        .onAppear {
            attendance = state.activeMove.isSettled ? state.activeMove.attendance : state.defaultAttendance(for: state.activeMove)
        }
    }
}

private struct AttendanceMemberRow: View {
    let member: Member
    @Binding var selection: AttendanceStatus
    let points: Int
    let isExcused: Bool

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                AvatarView(initials: member.initials, colorHex: member.avatarColorHex, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(isExcused && selection == .missed ? "excused · 0 pts" : "\(points >= 0 ? "+" : "")\(points) pts")
                        .font(.mono(10))
                        .tracking(0.5)
                        .foregroundStyle(points >= 0 ? theme.good : theme.bad)
                }
                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(AttendanceStatus.allCases, id: \.rawValue) { status in
                    Button {
                        selection = status
                    } label: {
                        Text(status.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(selection == status ? .white : Color.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selection == status ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Color.white.opacity(0.06).frame(height: 1)
        }
    }
}

private struct RequestExcusedAbsenceSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var reason = ""

    private var canSubmit: Bool {
        !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            OmbreBackground(style: .center)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    EyebrowLabel(text: "group vote · \(state.activeMove.location)", color: theme.g3)
                        .padding(.bottom, 14)

                    (Text("request\n").font(.display(52)) + Text("mercy.").font(.display(52)).italic().foregroundStyle(theme.gradient2))
                        .foregroundStyle(.white)
                        .lineSpacing(-5)
                        .padding(.bottom, 12)

                    Text("Tell the group why this flake should be excused. If the vote passes, your points survive this one.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineSpacing(3)
                        .padding(.bottom, 18)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("your excuse")
                            .font(.mono(10))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.white.opacity(0.45))

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $reason)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 150)
                                .padding(10)

                            if reason.isEmpty {
                                Text("food poisoning, family thing, train died, actually compelling evidence...")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.white.opacity(0.35))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }
                        .background(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.bottom, 14)

                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.g3)
                        Text("at stake: −\(state.activeMove.flakePenalty(for: state.currentUserID)) pts")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.bottom, 22)

                    Button {
                        state.requestExcusedAbsence(reason: reason)
                        dismiss()
                    } label: {
                        HStack {
                            Text("send to group vote")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text("→").font(.system(size: 18))
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(canSubmit ? AnyShapeStyle(theme.gradient2) : AnyShapeStyle(Color.white.opacity(0.1)))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .disabled(!canSubmit)

                    Button("cancel") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(14)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.flakeBG)
    }
}

private struct EventCalendarSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            OmbreBackground(style: .split)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    EyebrowLabel(text: "calendar · \(state.allEventEntries.count) moves")
                        .padding(.bottom, 12)

                    (Text("all\n").font(.display(54)) + Text("moves.").font(.display(54)).italic().foregroundStyle(theme.gradient2))
                        .foregroundStyle(.white)
                        .lineSpacing(-6)
                        .padding(.bottom, 18)

                    VStack(spacing: 10) {
                        ForEach(state.allEventEntries) { entry in
                            CalendarEventRow(entry: entry, isSelected: entry.move.id == state.activeMove.id && entry.groupID == state.selectedGroupID) {
                                state.selectEvent(entry)
                                dismiss()
                            }
                        }
                    }
                    .padding(.bottom, 18)

                    Button("close") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(14)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.flakeBG)
    }
}

private struct CalendarEventRow: View {
    let entry: AppState.EventEntry
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(month(entry.move.date))
                        .font(.mono(9, weight: .bold))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(isSelected ? theme.g3 : Color.white.opacity(0.5))
                    Text(day(entry.move.date))
                        .font(.display(28, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 50, height: 58)
                .background(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.move.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(entry.groupName) · \(entry.move.location) · \(time(entry.move.date))")
                        .font(.mono(11))
                        .tracking(0.2)
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineLimit(1)
                    Text("\(entry.move.lockedInCount) locked in · \(entry.move.sendingItCount) maybe · \(entry.move.flakedCount) out")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.48))
                }

                Spacer()
            }
            .padding(14)
            .background(isSelected ? AnyShapeStyle(LinearGradient(colors: [theme.g1.opacity(0.16), theme.g2.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(isSelected ? theme.g1.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func month(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: date).lowercased()
    }
}

private struct CreateMoveSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var subtitle = ""
    @State private var location = ""
    @State private var date = Date().addingTimeInterval(86400 * 2)

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            OmbreBackground(style: .center)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    EyebrowLabel(text: state.selectedGroup?.name ?? "new move")
                        .padding(.bottom, 12)

                    (Text("new\n").font(.display(54)) + Text("move.").font(.display(54)).italic().foregroundStyle(theme.gradient2))
                        .foregroundStyle(.white)
                        .lineSpacing(-6)
                        .padding(.bottom, 18)

                    VStack(spacing: 12) {
                        MoveField(title: "what's the move?", text: $title)
                        MoveField(title: "one-line vibe", text: $subtitle)
                        LocationSearchField(text: $location)

                        DatePicker("when?", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .colorScheme(.dark)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.bottom, 16)

                    HStack(spacing: 10) {
                        Text("★")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.g3)
                        Text("you start it, you are group leader · +25 pts")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.bottom, 22)

                    Button {
                        state.createMove(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
                            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                            date: date
                        )
                        dismiss()
                    } label: {
                        HStack {
                            Text("create move")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text("→")
                                .font(.system(size: 18))
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(canCreate ? AnyShapeStyle(theme.gradient2) : AnyShapeStyle(Color.white.opacity(0.1)))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .disabled(!canCreate)

                    Button("cancel") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(14)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.flakeBG)
    }
}

private struct LocationSearchField: View {
    @Binding var text: String
    @StateObject private var search = LocationSearchModel()
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
                    ForEach(Array(search.completions.prefix(5).enumerated()), id: \.offset) { _, completion in
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

private final class LocationSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
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

private struct MoveField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .textInputAutocapitalization(.never)
            .padding(16)
            .background(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Sync error banner

private struct SyncErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.bad)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(hex: "1a0a0a"))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(theme.bad.opacity(0.35)), alignment: .bottom)
        .padding(.top, 50) // below the status bar notch
    }
}

