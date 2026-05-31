import Foundation

enum CardioHubRoute: Hashable {
    case history
    case goals
    case bests
    case completed(CardioSession.ID)
}

enum HomeRoute: Hashable {
    case planDetail
}
