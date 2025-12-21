//
//  VectorMathUtilsTests.swift
//  vivarium-studioTests
//
//  Created by Roy Li on 12/18/25.
//

import XCTest
import simd
@testable import vivarium_studio

final class VectorMathUtilsTests: XCTestCase {

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
    
    func testXZPlaneProjection() {
        let v = SIMD3<Float>(x: 1, y: 2, z: 3)
        let expectedProjectedVector = SIMD3<Float>(x: 1, y: 0, z: 3)
        XCTAssertEqual(expectedProjectedVector, v.projectionOntoXZPlane)
    }

    func testFindYAxisRotationPivot() {
        let distance: Float = 5.0
        let p = SIMD3<Float>(x: 1, y: 1, z: 0)
        let forward = SIMD3<Float>(x: -1, y: -1, z: 0)
        let pivot = findYAxisRotationPivot(forward: forward, from: p, distance: distance)
        XCTAssertEqual(pivot.y, p.y, "A pivot point on a plane parallel to the x-z plane should always have the same y-coordinate as the input point")
        XCTAssertEqual(SIMD3<Float>(x: -4, y: 1, z: 0), pivot)
        XCTAssertEqual(simd_length(pivot - p), 5, accuracy: 0.001)
    }
    
    func testFindYAxisRotationPivotWithNonZeroXYZPoint() {
        let distance: Float = 5.0
        let p = SIMD3<Float>(x: 1, y: 1, z: 1)
        let forward = SIMD3<Float>(x: -1, y: 0, z: 0)
        let pivot = findYAxisRotationPivot(forward: forward, from: p, distance: distance)
        XCTAssertEqual(pivot.y, p.y, "A pivot point on a plane parallel to the x-z plane should always have the same y-coordinate as the input point")
        XCTAssertEqual(SIMD3<Float>(x: -4, y: 1, z: 1), pivot)
        XCTAssertEqual(simd_length(pivot - p), 5, accuracy: 0.001)
    }
    
    func testFindYAxisRotationPivotForwardPointingOutward() {
        let distance: Float = 5.0
        let p = SIMD3<Float>(x: 1, y: 1, z: 1)
        let forward = SIMD3<Float>(x: 1, y: 1, z: 1)
        let pivot = findYAxisRotationPivot(forward: forward, from: p, distance: distance)
        XCTAssertEqual(pivot.y, p.y, "A pivot point on a plane parallel to the x-z plane should always have the same y-coordinate as the input point")
        XCTAssertEqual(pivot.x, 1 + 3.5355, accuracy: 0.001)
        XCTAssertEqual(pivot.z, 1 + 3.5355, accuracy: 0.001)
        XCTAssertEqual(simd_length(pivot - p), 5, accuracy: 0.001)
    }    
}
