import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let socialService: SocialService
    let webService: WebFeatureService
    let virtualAssetRepository: VirtualAssetRepository

    var eventListRepository: EventListRepository {
        EventListRepositoryAdapter(service: webService)
    }

    var eventRecommendationRepository: EventRecommendationRepository {
        EventRecommendationRepositoryAdapter(service: webService)
    }

    var eventReadRepository: EventReadRepository {
        EventReadRepositoryAdapter(service: webService)
    }

    var eventLiveDiscussionRepository: EventLiveDiscussionRepository {
        EventLiveDiscussionRepositoryAdapter(service: socialService)
    }

    var eventCommandRepository: EventCommandRepository {
        EventCommandRepositoryAdapter(service: webService)
    }

    var eventMediaRepository: EventMediaRepository {
        EventMediaRepositoryAdapter(service: webService)
    }

    var eventDiscussionMediaRepository: EventDiscussionMediaRepository {
        EventMediaRepositoryAdapter(service: webService)
    }

    var eventCheckinRepository: EventCheckinRepository {
        EventCheckinRepositoryAdapter(service: webService)
    }

    var eventRelatedContentRepository: EventRelatedContentRepository {
        EventRelatedContentRepositoryAdapter(service: webService)
    }

    var ratingRepository: RatingRepository {
        RatingRepositoryAdapter(service: webService)
    }

    var discoverNewsRepository: DiscoverNewsRepository {
        DiscoverNewsRepositoryAdapter(
            socialService: socialService,
            webService: webService
        )
    }

    var djListRepository: DJListRepository {
        DJListRepositoryAdapter(service: webService)
    }

    var djReadRepository: DJReadRepository {
        DJReadRepositoryAdapter(service: webService)
    }

    var djLinkedContentRepository: DJLinkedContentRepository {
        DJLinkedContentRepositoryAdapter(service: webService)
    }

    var djRelationRepository: DJRelationRepository {
        DJRelationRepositoryAdapter(service: webService)
    }

    var djCommandRepository: DJCommandRepository {
        DJCommandRepositoryAdapter(service: webService)
    }

    var djRankingRepository: DJRankingRepository {
        DJRankingRepositoryAdapter(service: webService)
    }

    var djImportRepository: DJImportRepository {
        DJImportRepositoryAdapter(service: webService)
    }

    var djMediaRepository: DJMediaRepository {
        DJMediaRepositoryAdapter(service: webService)
    }

    var setListRepository: SetListRepository {
        SetListRepositoryAdapter(service: webService)
    }

    var setReadRepository: SetReadRepository {
        SetReadRepositoryAdapter(service: webService)
    }

    var setCommentRepository: SetCommentRepository {
        SetCommentRepositoryAdapter(service: webService)
    }

    var setCommandRepository: SetCommandRepository {
        SetCommandRepositoryAdapter(service: webService)
    }

    var tracklistRepository: TracklistRepository {
        TracklistRepositoryAdapter(service: webService)
    }

    var setEventLookupRepository: SetEventLookupRepository {
        SetEventLookupRepositoryAdapter(service: webService)
    }

    var setMediaRepository: SetMediaRepository {
        SetMediaRepositoryAdapter(service: webService)
    }

    var discoverWikiRepository: DiscoverWikiRepository {
        DiscoverWikiRepositoryAdapter(
            service: webService,
            socialService: socialService
        )
    }

    var conversationRepository: ConversationRepository {
        ConversationRepositoryAdapter(service: socialService)
    }

    var messageNotificationRepository: MessageNotificationRepository {
        MessageNotificationRepositoryAdapter(service: socialService)
    }

    var chatSettingsRepository: ChatSettingsRepository {
        ChatSettingsRepositoryAdapter(service: socialService)
    }

    var notificationRepository: NotificationRepository {
        NotificationRepositoryAdapter(service: socialService)
    }

    var shareMessageRepository: ShareMessageRepository {
        ShareMessageRepositoryAdapter(service: socialService)
    }

    var feedStreamRepository: FeedStreamRepository {
        FeedStreamRepositoryAdapter(service: socialService)
    }

    var postReadRepository: PostReadRepository {
        PostReadRepositoryAdapter(service: socialService)
    }

    var postCommandRepository: PostCommandRepository {
        PostCommandRepositoryAdapter(service: socialService)
    }

    var postInteractionRepository: PostInteractionRepository {
        PostInteractionRepositoryAdapter(service: socialService)
    }

    var feedEventTrackingRepository: FeedEventTrackingRepository {
        FeedEventTrackingRepositoryAdapter(service: socialService)
    }

    var postCommentRepository: PostCommentRepository {
        PostCommentRepositoryAdapter(service: socialService)
    }

    var postMediaRepository: PostMediaRepository {
        PostMediaRepositoryAdapter(service: webService)
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

    var squadActivityRepository: SquadActivityRepository {
        SquadActivityRepositoryAdapter(service: socialService)
    }

    var locationSyncRepository: LocationSyncRepository {
        LocationSyncRepositoryAdapter(service: socialService)
    }

    var profileUserRepository: ProfileUserRepository {
        ProfileUserRepositoryAdapter(socialService: socialService)
    }

    var profileContentRepository: ProfileContentRepository {
        ProfileContentRepositoryAdapter(
            socialService: socialService,
            webService: webService
        )
    }

    var profileCheckinRepository: ProfileCheckinRepository {
        ProfileCheckinRepositoryAdapter(webService: webService)
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
