//
//  CokeVideoUITestsLaunchTests.swift
//  CokeVideoUITests
//
//  Created by wenyang on 2023/10/31.
//

import XCTest

final class CokeVideoUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        let option = XCTMeasureOptions()
        option.invocationOptions = .manuallyStart
        measure(metrics: [XCTMemoryMetric(application: app)], options: option) {
            app.launch()
            startMeasuring()
            app.buttons["scene"].firstMatch.tap()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 30))
        }
    }
}
