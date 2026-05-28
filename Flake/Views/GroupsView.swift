import SwiftUI

struct GroupsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme

    @State private var showCreate = false
    @State private var showJoin = false
    @State private var showSeasonSettings = false
    @State private var groupPendingDelete: FlakeGroup? = nil
    @State private var showLeaveConfirm = false
    @State private var showDeleteGroupConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .top) {
                OmbreBackground(style: .split).frame(height: 300)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                state.featureScreen = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("‹")
                                Text("back")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.06))
                            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        EyebrowLabel(text: "your groups · \(state.groups.count)")
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 0) {
                        (Text("be #1 here.\n").font(.display(52))
                            + Text("last ").font(.display(52))
                            + Text("there.").font(.display(52)).italic().foregroundStyle(theme.gradient2))
                            .foregroundStyle(.white)
                    }
                    .padding(.bottom, 6)

                    Text("one leaderboard per thread. stats per group. the gap between them is, frankly, very funny.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineSpacing(3)
                        .padding(.bottom, 24)

                    // Group cards
                    VStack(spacing: 12) {
                        ForEach(state.groups) { group in
                            GroupCard(group: group, isActive: group.id == state.selectedGroupID)
                                .onTapGesture {
                                    withAnimation { state.selectGroup(group) }
                                }
                        }
                    }
                    .padding(.bottom, 14)

                    // Invite friends — visible for every group that has a thread key
                    if let group = state.selectedGroup, let key = group.threadKey {
                        let shareText = "join \(group.name) on flake.\n\ncode: \(key)\n\nopen flake → tap groups → join a group → enter this code."
                        ShareLink(item: shareText) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 13))
                                Text("invite to \(group.name)")
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                                Text(key)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(theme.g1)
                            }
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.g1.opacity(0.2), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)
                    }

                    // Season settings — only visible to the group leader of the selected group
                    if let group = state.selectedGroup,
                       group.groupLeaderID == state.currentUserID {
                        Button { showSeasonSettings = true } label: {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 13))
                                Text("season settings")
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                                Text("szn \(group.season) · \(group.seasonWeeks)w")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)
                    }

                    // Leave / delete group — shown for the currently selected group
                    if let group = state.selectedGroup {
                        let isLeader = group.groupLeaderID == state.currentUserID
                        Button {
                            groupPendingDelete = group
                            if isLeader {
                                showDeleteGroupConfirm = true
                            } else {
                                showLeaveConfirm = true
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isLeader ? "trash" : "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(isLeader ? "delete group" : "leave group")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                            }
                            .foregroundStyle(theme.bad)
                            .padding(16)
                            .background(theme.bad.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.bad.opacity(0.18), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)
                    }

                    // Start / join
                    HStack(spacing: 8) {
                        Button { showCreate = true } label: {
                            HStack {
                                Text("new group")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text("→").font(.system(size: 14))
                            }
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)

                        Button { showJoin = true } label: {
                            HStack {
                                Text("join a group")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text("→").font(.system(size: 14))
                            }
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 120)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color.flakeBG)
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showCreate) {
            CreateGroupSheet { name in
                state.createGroup(name: name)
            }
        }
        .sheet(isPresented: $showJoin) {
            JoinGroupSheet()
        }
        .sheet(isPresented: $showSeasonSettings) {
            if let group = state.selectedGroup {
                SeasonSettingsSheet(group: group)
            }
        }
        .confirmationDialog(
            "leave \"\(groupPendingDelete?.name ?? "group")\"?",
            isPresented: $showLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button("leave group", role: .destructive) {
                if let g = groupPendingDelete { state.leaveGroup(g) }
                groupPendingDelete = nil
            }
            Button("cancel", role: .cancel) { groupPendingDelete = nil }
        } message: {
            Text("you'll lose your stats and rank in this group.")
        }
        .confirmationDialog(
            "delete \"\(groupPendingDelete?.name ?? "group")\"?",
            isPresented: $showDeleteGroupConfirm,
            titleVisibility: .visible
        ) {
            Button("delete group for everyone", role: .destructive) {
                if let g = groupPendingDelete { state.deleteGroup(g) }
                groupPendingDelete = nil
            }
            Button("cancel", role: .cancel) { groupPendingDelete = nil }
        } message: {
            Text("this permanently deletes the group, all moves, and all stats for everyone in it.")
        }
    }
}

// MARK: - GroupCard

private struct GroupCard: View {
    let group: FlakeGroup
    let isActive: Bool

    @Environment(\.flakeTheme) private var theme

    var rankColor: AnyShapeStyle {
        if group.userRank == 1 { return AnyShapeStyle(theme.gradient) }
        if group.members.count > 0 && group.userRank == group.members.count { return AnyShapeStyle(Color(hex: "ff5a7a")) }
        return AnyShapeStyle(Color.white)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.name)
                    .font(.display(24))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(group.members.count) friends · \(group.moves.count) moves · szn \(group.season)")
                    .font(.mono(10))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(.bottom, 10)

            HStack {
                AvatarStack(members: group.members, maxVisible: 4, size: 24)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%02d", group.userRank))
                        .font(.display(28, weight: group.userRank == 1 ? .bold : .medium))
                        .foregroundStyle(rankColor)
                    Text("of \(group.members.count)")
                        .font(.mono(9))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }

            if group.currentMove != nil || !group.nextSummary.isEmpty {
                Color.white.opacity(0.08).frame(height: 1).padding(.vertical, 10)

                if let move = group.currentMove {
                    Text("next move · \(move.location) · ")
                        .foregroundStyle(Color.white.opacity(0.55))
                    + Text("\(move.lockedInCount) locked in")
                        .foregroundStyle(.white).bold()
                    + Text(" · \(timeUntilString(move.date))")
                        .foregroundStyle(theme.gradient2).italic()
                } else {
                    Text(group.nextSummary)
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
        }
        .font(.system(size: 12))
        .padding(18)
        .background(
            isActive
                ? AnyShapeStyle(LinearGradient(colors: [theme.g1.opacity(0.12), theme.g2.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(Color.white.opacity(0.04))
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(isActive ? theme.g1.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func timeUntilString(_ date: Date) -> String {
        let days = Int(date.timeIntervalSinceNow) / 86400
        if days > 1 { return "\(days) days out." }
        if days == 1 { return "tomorrow." }
        return "today."
    }
}

// MARK: - CreateGroupSheet

private struct CreateGroupSheet: View {
    let onCreate: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.flakeTheme) private var theme
    @Environment(AppState.self) private var state

    @State private var name = ""
    @State private var created = false

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            OmbreBackground(style: .top).frame(height: 280).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text(created ? "group created." : "new group.")
                    .font(.display(44))
                    .foregroundStyle(.white)
                    .padding(.bottom, 6)
                    .animation(.easeInOut, value: created)

                Text(created ? "share the code or send an invite." : "give your crew a name.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.bottom, 28)
                    .animation(.easeInOut, value: created)

                if !created {
                    TextField("", text: $name,
                              prompt: Text("thursday crew, house, soccer sundays…")
                                  .foregroundStyle(Color.white.opacity(0.3)))
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.bottom, 16)
                        .submitLabel(.done)
                        .onSubmit { createGroup() }

                    Button(action: createGroup) {
                        HStack {
                            Text("create group")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text("→").font(.system(size: 18))
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? AnyShapeStyle(Color.white.opacity(0.15))
                                    : AnyShapeStyle(theme.gradient2))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.plain)
                } else {
                    // Invite section — only shown right after creation, never again
                    VStack(alignment: .leading, spacing: 12) {
                        let threadKey = state.selectedGroup?.threadKey

                        // Join code card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("join code")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.white.opacity(0.4))

                            HStack(alignment: .center) {
                                if let key = threadKey {
                                    Text(key)
                                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .tracking(6)
                                } else {
                                    ProgressView().tint(.white.opacity(0.5))
                                    Text("syncing…")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.white.opacity(0.4))
                                }
                                Spacer()
                                if let key = threadKey {
                                    Button {
                                        UIPasteboard.general.string = key
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 18))
                                            .foregroundStyle(theme.g1)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Text("friends enter this in the join tab, or tap share below.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.35))
                                .lineSpacing(2)
                        }
                        .padding(18)
                        .background(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.g1.opacity(0.2), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        // Share button
                        if let key = threadKey {
                            let groupName = state.selectedGroup?.name ?? "my group"
                            let shareText = "join \(groupName) on flake.\n\ncode: \(key)\n\nopen flake → tap groups → join a group → enter this code."
                            ShareLink(item: shareText) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("invite friends")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(18)
                                .background(AnyShapeStyle(theme.gradient2))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                        }

                        Button { dismiss() } label: {
                            Text("done")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(14)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding(28)
        }
    }

    private func createGroup() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onCreate(trimmed)
        withAnimation(.easeInOut(duration: 0.25)) { created = true }
    }

}

// MARK: - JoinGroupSheet

struct JoinGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.flakeTheme) private var theme
    @Environment(AppState.self) private var state

    @State private var code = ""
    @State private var joining = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            OmbreBackground(style: .top).frame(height: 220).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("join a group.")
                    .font(.display(44))
                    .foregroundStyle(.white)
                    .padding(.bottom, 6)

                Text("enter the code someone shared with you.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.bottom, 28)

                // Code field
                TextField("", text: $code,
                          prompt: Text("e.g. A1B2C3D4")
                              .foregroundStyle(Color.white.opacity(0.3)))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(4)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .focused($focused)
                    .padding(16)
                    .background(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.bottom, 8)
                    .submitLabel(.go)
                    .onSubmit { tryJoin() }
                    .onChange(of: code) { _, new in
                        code = String(new.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
                    }

                // Error
                if let error = state.authErrorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "ff5a7a"))
                        .padding(.bottom, 8)
                }

                Button(action: tryJoin) {
                    HStack {
                        if joining { ProgressView().tint(.white).scaleEffect(0.8) }
                        Text(joining ? "joining…" : "join group")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        if !joining { Text("→").font(.system(size: 18)) }
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(
                        code.count < 6
                            ? AnyShapeStyle(Color.white.opacity(0.15))
                            : AnyShapeStyle(theme.gradient2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(code.count < 6 || joining)
                .buttonStyle(.plain)
                .padding(.bottom, 12)

                Button { dismiss() } label: {
                    Text("cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(28)
        }
        .onAppear {
            state.authErrorMessage = nil
            focused = true
        }
    }

    private func tryJoin() {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else { return }
        joining = true
        Task {
            await state.joinGroup(code: trimmed)
            joining = false
            if state.authErrorMessage == nil {
                dismiss()
            }
        }
    }
}

// MARK: - SeasonSettingsSheet
// Only reachable by the group leader (created_by). Lets them set season number,
// length, and start date. Members never see this sheet.

private struct SeasonSettingsSheet: View {
    let group: FlakeGroup

    @Environment(\.dismiss) private var dismiss
    @Environment(\.flakeTheme) private var theme
    @Environment(AppState.self) private var state

    @State private var seasonNumber: Int
    @State private var seasonWeeks: Int
    @State private var seasonStartedAt: Date
    @State private var saving = false

    init(group: FlakeGroup) {
        self.group = group
        _seasonNumber    = State(initialValue: group.season)
        _seasonWeeks     = State(initialValue: group.seasonWeeks)
        _seasonStartedAt = State(initialValue: group.seasonStartedAt ?? Date())
    }

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            OmbreBackground(style: .top).frame(height: 220).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("season settings.")
                    .font(.display(38))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)

                Text("only you see this — you created the group.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.bottom, 32)

                // Season number
                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: "season number")
                    HStack(spacing: 0) {
                        ForEach(1...8, id: \.self) { n in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { seasonNumber = n }
                            } label: {
                                Text("\(n)")
                                    .font(.system(size: 15, weight: seasonNumber == n ? .bold : .regular,
                                                  design: .monospaced))
                                    .foregroundStyle(seasonNumber == n ? .white : Color.white.opacity(0.35))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(seasonNumber == n
                                                ? AnyShapeStyle(theme.gradient2)
                                                : AnyShapeStyle(Color.white.opacity(0.04)))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            if n < 8 { Spacer().frame(width: 4) }
                        }
                    }
                }
                .padding(.bottom, 20)

                // Season length
                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: "season length")
                    HStack(spacing: 4) {
                        ForEach([4, 6, 8, 10, 12, 16], id: \.self) { w in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { seasonWeeks = w }
                            } label: {
                                Text("\(w)w")
                                    .font(.system(size: 13, weight: seasonWeeks == w ? .bold : .regular,
                                                  design: .monospaced))
                                    .foregroundStyle(seasonWeeks == w ? .white : Color.white.opacity(0.35))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(seasonWeeks == w
                                                ? AnyShapeStyle(theme.gradient2)
                                                : AnyShapeStyle(Color.white.opacity(0.04)))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.bottom, 20)

                // Start date
                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: "season started")
                    DatePicker("", selection: $seasonStartedAt, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .colorScheme(.dark)
                }
                .padding(.bottom, 32)

                // Save
                Button {
                    saving = true
                    Task {
                        await state.updateGroupSeason(
                            seasonNumber: seasonNumber,
                            seasonWeeks: seasonWeeks,
                            seasonStartedAt: seasonStartedAt
                        )
                        saving = false
                        dismiss()
                    }
                } label: {
                    HStack {
                        if saving {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        }
                        Text(saving ? "saving…" : "save season")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        if !saving { Text("→").font(.system(size: 18)) }
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(AnyShapeStyle(theme.gradient2))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(saving)
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(28)
        }
    }
}
