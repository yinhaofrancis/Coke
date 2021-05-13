import XCTest

import Security
import AVFoundation
@testable import Coke
class Tests: XCTestCase,AVAssetDownloadDelegate {
    
    let exp = XCTestExpectation(description: "fix")
    var runloop:CokeRunloop? = CokeRunloop()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try super.tearDownWithError()
    }
    func app() {
        self.runloop?.runloop.perform(inModes: [.common]) {[weak self] in
            print(self?.runloop?.runloop)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(3)) {
            self.runloop = nil
        }
    }
    func testExample() throws {
        DispatchQueue.global().async {
            self.app()
        }
        self.wait(for: [exp], timeout: 10000)
    }
    deinit {
        
    }
}
