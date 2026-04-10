import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let socialService: SocialService
    let webService: WebFeatureService

    var discoverEventsRepository: DiscoverEventsRepository {
        DiscoverEventsRepositoryAdapter(service: webService)
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
        DiscoverWikiRepositoryAdapter(service: webService)
    }

    var messagesRepository: MessagesRepository {
        MessagesRepositoryAdapter(service: socialService)
    }

    var circleFeedRepository: CircleFeedRepository {
        CircleFeedRepositoryAdapter(service: socialService)
    }

    var profileSocialRepository: ProfileSocialRepository {
        ProfileSocialRepositoryAdapter(
            socialService: socialService,
            webService: webService
        )
    }

    init(
        socialService: SocialService = AppEnvironment.makeService(),
        webService: WebFeatureService = AppEnvironment.makeWebService()
    ) {
        self.socialService = socialService
        self.webService = webService
    }
}
