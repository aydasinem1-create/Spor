import XCTest

/// Uçtan uca akışlar. Her adımda ekran görüntüsü SCREENSHOT_DIR klasörüne kaydedilir.
final class FormaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"] + args
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            try? FileManager.default.createDirectory(at: URL(fileURLWithPath: dir), withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: url)
        }
    }

    private func tap(_ element: XCUIElement, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Bulunamadı: \(element)", file: file, line: line)
        element.tap()
    }

    // MARK: Kurulum

    func testOnboardingFlow() throws {
        let app = launch([])
        shot(app, "01-hosgeldin")
        tap(app.buttons["onboarding.next"])
        let name = app.textFields["onboarding.name"]
        tap(name)
        name.typeText("Deniz")
        shot(app, "02-tanisma")
        app.buttons["onboarding.next"].tap()   // boy-kilo
        shot(app, "03-boy-kilo")
        app.buttons["onboarding.next"].tap()   // hedef
        shot(app, "04-hedef")
        for _ in 0..<5 { app.buttons["onboarding.next"].tap() }   // deneyim, aktivite, ekipman, odak, plan
        shot(app, "05-plan")
        app.buttons["onboarding.next"].tap()   // hedefler
        shot(app, "06-hedefler")
        app.buttons["onboarding.next"].tap()   // bitir
        XCTAssertTrue(app.buttons["tab.today"].waitForExistence(timeout: 8))
        shot(app, "07-ilk-bugun")
    }

    // MARK: Ana akış (örnek veriyle)

    func testDemoTour() throws {
        let app = launch(["-demo"])
        XCTAssertTrue(app.buttons["tab.today"].waitForExistence(timeout: 10))
        sleep(1)
        shot(app, "10-bugun")

        // Su ekle
        tap(app.buttons["water.add330"])
        app.swipeUp()
        shot(app, "11-bugun-asagi")
        app.swipeUp()
        shot(app, "12-bugun-alt")

        // Beslenme
        tap(app.buttons["tab.nutrition"])
        sleep(1)
        shot(app, "20-beslenme")
        tap(app.buttons["meal.add.snack"])
        sleep(1)
        shot(app, "21-yiyecek-ara")
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap()
            search.typeText("tavuk")
            sleep(1)
            shot(app, "22-arama-sonuc")
        }

        // İlerleme
        app.terminate()
        let app2 = launch(["-demo"])
        tap(app2.buttons["tab.progress"])
        sleep(1)
        shot(app2, "30-ilerleme")
        app2.swipeUp()
        shot(app2, "31-ilerleme-alt")

        // Profil
        tap(app2.buttons["tab.profile"])
        sleep(1)
        shot(app2, "40-profil")
    }

    func testWorkoutFlow() throws {
        let app = launch(["-demo"])
        tap(app.buttons["tab.workout"])
        sleep(1)
        shot(app, "50-antrenman")
        tap(app.buttons["workout.start"])
        sleep(2)
        shot(app, "51-aktif-antrenman")
        // İlk iki seti tamamla
        let firstSet = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'set.complete.0.'")).firstMatch
        tap(firstSet)
        sleep(1)
        shot(app, "52-dinlenme")
        let next = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'set.complete.0.' AND label == 'Seti tamamla'")).firstMatch
        if next.waitForExistence(timeout: 3) { next.tap() }
        app.swipeUp()
        shot(app, "53-aktif-asagi")
        tap(app.buttons["workout.finish"])
        sleep(1)
        shot(app, "54-bitir")
        tap(app.buttons["workout.save"])
        sleep(2)
        shot(app, "55-ozet")
        tap(app.buttons["summary.done"])
        XCTAssertTrue(app.buttons["tab.workout"].waitForExistence(timeout: 5))
    }

    func testRecoveryMapAndExercise() throws {
        let app = launch(["-demo"])
        tap(app.buttons["tab.workout"])
        let map = app.buttons["Kas haritası"]
        tap(map)
        sleep(1)
        shot(app, "60-kas-haritasi")
        app.swipeUp()
        shot(app, "61-kas-listesi")
        app.buttons["Kapat"].firstMatch.tap()
        let lib = app.buttons["Hareketler"]
        tap(lib)
        sleep(1)
        shot(app, "62-hareketler")
        let first = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Leg Press'")).firstMatch
        if first.waitForExistence(timeout: 4) {
            first.tap()
            sleep(2)
            shot(app, "63-hareket-detay")
            app.swipeUp()
            shot(app, "64-hareket-form")
        }
    }

    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-uitest", "-demo"]
            app.launch()
        }
    }
}
