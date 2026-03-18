import Foundation

enum AppEnvironment {
    static let sharedService: SocialService = {
        switch AppConfig.runtimeMode {
        case .mock:
            return MockSocialService()
        case .live:
            return LiveSocialService(baseURL: AppConfig.bffBaseURL)
        }
    }()

    static func makeService() -> SocialService {
        sharedService
    }
}
