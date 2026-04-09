import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let socialService: SocialService
    let webService: WebFeatureService

    init(
        socialService: SocialService = AppEnvironment.makeService(),
        webService: WebFeatureService = AppEnvironment.makeWebService()
    ) {
        self.socialService = socialService
        self.webService = webService
    }
}
