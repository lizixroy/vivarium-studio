//
//  EditorCameraControllerTests.swift
//  vivarium-studioTests
//
//  Created by Roy Li on 12/21/25.
//

import XCTest
import simd
@testable import vivarium_studio

final class EditorCameraControllerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    let accuracy: Float = 0.001
    
    // Test yaw with 0 in the y direction.
    func testYaw() {
        let position = SIMD3<Float>(x: 0, y: 0, z: 1)
        let cameraController = EditorCameraController(position: position)
        
        let pivotBeforeYaw = cameraController.yawPivot()
        
        cameraController.yaw(angle: .pi / 2)
        XCTAssertEqual(cameraController.position.x, 1, accuracy: accuracy)
        XCTAssertEqual(cameraController.position.y, 0, accuracy: accuracy)
        XCTAssertEqual(cameraController.position.z, 0, accuracy: accuracy)
        
        let pivotAfterYaw = cameraController.yawPivot()
        XCTAssertTrue(pivotBeforeYaw == pivotAfterYaw)
    }
    
    // Test yaw with 10 in the y direction
    func testYawWithYOffset() {
        let position = SIMD3<Float>(x: 0, y: 10, z: 1)
        let cameraController = EditorCameraController(position: position)
        
        var angle: Float = 0.0
        let angleIncrement = 0.1 * Float.pi
        
        let pivotBeforeYaw = cameraController.yawPivot()
        
        while angle < 2 * Float.pi {
            cameraController.yaw(angle: angleIncrement)
            let pivotAfterYaw = cameraController.yawPivot()
            
            XCTAssertEqual(pivotBeforeYaw.x, pivotAfterYaw.x, accuracy: 0.01)
            XCTAssertEqual(pivotBeforeYaw.y, pivotAfterYaw.y, accuracy: 0.01)
            XCTAssertEqual(pivotBeforeYaw.z, pivotAfterYaw.z, accuracy: 0.01)
            
            angle += angleIncrement
        }
        
        print("position after orbit: \(cameraController.position)")
        XCTAssertEqual(position.x, cameraController.position.x, accuracy: 0.01)
        XCTAssertEqual(position.y, cameraController.position.y, accuracy: 0.01)
        XCTAssertEqual(position.z, cameraController.position.z, accuracy: 0.01)
    }
    
    func testYawWithPitch() {
        
    }
}
