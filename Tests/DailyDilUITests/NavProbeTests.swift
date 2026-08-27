import XCTest

final class NavProbeTests: XCTestCase {
    let shotDir = "/private/tmp/claude-501/-Users-raviraj/2e06edb7-e34a-47bb-9d5f-e0665a3e9f3e/scratchpad/walk"

    @MainActor
    func snap(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? FileManager.default.createDirectory(atPath: shotDir, withIntermediateDirectories: true)
        try? png.write(to: URL(fileURLWithPath: "\(shotDir)/\(name).png"))
    }

    @MainActor
    func testWalkAllScreens() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--uitest-onboarded")
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 5))

        // Finger PPG flow
        app.buttons["Measure"].tap()
        XCTAssertTrue(app.navigationBars["Measure"].waitForExistence(timeout: 3))
        snap("10-measure")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start screening'")).firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start camera'")).firstMatch.waitForExistence(timeout: 3))
        snap("11-ppg-ready")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Measure"].waitForExistence(timeout: 3))

        // Home after a reading
        app.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 3))
        snap("20-home")
        app.swipeUp()
        snap("21-home-2")
        app.swipeUp()
        snap("22-home-3")

        // Trends
        app.buttons["Trends"].tap()
        XCTAssertTrue(app.navigationBars["Trends"].waitForExistence(timeout: 3))
        snap("30-trends")
        app.swipeUp()
        snap("31-trends-2")

        // Profile + subscreens
        app.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 3))
        snap("40-profile")
        app.swipeUp()
        snap("41-profile-2")
        for (label, name) in [("About", "42-about"), ("Data & privacy", "43-privacy"), ("Export", "44-export")] {
            let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
            let cell = row.exists ? row : app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
            if cell.waitForExistence(timeout: 3) {
                cell.tap()
                snap(name)
                app.swipeUp()
                snap(name + "-2")
                app.navigationBars.buttons.firstMatch.tap()
                XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 3))
            }
        }
        snap("99-end")
    }
}
