import Foundation

struct BackendProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var initials: String
    var avatarColor: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case initials
        case avatarColor = "avatar_color"
        case createdAt   = "created_at"
    }
}

struct BackendGroup: Codable, Identifiable, Hashable {
    let id: UUID
    var threadKey: String?
    var name: String
    var createdBy: UUID?
    var createdAt: Date?
    var seasonNumber: Int?
    var seasonWeeks: Int?
    var seasonStartedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case threadKey      = "thread_key"
        case name
        case createdBy      = "created_by"
        case createdAt      = "created_at"
        case seasonNumber   = "season_number"
        case seasonWeeks    = "season_weeks"
        case seasonStartedAt = "season_started_at"
    }
}

struct BackendGroupMember: Codable {
    var groupID: UUID
    var userID: UUID

    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case userID = "user_id"
    }
}

struct BackendMove: Codable, Identifiable, Hashable {
    let id: UUID
    var groupID: UUID
    var title: String
    var subtitle: String
    var locationName: String
    var locationLatitude: Double?
    var locationLongitude: Double?
    var startsAt: Date
    var creatorID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case title
        case subtitle
        case locationName = "location_name"
        case locationLatitude = "location_lat"
        case locationLongitude = "location_lng"
        case startsAt = "starts_at"
        case creatorID = "creator_id"
    }
}

struct BackendRSVP: Codable, Hashable {
    var moveID: UUID
    var userID: UUID
    var status: String

    enum CodingKeys: String, CodingKey {
        case moveID = "move_id"
        case userID = "user_id"
        case status
    }
}

struct BackendAttendance: Codable, Hashable {
    var moveID: UUID
    var userID: UUID
    var status: String

    enum CodingKeys: String, CodingKey {
        case moveID = "move_id"
        case userID = "user_id"
        case status
    }
}

/// Matches the `excused_votes` table — one row per excused-absence request.
struct BackendExcusedVote: Codable, Identifiable, Hashable {
    let id: UUID
    var moveID: UUID
    var petitionerID: UUID
    var reason: String
    var status: String          // "pending" | "approved" | "denied"
    var pointsAtRisk: Int
    var closesAt: Date
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case moveID       = "move_id"
        case petitionerID = "petitioner_id"
        case reason
        case status
        case pointsAtRisk = "points_at_risk"
        case closesAt     = "closes_at"
        case createdAt    = "created_at"
    }
}

/// Matches the `excused_vote_ballots` table — individual votes on an excused request.
struct BackendExcusedBallot: Codable, Hashable {
    var voteID: UUID
    var voterID: UUID
    var choice: String          // "approve" | "deny"

    enum CodingKeys: String, CodingKey {
        case voteID  = "vote_id"
        case voterID = "voter_id"
        case choice
    }
}

// MARK: - Roast Reactions

struct BackendRoastReaction: Codable, Hashable {
    var groupID:      UUID
    var targetUserID: UUID
    var season:       Int
    var emoji:        String
    var reactorID:    UUID

    enum CodingKeys: String, CodingKey {
        case groupID      = "group_id"
        case targetUserID = "target_user_id"
        case season
        case emoji
        case reactorID    = "reactor_id"
    }
}

// MARK: - Assembled snapshot returned by loadAllData

struct BackendSnapshot {
    var groups: [BackendGroup]
    var membersByGroup: [UUID: [BackendProfile]]       // group_id → profiles
    var movesByGroup: [UUID: [BackendMove]]            // group_id → moves
    var rsvpsByMove: [UUID: [BackendRSVP]]             // move_id  → rsvps
    var attendanceByMove: [UUID: [BackendAttendance]]  // move_id  → attendance rows
    var excusedVotesByMove: [UUID: BackendExcusedVote] // move_id  → single excused request
    var ballotsByVote: [UUID: [BackendExcusedBallot]]  // vote_id  → ballots
}
