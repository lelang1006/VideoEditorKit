import XCTest
import VideoEditorKit

final class VideoEditorKitTests: XCTestCase {
    func testImport() {
        // Test that VideoEditorKit can be imported
        let factory = VideoEditorViewFactory()
        XCTAssertNotNil(factory)
    }
}
