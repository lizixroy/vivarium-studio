//
//  BRepTests.swift
//  vivarium-studioTests
//
//  Created by Roy Li on 1/1/26.
//

import XCTest
@testable import vivarium_studio

final class BRepTests: XCTestCase {

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
    
    func testHalfEdgeFromVertex() {
        var brep = BRep()
                
        // Assume the following loop: v0 --> v1 --> v2 --> v0
        let vertexID0 = VertexID(raw: 0)
        let vertexID1 = VertexID(raw: 1)
        let vertexID2 = VertexID(raw: 2)
        let vertexID3 = VertexID(raw: 3)
                
        let vertex0 = Vertex(position: [0, 0, 0])
        let vertex1 = Vertex(position: [1, 0, 0])
        let vertex2 = Vertex(position: [1, 1, 0])
        let vertex3 = Vertex(position: [0, 1, 0])
        
        brep.addVertex(vertex0)
        brep.addVertex(vertex1)
        brep.addVertex(vertex2)
        brep.addVertex(vertex3)

        let faceID = brep.addPlanarFace([vertexID0, vertexID1, vertexID2, vertexID3])
        print("faceID: \(faceID)")
        
        XCTAssertEqual(brep.edges.count, 4)
        XCTAssertEqual(brep.halfEdges.count, 4)
        XCTAssertEqual(brep.faces.count, 1)
        XCTAssertEqual(brep.vertices.count, 4)
        XCTAssertEqual(brep.loops.count, 1)
        
        // Walk through all the halfEdges to make sure we return to the beginning.
        for i in 0..<brep.halfEdges.count {
            let halfEdge = brep.halfEdges[i]
            let nextHalfEdgeID = brep.halfEdges[(i + 1) % brep.halfEdges.count]
            XCTAssertEqual(halfEdge.toVertex.raw, nextHalfEdgeID.fromVertex.raw)
        }
    }
    
    func testFindOppositeHalfEdge() {
        
    }
    
    func testMakeBox() {
        let box = BRep.makeBox(width: 1, height: 1, depth: 1)
        print("box: \(box)")
        
        XCTAssertEqual(box.vertices.count, 8)
        XCTAssertEqual(box.faces.count, 6)
        XCTAssertEqual(box.edges.count, 12)
        XCTAssertEqual(box.loops.count, 6)
        XCTAssertEqual(box.halfEdges.count, 24)
        
        // Every edge is shared, so each halfEdge should have a twin half edge.
        for halfEdge in box.halfEdges {
            XCTAssertNotNil(halfEdge.twin, "Every edge is shared, so each halfEdge should have a twin half edge.")
        }
    }

}
