import XCTest

final class AuthSessionPersistenceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSessionPersistsAfterRelaunchInMockMode() throws {
        let firstLaunch = makeApp(resetSession: true, forceSessionExpireOnBoot: false)
        firstLaunch.launch()

        try loginThroughOneTap(on: firstLaunch)
        XCTAssertTrue(
            firstLaunch.otherElements["app.authenticatedRoot"].waitForExistence(timeout: 10),
            "Expected authenticated root after first login."
        )

        firstLaunch.terminate()

        let secondLaunch = makeApp(resetSession: false, forceSessionExpireOnBoot: false)
        secondLaunch.launch()

        XCTAssertTrue(
            secondLaunch.otherElements["app.authenticatedRoot"].waitForExistence(timeout: 10),
            "Expected authenticated root to be restored after relaunch."
        )
    }

    func testSessionExpiryFallsBackToLogin() throws {
        let firstLaunch = makeApp(resetSession: true, forceSessionExpireOnBoot: false)
        firstLaunch.launch()

        try loginThroughOneTap(on: firstLaunch)
        XCTAssertTrue(
            firstLaunch.otherElements["app.authenticatedRoot"].waitForExistence(timeout: 10),
            "Expected authenticated root after first login."
        )

        firstLaunch.terminate()

        let secondLaunch = makeApp(resetSession: false, forceSessionExpireOnBoot: true)
        secondLaunch.launch()

        XCTAssertTrue(
            secondLaunch.otherElements["app.loginRoot"].waitForExistence(timeout: 10),
            "Expected login root after forced session expiry."
        )
    }

    private func makeApp(resetSession: Bool, forceSessionExpireOnBoot: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["RAVER_USE_MOCK"] = "1"
        app.launchEnvironment["RAVER_UI_TEST_RESET_SESSION"] = resetSession ? "1" : "0"
        app.launchEnvironment["RAVER_UI_TEST_FORCE_SESSION_EXPIRED_ON_BOOT"] = forceSessionExpireOnBoot ? "1" : "0"
        return app
    }

    private func loginThroughOneTap(on app: XCUIApplication) throws {
        let loginRoot = app.otherElements["app.loginRoot"]
        XCTAssertTrue(loginRoot.waitForExistence(timeout: 10), "Expected login root to appear.")

        let agreeControl = resolveElement(
            in: app,
            identifiers: ["login.agreeTermsButton"],
            buttonLabels: [
                "我同意《用户服务条款》《用户协议》《隐私政策》",
                "I agree to the \"User Terms of Service\", \"User Agreement\" and \"Privacy Policy\""
            ]
        )
        XCTAssertTrue(agreeControl.waitForExistence(timeout: 5), "Expected terms agreement button.")
        tapElement(agreeControl)

        let oneTapButton = resolveElement(
            in: app,
            identifiers: ["login.oneTapButton"],
            buttonLabels: ["一键登录/注册", "One-click login/registration"]
        )
        XCTAssertTrue(oneTapButton.waitForExistence(timeout: 5), "Expected one-tap login button.")
        tapElement(oneTapButton)
    }

    private func resolveElement(
        in app: XCUIApplication,
        identifiers: [String],
        buttonLabels: [String]
    ) -> XCUIElement {
        for identifier in identifiers {
            let candidate = app.descendants(matching: .any)[identifier]
            if candidate.exists {
                return candidate
            }
        }
        for label in buttonLabels {
            let button = app.buttons[label]
            if button.exists {
                return button
            }
        }
        if let firstIdentifier = identifiers.first {
            return app.descendants(matching: .any)[firstIdentifier]
        }
        if let firstLabel = buttonLabels.first {
            return app.buttons[firstLabel]
        }
        return app.descendants(matching: .any).element(boundBy: 0)
    }

    private func tapElement(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
