import Foundation

struct BackendProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var initials: String
    var avatarColor: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case initials
        case avatarColor = "avatar_color"
    }
}

struct BackendGroup: Codable, Identifiable, Hashable {
    let id: UUID
    var threadKey: String?
    var name: String
    var createdBy: UUID?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case threadKey = "thread_key"
        case name
        case createdBy = "created_by"
        case createdAt = "created_at"
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
