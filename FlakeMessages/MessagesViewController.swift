import UIKit
import Messages
import SwiftUI

// MARK: - Main iMessage extension controller

final class MessagesViewController: MSMessagesAppViewController {

    private var selectedMove: Move?
    private var selectedInvite: GroupInvite?
    private var showingInvitePicker = false
    /// True only when the user explicitly tapped "send a move" — CreateMoveView must never appear otherwise.
    private var isCreatingMove = false

    /// Groups available for invite/create — starts from cache, refreshed from Supabase on activation.
    private var cachedGroups: [SharedGroupStore.Entry] = SharedGroupStore.load()

    /// Supabase user ID of the current user — loaded async on activation.
    private var currentUserID: UUID?

    /// Most-recent move from SharedGroupStore cache (populated by the main app).
    /// Available immediately without any network calls — guarantees the RSVP view
    /// is reachable as soon as the extension opens, even without tapping a card.
    private var cachedMove: Move? = SharedGroupStore.loadRecentMove()

    /// Recent moves from Supabase — refreshed async; overwrites cachedMove.
    private var cachedMoves: [Move] = []

    // MARK: - Lifecycle

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)

        let sm = conversation.selectedMessage
        NSLog("🟡 willBecomeActive — selectedMessage: %@, url: %@",
              sm == nil ? "NIL" : "present",
              sm?.url?.absoluteString ?? "no url")

        // Parse whatever the user tapped (move card or invite card).
        selectedMove   = move(from: sm)
        selectedInvite = GroupInvite.fromMessageURL(sm?.url)

        NSLog("🟡 parsed — selectedMove: %@, selectedInvite: %@",
              selectedMove?.title ?? "nil",
              selectedInvite?.groupName ?? "nil")

        showingInvitePicker = false
        isCreatingMove   = false

        // Load cached groups immediately (no network).
        cachedGroups = SharedGroupStore.load()
        // Load the most recent move from the local cache so the RSVP view is
        // visible instantly — no async Supabase call needed on first render.
        cachedMove = SharedGroupStore.loadRecentMove()

        // Refresh groups + user ID + moves in background.
        #if canImport(Supabase)
        Task { [weak self] in
            async let freshGroups = ExtensionGroupLoader.shared.loadFresh()
            async let uid         = ExtensionGroupLoader.shared.currentUserID()
            let (groups, userID) = await (freshGroups, uid)

            // Fetch recent moves for all groups; prioritise the first group for speed.
            var moves: [Move] = []
            for entry in groups.prefix(3) {
                let fetched = await ExtensionGroupLoader.shared.fetchMoves(groupID: entry.id)
                moves.append(contentsOf: fetched)
                if !moves.isEmpty { break } // one group with moves is enough
            }

            await MainActor.run {
                guard let self else { return }
                self.cachedGroups  = groups
                self.currentUserID = userID
                self.cachedMoves   = moves
                if let first = moves.first { self.cachedMove = first }

                // If nothing was selected and we now have moves, refresh the panel.
                if self.selectedMove == nil, self.selectedInvite == nil,
                   !moves.isEmpty, let conv = self.activeConversation {
                    self.removeAllChildren()
                    self.presentView(for: conv, style: self.presentationStyle)
                }
            }
        }
        #endif

        // If activated by tapping a move/invite card, skip the compact panel
        // and go straight to the expanded view — no extra tap required.
        if selectedMove != nil || selectedInvite != nil {
            requestPresentationStyle(.expanded)
        } else {
            presentView(for: conversation, style: presentationStyle)
        }
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        // Prefer invite card detection over move detection
        if let invite = GroupInvite.fromMessageURL(message.url) {
            selectedInvite = invite
            selectedMove   = nil
        } else {
            selectedMove   = move(from: message)
            selectedInvite = nil
        }
        requestPresentationStyle(.expanded)

        if presentationStyle == .expanded {
            removeAllChildren()
            presentView(for: conversation, style: .expanded)
        }
    }

    override func willSelect(_ message: MSMessage, conversation: MSConversation) {
        super.willSelect(message, conversation: conversation)
        if let invite = GroupInvite.fromMessageURL(message.url) {
            selectedInvite = invite
            selectedMove = nil
            return
        }
        selectedMove = move(from: message)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        removeAllChildren()
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        guard let conversation = activeConversation else { return }
        // selectedMessage can become available after the transition — grab it one more time
        if selectedMove == nil, selectedInvite == nil {
            selectedMove   = move(from: conversation.selectedMessage)
            selectedInvite = GroupInvite.fromMessageURL(conversation.selectedMessage?.url)
        }
        presentView(for: conversation, style: presentationStyle)
    }

    // MARK: - Presentation logic

    private func presentView(for conversation: MSConversation, style: MSMessagesAppPresentationStyle) {
        let selectedMessage = conversation.selectedMessage

        // ── Group invite card tapped ─────────────────────────────────────────
        if let invite = selectedInvite ?? GroupInvite.fromMessageURL(selectedMessage?.url) {
            selectedInvite = invite
            if style == .expanded {
                let vc = makeHostingController(for: GroupInviteReceivedView(
                    invite: invite,
                    onJoin: { [weak self] in
                        self?.openInviteInApp(invite)
                    },
                    onDismiss: { [weak self] in
                        self?.dismiss()
                    }
                ))
                embed(vc)
            } else {
                // Compact — show minimal "tap to join" preview
                let vc = makeHostingController(for: CompactInvitePreviewView(invite: invite) { [weak self] in
                    self?.requestPresentationStyle(.expanded)
                })
                embed(vc)
            }
            return
        }

        // ── Move RSVP / create flow ──────────────────────────────────────────
        if let move = move(from: selectedMessage) { selectedMove = move }

        if style == .compact {
            if showingInvitePicker {
                let vc = makeHostingController(for: GroupInvitePickerView(
                    groups: cachedGroups,
                    onSelect: { [weak self] entry in
                        self?.sendInvite(for: entry, in: conversation)
                    },
                    onBack: { [weak self] in
                        self?.showingInvitePicker = false
                        self?.removeAllChildren()
                        self?.presentView(for: conversation, style: .compact)
                    }
                ))
                embed(vc)
            } else if let move = selectedMove ?? cachedMoves.first ?? cachedMove {
                // Show the most recent move (from tapping a card, from Supabase, or from
                // the local SharedGroupStore cache) so the user can tap once to RSVP —
                // no card in the thread required, and no async loading needed.
                let vc = makeHostingController(for: CompactSelectedMoveView(move: move) { [weak self] in
                    self?.selectedMove = move
                    self?.requestPresentationStyle(.expanded)
                })
                embed(vc)
            } else {
                let vc = CompactMoveViewController()
                vc.groups = cachedGroups
                vc.onExpand = { [weak self] in
                    self?.isCreatingMove = true
                    self?.requestPresentationStyle(.expanded)
                }
                vc.onInvite = { [weak self] in
                    self?.showingInvitePicker = true
                    self?.removeAllChildren()
                    self?.presentView(for: conversation, style: .compact)
                }
                embed(vc)
            }
        } else {
            // Expanded — three explicit cases only. No fallback to create.

            // 1. User explicitly tapped "send a move"
            if isCreatingMove {
                let groups = cachedGroups
                let uid = currentUserID
                let createVC = makeHostingController(for: CreateMoveView(
                    groups: groups,
                    currentUserID: uid
                ) { [weak self] move, groupEntry in
                    self?.isCreatingMove = false
                    self?.insert(move: move, groupEntry: groupEntry, into: conversation)
                })
                embed(createVC)
                return
            }

            // 2. A move to RSVP to: from tapping a card, Supabase fetch, or local cache.
            // Use currentUserID (Supabase UUID) as the participant so RSVPs from the
            // extension always key consistently with the main app.
            if let move = move(from: selectedMessage) ?? selectedMove ?? cachedMoves.first ?? cachedMove {
                selectedMove = move
                let participantID = currentUserID ?? conversation.localParticipantIdentifier
                let rsvpVC = makeHostingController(for: MoveRSVPExtensionView(
                    move: move,
                    participants: participants(for: conversation),
                    currentParticipantID: participantID
                ) { [weak self] status in
                    self?.send(rsvp: status, for: move, in: conversation)
                })
                embed(rsvpVC)
                return
            }

            // 3. Nothing to show in expanded — collapse back to compact.
            requestPresentationStyle(.compact)
        }
    }

    // MARK: - Group invite sending

    private func sendInvite(for entry: SharedGroupStore.Entry, in conversation: MSConversation) {
        let invite = GroupInvite(
            threadKey: entry.threadKey,
            groupName: entry.name,
            memberCount: entry.memberCount
        )
        guard let url = invite.asURL() else { return }

        let message = MSMessage(session: MSSession())
        let layout  = MSMessageTemplateLayout()
        layout.image        = FlakeInviteArtwork.inviteCard(groupName: entry.name, memberCount: entry.memberCount)
        layout.caption      = entry.name
        layout.subcaption   = "\(entry.memberCount) member\(entry.memberCount == 1 ? "" : "s") · tap to join"
        layout.trailingCaption = "flake."
        message.summaryText = "join my flake group \"\(entry.name)\""
        message.url         = url
        message.layout      = layout

        conversation.insert(message) { [weak self] error in
            if error == nil {
                DispatchQueue.main.async { self?.dismiss() }
            }
        }
    }

    private func openInviteInApp(_ invite: GroupInvite) {
        // Open the main Flake app via deep link so the user can join the group.
        // On iOS 14+ this works from an iMessage extension via extensionContext.
        let deepLink = URL(string: "flake://join/\(invite.threadKey)")!
        extensionContext?.open(deepLink, completionHandler: nil)
    }

    // MARK: - Move parsing

    private func move(from message: MSMessage?) -> Move? {
        if GroupInvite.fromMessageURL(message?.url) != nil { return nil }
        return Move.fromMessageURL(message?.url)
    }

    // MARK: - Embed helpers

    private func embed(_ child: UIViewController) {
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(child.view)
        child.didMove(toParent: self)
    }

    private func removeAllChildren() {
        children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        }
    }

    private func makeHostingController<V: View>(for view: V) -> UIViewController {
        UIHostingController(rootView: view.environment(\.flakeTheme, .sunset))
    }

    override func contentSizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: min(230, max(180, size.width * 0.56)))
    }

    // MARK: - Sending messages

    // Force: Always attach an image and minimize all layout fields for maximum card visibility in transcript.
    private func insert(move: Move, groupEntry: SharedGroupStore.Entry?, into conversation: MSConversation) {
        guard let url = move.asURL() else { return }
        let message = MSMessage(session: MSSession())
        let layout  = moveLayout(for: move, participants: participants(for: conversation))

        layout.caption         = displayTitle(for: move).isEmpty ? "Move" : displayTitle(for: move)
        layout.subcaption      = "leader +25 · \(move.location) · tap to RSVP"
        let trailing           = responseSummary(for: move, participants: participants(for: conversation))
        layout.trailingCaption = trailing.isEmpty ? "responses pending" : trailing
        if layout.image == nil { layout.image = FlakeMessageArtwork.moveIcon() }

        message.summaryText = "\(displayTitle(for: move)) · group leader locked in"
        message.url         = url
        message.layout      = layout
        selectedMove        = move

        conversation.insert(message) { [weak self] error in
            guard error == nil else { return }
            DispatchQueue.main.async { self?.dismiss() }

            // Persist to Supabase in background so the main app sees it
            #if canImport(Supabase)
            Task {
                await ExtensionGroupLoader.shared.createMove(
                    id: move.id,
                    groupID: move.groupID,
                    creatorID: move.creatorID,
                    title: move.title,
                    location: move.location,
                    date: move.date
                )
            }
            #endif
        }
    }

    // Force: Always attach an image and minimize all layout fields for maximum card visibility in transcript.
    private func send(rsvp: RSVPStatus, for move: Move, in conversation: MSConversation) {
        // Prefer the Supabase user UUID so RSVPs are consistent between the
        // extension and the main app, regardless of how the RSVP view was reached.
        let participantID = currentUserID ?? conversation.localParticipantIdentifier
        var updatedMove = move
        updatedMove.rsvps[participantID] = rsvp
        guard let url = updatedMove.asURL() else { return }

        let message = MSMessage(session: conversation.selectedMessage?.session ?? MSSession())
        let layout  = rsvpLayout(
            for: updatedMove,
            status: rsvp,
            participants: participants(for: conversation),
            currentParticipantID: participantID
        )
        
        // Restore original caption, subcaption, trailingCaption logic
        layout.caption = everyoneResponded(move: updatedMove, participants: participants(for: conversation)) ? "Everyone responded" : "RSVP \(rsvp.label)"
        layout.subcaption = "\(displayTitle(for: updatedMove)) · \(rsvp.receiptSubcaption)"
        let trailing = responseSummary(for: updatedMove, participants: participants(for: conversation))
        layout.trailingCaption = trailing.isEmpty ? "responses pending" : trailing
        
        if layout.image == nil {
            layout.image = FlakeMessageArtwork.moveIcon()
        }
        
        message.summaryText = "\(displayTitle(for: updatedMove)) · \(rsvp.label)"
        message.url    = url
        message.layout = layout
        selectedMove   = updatedMove

        conversation.insert(message) { [weak self] error in
            guard error == nil else { return }
            DispatchQueue.main.async { self?.dismiss() }

            // Persist RSVP to Supabase in background
            #if canImport(Supabase)
            guard let uid = self?.currentUserID else { return }
            let moveID = updatedMove.id
            let capturedRSVP = rsvp
            Task {
                await ExtensionGroupLoader.shared.submitRSVP(
                    moveID: moveID,
                    userID: uid,
                    status: capturedRSVP
                )
            }
            #endif
        }
    }

    private func moveLayout(for move: Move, participants: [MessageParticipant]) -> MSMessageTemplateLayout {
        let layout = MSMessageTemplateLayout()
        layout.image = FlakeMessageArtwork.moveCard(move: move, selectedStatus: nil, participants: participants)
        // Defensive: fallback captions
        let caption = displayTitle(for: move)
        layout.caption = caption.isEmpty ? "Move" : caption
        
        let subcaptionFallback = "leader +25 · \(move.location) · tap to RSVP"
        layout.subcaption = layout.subcaption?.isEmpty == false ? layout.subcaption : subcaptionFallback
        layout.subcaption = layout.subcaption ?? subcaptionFallback
        
        let trailing = responseSummary(for: move, participants: participants)
        layout.trailingCaption = trailing.isEmpty ? "responses pending" : trailing
        return layout
    }

    private func rsvpLayout(for move: Move, status: RSVPStatus, participants: [MessageParticipant], currentParticipantID: UUID) -> MSMessageTemplateLayout {
        let layout = MSMessageTemplateLayout()
        layout.image = FlakeMessageArtwork.moveCard(move: move, selectedStatus: status, participants: participants)
        
        let captionFallback = everyoneResponded(move: move, participants: participants) ? "Everyone responded" : "RSVP \(status.receiptAction)"
        layout.caption = captionFallback.isEmpty ? "RSVP" : captionFallback
        
        let subcaptionFallback = "\(displayTitle(for: move)) · \(status.receiptSubcaption)"
        layout.subcaption = subcaptionFallback.isEmpty ? "\(displayTitle(for: move))" : subcaptionFallback
        
        let trailingFallback = responseSummary(for: move, participants: participants)
        layout.trailingCaption = trailingFallback.isEmpty ? "responses pending" : trailingFallback
        
        return layout
    }

    private func displayTitle(for move: Move) -> String {
        let trimmedTitle = move.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty { return move.location }
        if trimmedTitle.localizedCaseInsensitiveContains(move.location) { return trimmedTitle }
        return trimmedTitle
    }

    private func participants(for conversation: MSConversation) -> [MessageParticipant] {
        let local = MessageParticipant(id: conversation.localParticipantIdentifier, label: "you", isMe: true)
        let remoteIDs = conversation.remoteParticipantIdentifiers
        let remotes = remoteIDs.enumerated().map { index, id in
            let label = remoteIDs.count == 1 ? "friend" : "friend \(index + 1)"
            return MessageParticipant(id: id, label: label, isMe: false)
        }
        return [local] + remotes
    }

    private func responseSummary(for move: Move, participants: [MessageParticipant]) -> String {
        if everyoneResponded(move: move, participants: participants) {
            return "everyone responded"
        }
        let locked = move.rsvps.values.filter { $0 == .lockedIn }.count
        let maybe = move.rsvps.values.filter { $0 == .sendingIt }.count
        let out = move.rsvps.values.filter { $0 == .flaked }.count
        return "\(locked) yes · \(maybe) maybe · \(out) out"
    }

    private func everyoneResponded(move: Move, participants: [MessageParticipant]) -> Bool {
        !participants.isEmpty && participants.allSatisfy { move.rsvps[$0.id] != nil }
    }
}

private extension RSVPStatus {
    var receiptAction: String {
        switch self {
        case .lockedIn: return "locked in"
        case .sendingIt: return "maybe"
        case .flaked: return "flaked"
        case .silent: return "updated"
        }
    }

    var receiptSubcaption: String {
        switch self {
        case .lockedIn: return "tap to see the lineup"
        case .sendingIt: return "tap to nudge the group"
        case .flaked: return "tap to see the damage"
        case .silent: return "tap to RSVP"
        }
    }

    func receiptTrailingCaption(existingLockedIn: Int) -> String {
        switch self {
        case .lockedIn:
            return "\(max(1, existingLockedIn + 1)) locked in"
        case .sendingIt:
            return "sending it"
        case .flaked:
            return "out"
        case .silent:
            return "tap to RSVP"
        }
    }
}

private enum FlakeMessageArtwork {
    static func writeTemporaryPNG(_ image: UIImage, name: String) -> URL? {
        guard let data = image.pngData() else { return nil }
        let safeName = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("flake-\(safeName).png")

        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
    }

    static func moveCard(move: Move, selectedStatus: RSVPStatus?, participants: [MessageParticipant]) -> UIImage {
        let size = CGSize(width: 600, height: 360)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let cgColors = [
                UIColor(hex: "0a0612").cgColor,
                UIColor(hex: "27152b").cgColor,
                statusColor(selectedStatus ?? .silent).withAlphaComponent(0.78).cgColor
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: [0, 0.55, 1])

            context.cgContext.saveGState()
            UIBezierPath(roundedRect: rect, cornerRadius: 44).addClip()
            context.cgContext.drawLinearGradient(
                gradient!,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            UIColor.white.withAlphaComponent(0.1).setStroke()
            UIBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: 42).stroke()
            context.cgContext.restoreGState()

            drawText("flake.", in: CGRect(x: 36, y: 28, width: 180, height: 30), size: 22, weight: .semibold, color: UIColor(hex: "ff8c42"), italic: true)
            let statusLine = selectedStatus.map { "your RSVP: \($0.label)" } ?? "leader +25 · tap to RSVP"
            drawText(statusLine.uppercased(), in: CGRect(x: 250, y: 31, width: 310, height: 24), size: 16, weight: .semibold, color: UIColor.white.withAlphaComponent(0.56), alignment: .right, mono: true)

            drawText(move.title, in: CGRect(x: 36, y: 82, width: 520, height: 86), size: 46, weight: .regular, color: .white, serif: true)
            drawText(move.location, in: CGRect(x: 38, y: 162, width: 520, height: 30), size: 20, weight: .medium, color: UIColor.white.withAlphaComponent(0.72), mono: true)

            let responded = participants.filter { move.rsvps[$0.id] != nil }.count
            let allDone = !participants.isEmpty && responded == participants.count
            drawText(allDone ? "EVERYONE RESPONDED" : "\(responded)/\(participants.count) RESPONDED", in: CGRect(x: 38, y: 200, width: 520, height: 24), size: 17, weight: .bold, color: allDone ? UIColor(hex: "66e0a3") : UIColor.white.withAlphaComponent(0.52), mono: true)

            let pillY: CGFloat = 248
            let pillW: CGFloat = 160
            let gap: CGFloat = 18
            drawOptionPill(label: "yes", status: .lockedIn, selectedStatus: selectedStatus, rect: CGRect(x: 36, y: pillY, width: pillW, height: 66))
            drawOptionPill(label: "maybe", status: .sendingIt, selectedStatus: selectedStatus, rect: CGRect(x: 36 + pillW + gap, y: pillY, width: pillW, height: 66))
            drawOptionPill(label: "flake", status: .flaked, selectedStatus: selectedStatus, rect: CGRect(x: 36 + (pillW + gap) * 2, y: pillY, width: pillW, height: 66))
        }
    }

    static func moveIcon() -> UIImage {
        renderBadge(text: "f.", colors: [UIColor(hex: "ff6b9d"), UIColor(hex: "ff8c42"), UIColor(hex: "ffd166")])
    }

    static func rsvpIcon(status: RSVPStatus) -> UIImage {
        let text: String
        let colors: [UIColor]
        switch status {
        case .lockedIn:
            text = "in"
            colors = [UIColor(hex: "66e0a3"), UIColor(hex: "ff8c42")]
        case .sendingIt:
            text = "?"
            colors = [UIColor(hex: "ffd166"), UIColor(hex: "ff8c42")]
        case .flaked:
            text = "out"
            colors = [UIColor(hex: "ff5a7a"), UIColor(hex: "b56bff")]
        case .silent:
            text = "f."
            colors = [UIColor(hex: "ff6b9d"), UIColor(hex: "ff8c42")]
        }
        return renderBadge(text: text, colors: colors)
    }

    private static func drawOptionPill(label: String, status: RSVPStatus, selectedStatus: RSVPStatus?, rect: CGRect) {
        let selected = selectedStatus == status
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 24)
        (selected ? statusColor(status) : UIColor.white.withAlphaComponent(0.08)).setFill()
        path.fill()
        (selected ? UIColor.white.withAlphaComponent(0.82) : UIColor.white.withAlphaComponent(0.14)).setStroke()
        path.lineWidth = selected ? 2 : 1
        path.stroke()

        drawText(label.uppercased(), in: rect.insetBy(dx: 12, dy: 20), size: 18, weight: .bold, color: selected && status == .lockedIn ? UIColor(hex: "062511") : .white, alignment: .center, mono: true)
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        size: CGFloat,
        weight: UIFont.Weight,
        color: UIColor,
        alignment: NSTextAlignment = .left,
        mono: Bool = false,
        serif: Bool = false,
        italic: Bool = false
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let baseFont: UIFont
        if mono {
            baseFont = UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        } else if serif {
            baseFont = UIFont(descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle).withDesign(.serif) ?? UIFontDescriptor(), size: size)
        } else {
            baseFont = UIFont.systemFont(ofSize: size, weight: weight)
        }
        let font = italic ? (UIFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) ?? baseFont.fontDescriptor, size: size)) : baseFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        NSString(string: text).draw(in: rect, withAttributes: attributes)
    }

    private static func statusColor(_ status: RSVPStatus) -> UIColor {
        switch status {
        case .lockedIn: return UIColor(hex: "66e0a3")
        case .sendingIt: return UIColor(hex: "ffd166")
        case .flaked: return UIColor(hex: "ff5a7a")
        case .silent: return UIColor(hex: "ff6b9d")
        }
    }

    private static func renderBadge(text: String, colors: [UIColor]) -> UIImage {
        let size = CGSize(width: 96, height: 96)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let cgColors = colors.map(\.cgColor) as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil)

            context.cgContext.saveGState()
            UIBezierPath(roundedRect: rect, cornerRadius: 26).addClip()
            context.cgContext.drawLinearGradient(
                gradient!,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            UIColor.white.withAlphaComponent(0.16).setStroke()
            UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 25).stroke()
            context.cgContext.restoreGState()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: text.count > 2 ? 28 : 34, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            let textRect = CGRect(x: 0, y: 29, width: size.width, height: 40)
            NSString(string: text).draw(in: textRect, withAttributes: attributes)
        }
    }
}

private extension UIColor {
    convenience init(hex: String) {
        var hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Compact panel

final class CompactMoveViewController: UIViewController {
    var groups: [SharedGroupStore.Entry] = []
    var onExpand: (() -> Void)?
    var onInvite: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Color.flakeBG)
        let hostingVC = UIHostingController(
            rootView: CompactBubbleView(
                groups: groups,
                onExpand: { [weak self] in self?.onExpand?() },
                onInvite: { [weak self] in self?.onInvite?() }
            )
            .environment(\.flakeTheme, .sunset)
        )
        addChild(hostingVC)
        hostingVC.view.frame = view.bounds
        hostingVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingVC.view.backgroundColor = .clear
        view.addSubview(hostingVC.view)
        hostingVC.didMove(toParent: self)
    }
}

final class TranscriptCardViewController: UIViewController {
    private let image: UIImage
    private let onTap: () -> Void

    init(image: UIImage, onTap: @escaping () -> Void) {
        self.image = image
        self.onTap = onTap
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerCurve = .continuous
        imageView.layer.cornerRadius = 24
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        onTap()
    }
}
