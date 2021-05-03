import XCTest
import Coke
import AVFoundation
class Tests: XCTestCase,AVAssetDownloadDelegate {
    
    let exp = XCTestExpectation(description: "fix")
    var session:AVAssetDownloadURLSession!
    override func setUpWithError() throws {
        try super.setUpWithError()
        let loader = try WebVideoLoader(url: "https://wwwstatic.vivo.com.cn/vivoportal/files/resource/files/1612698718175/20210207/yuelaiyuehao.mp4")
        try loader.downloader.storage.delete()
        self.session = AVAssetDownloadURLSession(configuration: .background(withIdentifier: "ddd"), assetDownloadDelegate: self, delegateQueue: nil)
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try super.tearDownWithError()
    }
    func testExample() throws {
        self.wait(for: [self.exp], timeout: 4000)
        
    }
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
}
