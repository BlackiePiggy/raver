import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let socialService: SocialService
    let webService: WebFeatureService
    let virtualAssetRepository: VirtualAssetRepository

    var discoverEventsRepository: DiscoverEventsRepository {
        DiscoverEventsRepositoryAdapter(
            service: webService,
            socialService: socialService
        )
    }

    var discoverNewsRepository: DiscoverNewsRepository {
        DiscoverNewsRepositoryAdapter(
            socialService: socialService,
            webService: webService
        )
    }

    var discoverDJsRepository: DiscoverDJsRepository {
        DiscoverDJsRepositoryAdapter(service: webService)
    }

    var discoverSetsRepository: DiscoverSetsRepository {
        DiscoverSetsRepositoryAdapter(service: webService)
    }

    var discoverWikiRepository: DiscoverWikiRepository {
        DiscoverWikiRepositoryAdapter(
            service: webService,
            socialService: socialService
        )
    }

    var messagesRepository: MessagesRepository {
        MessagesRepositoryAdapter(service: socialService)
    }

    var notificationRepository: NotificationRepository {
        NotificationRepositoryAdapter(service: socialService)
    }

    var shareMessageRepository: ShareMessageRepository {
        ShareMessageRepositoryAdapter(service: socialService)
    }

    var circleFeedRepository: CircleFeedRepository {
        CircleFeedRepositoryAdapter(
            socialService: socialService,
            webService: webService
        )
    }

    var globalSearchRepository: GlobalSearchRepository {
        GlobalSearchRepositoryAdapter(service: webService)
    }

    var squadProfileRepository: SquadProfileRepository {
        SquadProfileRepositoryAdapter(
            socialService: socialService,
            webService: webService
        )
    }

    var profileSocialRepository: ProfileSocialRepository {
        ProfileSocialRepositoryAdapter(
            socialService: socialService,
            webService: webService
        )
    }

    init(
        socialService: SocialService = AppEnvironment.makeService(),
        webService: WebFeatureService = AppEnvironment.makeWebService(),
        virtualAssetRepository: VirtualAssetRepository = AppEnvironment.makeVirtualAssetRepository()
    ) {
        self.socialService = socialService
        self.webService = webService
        self.virtualAssetRepository = virtualAssetRepository
    }
}
