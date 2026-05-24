import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Compact picker (sender side — shown in app strip)

/// Shown in compact mode when user taps "invite friends →".
/// Lists groups stored in the shared container so the user can pick one.
struct GroupInvitePickerView: View {
    let groups: [SharedGroupStore.Entry]
    let onSelect: (SharedGroupStore.Entry) -> Void
    let onBack: () -> Void

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Text("‹")
                        Text("back")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Text("invite to group")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if groups.isEmpty {
                VStack(spacing: 6) {
                    Text("no groups yet.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Text("create one in the flake app first.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(groups) { entry in
                            Button { onSelect(entry) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text("\(entry.memberCount) member\(entry.memberCount == 1 ? "" : "s")")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.07))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }
        }
        .background(Color.flakeBG)
    }
}

// MARK: - Expanded invite card (recipient side — shown when tapping the message card)

/// Shown in expanded mode when the recipient taps a group invite card.
struct GroupInviteReceivedView: View {
    let invite: GroupInvite
    let onJoin: () -> Void      // opens flake://join/KEY in the main app
    let onDismiss: () -> Void

    @Environment(\.flakeTheme) private var theme

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()

            // gradient blob
            RadialGradient(
                colors: [theme.g1.opacity(0.35), .clear],
                center: .init(x: 0.5, y: 0.1),
                startRadius: 0,
                endRadius: 260
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // App tag
                HStack {
                    Text("flake.")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .italic()
                        .foregroundStyle(theme.gradient2)
                    Spacer()
                    Text("group invite")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .padding(.bottom, 24)

                Text("you're invited to")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.bottom, 4)

                Text(invite.groupName)
                    .font(.system(size: 38, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                Text("\(invite.memberCount) member\(invite.memberCount == 1 ? "" : "s") · one leaderboard")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.bottom, 28)

                // Join button
                Button(action: onJoin) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("join in flake")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("opens the flake app")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        Spacer()
                        Text("→")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                    }
                    .padding(18)
                    .background(theme.gradient2)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: theme.g1.opacity(0.3), radius: 16, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)

                Button(action: onDismiss) {
                    Text("maybe later")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(28)
        }
    }
}

// MARK: - Invite card image (used for MSMessageTemplateLayout.image)

import UIKit

enum FlakeInviteArtwork {
    static func inviteCard(groupName: String, memberCount: Int) -> UIImage {
        let size = CGSize(width: 600, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)

            // Background gradient
            let cgColors = [
                UIColor(hex: "0a0612").cgColor,
                UIColor(hex: "1a0a2e").cgColor,
                UIColor(hex: "2d1b4e").cgColor,
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: cgColors,
                locations: [0, 0.5, 1]
            ) {
                context.cgContext.saveGState()
                UIBezierPath(roundedRect: rect, cornerRadius: 44).addClip()
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
                // Border
                UIColor.white.withAlphaComponent(0.1).setStroke()
                UIBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: 42).stroke()
                context.cgContext.restoreGState()
            }

            // "flake." app tag
            drawText("flake.", in: CGRect(x: 36, y: 28, width: 200, height: 30),
                     size: 22, weight: .semibold, color: UIColor(hex: "ff8c42"), italic: true)

            // "GROUP INVITE" badge
            drawText("GROUP INVITE", in: CGRect(x: 300, y: 31, width: 260, height: 24),
                     size: 13, weight: .bold, color: UIColor.white.withAlphaComponent(0.45),
                     alignment: .right, mono: true)

            // Group name
            drawText(groupName, in: CGRect(x: 36, y: 80, width: 530, height: 100),
                     size: 44, weight: .regular, color: .white, serif: true)

            // Member count
            let sub = "\(memberCount) member\(memberCount == 1 ? "" : "s") · tap to join"
            drawText(sub, in: CGRect(x: 38, y: 182, width: 530, height: 28),
                     size: 16, weight: .medium, color: UIColor.white.withAlphaComponent(0.55),
                     mono: true)

            // CTA pill
            let pillRect = CGRect(x: 36, y: 224, width: 220, height: 52)
            let path = UIBezierPath(roundedRect: pillRect, cornerRadius: 18)
            UIColor(hex: "7c3aed").withAlphaComponent(0.9).setFill()
            path.fill()
            drawText("join the crew →", in: pillRect.insetBy(dx: 16, dy: 14),
                     size: 15, weight: .semibold, color: .white, alignment: .center)
        }
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
        let para = NSMutableParagraphStyle()
        para.alignment = alignment
        para.lineBreakMode = .byTruncatingTail
        var baseFont: UIFont
        if mono {
            baseFont = UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        } else if serif {
            baseFont = UIFont(
                descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
                    .withDesign(.serif) ?? UIFontDescriptor(),
                size: size
            )
        } else {
            baseFont = UIFont.systemFont(ofSize: size, weight: weight)
        }
        if italic, let desc = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) {
            baseFont = UIFont(descriptor: desc, size: size)
        }
        NSString(string: text).draw(in: rect, withAttributes: [
            .font: baseFont,
            .foregroundColor: color,
            .paragraphStyle: para,
        ])
    }
}

private extension UIColor {
    convenience init(hex: String) {
        var hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(
            red:   CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >>  8) & 0xFF) / 255,
            blue:  CGFloat( v        & 0xFF) / 255,
            alpha: 1
        )
    }
}
