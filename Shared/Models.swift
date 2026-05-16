import Foundation

// MARK: - RSVP

enum RSVPStatus: String, Codable, CaseIterable {
    case lockedIn   = "locked_in"
    case sendingIt  = "sending_it"
    case flaked     = "flaked"
    case silent     = "silent"

    var label: String {
        switch self {
        case .lockedIn:  return "locked in"
        case .sendingIt: return "sending it"
        case .flaked:    return "flaked"
        case .silent:    return "—"
        }
    }

    var emoji: String {
        switch self {
        case .lockedIn:  return "⚡"
        case .sendingIt: return "🤞"
        case .flaked:    return "💀"
        case .silent:    return "—"
        }
    }

    var pointsDelta: Int {
        switch self {
        case .lockedIn:  return 15
        case .sendingIt: return 5
        case .flaked:    return -5
        case .silent:    return 0
        }
    }
}

// MARK: - Attendance

enum AttendanceStatus: String, Codable, CaseIterable {
    case showed
    case missed

    var label: String {
        switch self {
        case .showed: return "showed"
        case .missed: return "missed"
        }
    }
}

// MARK: - Member

struct Member: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var handle: String
    var initials: String
    var avatarColorHex: String
    var score: Int
    var flakeCount: Int
    var showCount: Int
    var badges: [Badge]

    struct Badge: Codable, Hashable {
        var name: String
        var isGold: Bool
    }

    var showRate: Double {
        guard showCount + flakeCount > 0 else { return 0 }
        return Double(showCount) / Double(showCount + flakeCount)
    }

    var tagline: String {
        switch showRate {
        case 0.9...:  return "shows up every time"
        case 0.75...: return "shows up most of the time"
        case 0.5...:  return "a coin flip, honestly"
        default:      return "a cautionary tale"
        }
    }
}

// MARK: - Move

struct Move: Identifiable, Codable {
    let id: UUID
    var title: String
    var subtitle: String
    var location: String
    var date: Date
    var creatorID: UUID
    var rsvps: [UUID: RSVPStatus]
    var groupID: UUID
    var attendance: [UUID: AttendanceStatus] = [:]

    var lockedInCount: Int  { rsvps.values.filter { $0 == .lockedIn  }.count }
    var sendingItCount: Int { rsvps.values.filter { $0 == .sendingIt }.count }
    var flakedCount: Int    { rsvps.values.filter { $0 == .flaked    }.count }
    var isSettled: Bool { !attendance.isEmpty }

    func flakePenalty(for memberID: UUID) -> Int {
        memberID == creatorID ? 25 : 15
    }

    func pointDelta(for memberID: UUID, excusedApproved: Bool, attendance override: AttendanceStatus? = nil) -> Int {
        let actual = override ?? attendance[memberID]
        if let actual {
            switch actual {
            case .showed:
                let rsvp = rsvps[memberID] ?? .silent
                let showPoints = rsvp == .sendingIt ? 5 : 15
                return showPoints + (memberID == creatorID ? 25 : 0)
            case .missed:
                return excusedApproved ? 0 : -flakePenalty(for: memberID)
            }
        }

        switch rsvps[memberID] ?? .silent {
        case .lockedIn:
            return 15 + (memberID == creatorID ? 25 : 0)
        case .sendingIt:
            return 5
        case .flaked:
            return excusedApproved ? 0 : -flakePenalty(for: memberID)
        case .silent:
            return 0
        }
    }
}

// MARK: - FlakeGroup

struct FlakeGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var members: [Member]
    var moves: [Move]
    var season: Int
    var userRank: Int
    var userScore: Int
    var userScoreGoal: Int
    var ranksSubtitle: String
    var nextSummary: String

    var currentMove: Move? {
        moves
            .filter { $0.date >= Date() }
            .sorted { $0.date < $1.date }
            .first ?? moves.sorted { $0.date > $1.date }.first
    }
}

// MARK: - Roast

struct Roast: Identifiable {
    let id: UUID
    var targetName: String
    var text: String
    var timeAgo: String
    var reactions: [Reaction]

    struct Reaction: Identifiable {
        let id = UUID()
        var emoji: String
        var count: Int
        var isHot: Bool
    }
}

// MARK: - ExcusedVote

struct ExcusedVote: Identifiable {
    let id: UUID
    var petitioner: Member
    var move: Move
    var excuse: String
    var approvers: [Member]
    var deniers: [Member]
    var closesAt: Date
    var pointsAtRisk: Int
    var outcome: ExcusedVoteOutcome = .pending

    var approvalCount: Int { approvers.count }
    var denyCount: Int     { deniers.count }
    var totalVotes: Int    { approvers.count + deniers.count }
    var approvalFraction: Double {
        guard totalVotes > 0 else { return 0 }
        return Double(approvalCount) / Double(totalVotes)
    }
    var isApproved: Bool { outcome == .approved }
}

enum ExcusedVoteChoice {
    case approve
    case deny
}

enum ExcusedVoteOutcome {
    case pending
    case approved
    case denied
}

// MARK: - Season

struct Season: Codable {
    var number: Int
    var totalWeeks: Int
    var currentWeek: Int
    var champion: Member?
    var biggestFlake: Member?
}

// MARK: - Move URL encoding (shared between app & extension)

extension Move {
    static let urlScheme = "flake"

    static var transcriptFallback: Move {
        var move = Move(
            id: UUID(),
            title: "new move",
            subtitle: "",
            location: "tap to RSVP",
            date: Date(),
            creatorID: UUID(),
            rsvps: [:],
            groupID: UUID()
        )
        move.rsvps[move.creatorID] = .lockedIn
        return move
    }

    /// Encodes move identity into a URL for MSMessage
    func asURL() -> URL? {
        var components = URLComponents()
        components.scheme = Move.urlScheme
        components.host   = "move"
        var queryItems = [
            URLQueryItem(name: "id",       value: id.uuidString),
            URLQueryItem(name: "title",    value: title),
            URLQueryItem(name: "location", value: location),
            URLQueryItem(name: "date",     value: ISO8601DateFormatter().string(from: date)),
            URLQueryItem(name: "group",    value: groupID.uuidString),
            URLQueryItem(name: "creator",  value: creatorID.uuidString),
        ]
        queryItems.append(contentsOf: rsvps.map { id, status in
            URLQueryItem(name: "r_\(id.uuidString)", value: status.rawValue)
        })
        components.queryItems = queryItems
        return components.url
    }

    static func fromURL(_ url: URL) -> Move? {
        guard url.scheme == Move.urlScheme,
              url.host == "move",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return nil }
        func q(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard let idStr  = q("id"),   let id       = UUID(uuidString: idStr),
              let title  = q("title"),
              let loc    = q("location"),
              let dateStr = q("date"), let date = ISO8601DateFormatter().date(from: dateStr),
              let gidStr = q("group"), let gid  = UUID(uuidString: gidStr) else { return nil }
        let creatorID = q("creator").flatMap(UUID.init(uuidString:)) ?? UUID()
        let rsvps = items.reduce(into: [UUID: RSVPStatus]()) { result, item in
            guard item.name.hasPrefix("r_"),
                  let value = item.value,
                  let participantID = UUID(uuidString: String(item.name.dropFirst(2))),
                  let status = RSVPStatus(rawValue: value) else { return }
            result[participantID] = status
        }
        return Move(id: id, title: title, subtitle: "", location: loc, date: date,
                    creatorID: creatorID, rsvps: rsvps, groupID: gid)
    }

    static func fromMessageURL(_ url: URL?) -> Move? {
        guard let url else { return nil }
        if let move = fromURL(url) { return move }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return nil }

        func q(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard let title = q("title") ?? q("event") ?? q("caption") else { return nil }

        let id = q("id").flatMap(UUID.init(uuidString:)) ?? UUID()
        let location = q("location") ?? q("loc") ?? q("where") ?? "the move"
        let date = q("date").flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        let groupID = q("group").flatMap(UUID.init(uuidString:)) ?? UUID()

        let creatorID = q("creator").flatMap(UUID.init(uuidString:)) ?? UUID()
        let rsvps = items.reduce(into: [UUID: RSVPStatus]()) { result, item in
            guard item.name.hasPrefix("r_"),
                  let value = item.value,
                  let participantID = UUID(uuidString: String(item.name.dropFirst(2))),
                  let status = RSVPStatus(rawValue: value) else { return }
            result[participantID] = status
        }

        return Move(id: id, title: title, subtitle: "", location: location, date: date,
                    creatorID: creatorID, rsvps: rsvps, groupID: groupID)
    }
}
