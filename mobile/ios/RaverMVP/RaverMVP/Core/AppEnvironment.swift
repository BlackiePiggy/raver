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

    static let sharedWebService: WebFeatureService = {
        switch AppConfig.runtimeMode {
        case .mock:
            return MockWebFeatureService()
        case .live:
            return LiveWebFeatureService(baseURL: AppConfig.bffBaseURL)
        }
    }()

    static let sharedShareLinkService: ShareLinkService = {
        switch AppConfig.runtimeMode {
        case .mock:
            return MockShareLinkService()
        case .live:
            return LiveShareLinkService(baseURL: AppConfig.bffBaseURL)
        }
    }()

    static func makeVirtualAssetRepository() -> VirtualAssetRepository {
        guard AppConfig.virtualAssetsEnabled else {
            return DisabledVirtualAssetRepository()
        }
        switch AppConfig.runtimeMode {
        case .mock:
            return MockVirtualAssetRepository()
        case .live:
            return LiveVirtualAssetRepository(baseURL: AppConfig.bffBaseURL)
        }
    }

    static func makeService() -> SocialService {
        sharedService
    }

    static func makeWebService() -> WebFeatureService {
        sharedWebService
    }

    static func makeShareLinkService() -> ShareLinkService {
        sharedShareLinkService
    }

    static func makeShareLinkRepository() -> ShareLinkRepository {
        ShareLinkRepositoryAdapter(service: sharedShareLinkService)
    }

}
