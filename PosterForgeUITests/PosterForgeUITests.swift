// ========================================
// File: PosterForgeUITests.swift
// ========================================
import XCTest

final class PosterForgeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {}

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()

        // Esempio di test UI
        XCTAssertTrue(app.buttons["1) Carica CSV"].exists)
        XCTAssertTrue(app.buttons["2) Cerca un Film / Serie"].exists)
        XCTAssertTrue(app.buttons["3) Mostra Libreria"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
