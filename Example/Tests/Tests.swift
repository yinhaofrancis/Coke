import XCTest

import Security
import AVFoundation
@testable import Coke
class Tests: XCTestCase,AVAssetDownloadDelegate {
    
    let exp = XCTestExpectation(description: "fix")

    override func setUpWithError() throws {
        try super.setUpWithError()

    
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try super.tearDownWithError()
    }
    func testExample() throws {
        let keys =  try CokeKey.generatePair(type: .RSA, size: 1024)
        let d = keys.0.encrypt(data: "dasadasd".data(using: .utf8)!)!
        XCTAssert(String(data: keys.1.decrypt(data: d)!, encoding: .utf8) == "dasadasd")
        
    }
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
}
