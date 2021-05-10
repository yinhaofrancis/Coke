import XCTest

import Security
import AVFoundation
@testable import Coke
class Tests: XCTestCase,AVAssetDownloadDelegate {
    
    let exp = XCTestExpectation(description: "fix")

    var a = try! CokeRunloopSource<String>(order: 0)
    
    var thread:pthread_t?
    var lock:UnsafeMutablePointer<pthread_mutex_t> = .allocate(capacity: 1)
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        pthread_mutex_init(self.lock, nil)
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try super.tearDownWithError()
        a.cancel()
    }
    func app() {
        pthread_create(&self.thread, nil, { l in
            let r = CFRunLoopGetCurrent()
            l.assumingMemoryBound(to: CokeRunloopSource<String>.self).pointee.addRunloop(runloop: r!, mode: .default)
            CFRunLoopRun()
            return l
        }, &self.a)
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(3)) {
            for i in 0 ... 10{
                self.a.signal(model: "\(i)")
                print(i)
            }
        }
        
    }
    func testExample() throws {
        app()
        self.wait(for: [exp], timeout: 10000)
    }
}
