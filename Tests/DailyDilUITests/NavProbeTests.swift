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
        app.launch()
        sleep(2)

        // Finger PPG flow
        app.buttons["Measure"].tap(); sleep(1)
        snap("10-measure")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start screening'")).firstMatch.tap(); sleep(1)
        snap("11-ppg-ready")
        let startCam = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start camera'")).firstMatch
        if startCam.waitForExistence(timeout: 3) { startCam.tap() }
        sleep(4)
        snap("12-ppg-measuring")
        let startSave = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start saving'")).firstMatch
        if startSave.waitForExistence(timeout: 15) { startSave.tap() }
        sleep(3)
        snap("13-ppg-saving")
        sleep(21)
        snap("14-ppg-result")
        app.swipeUp(); snap("15-ppg-result-2")
        let done = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Done'")).firstMatch
        if done.waitForExistence(timeout: 3) { done.tap(); sleep(1) }

        // Home after a reading
        app.buttons["Home"].tap(); sleep(1)
        snap("20-home")
        app.swipeUp(); sleep(1)
        snap("21-home-2")
        app.swipeUp(); sleep(1)
        snap("22-home-3")

        // Trends
        app.buttons["Trends"].tap(); sleep(1)
        snap("30-trends")
        app.swipeUp(); sleep(1)
        snap("31-trends-2")

        // Profile + subscreens
        app.buttons["Profile"].tap(); sleep(1)
        snap("40-profile")
        app.swipeUp(); sleep(1)
        snap("41-profile-2")
        for (label, name) in [("About", "42-about"), ("Data & privacy", "43-privacy"), ("Export", "44-export")] {
            let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
            let cell = row.exists ? row : app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
            if cell.waitForExistence(timeout: 3) {
                cell.tap(); sleep(1)
                snap(name)
                app.swipeUp(); sleep(1)
                snap(name + "-2")
                app.navigationBars.buttons.firstMatch.tap(); sleep(1)
            }
        }
        snap("99-end")
    }
}
