//
//  BRep.swift
//  vivarium-studio
//
//  Created by Roy Li on 12/31/25.
//

import Foundation

import simd

// MARK: - ID Types

public struct VertexID: Hashable { public let raw: Int }
public struct HalfEdgeID: Hashable { public let raw: Int }
public struct EdgeID: Hashable { public let raw: Int }
public struct FaceID: Hashable { public let raw: Int }
public struct LoopID: Hashable { public let raw: Int }

// MARK: - Core Topology Elements

public struct Vertex {
    public var position: SIMD3<Float>
    /// One outgoing half-edge (optional). Useful as an entry point for adjacency traversal.
    public var outgoing: HalfEdgeID?

    public init(position: SIMD3<Float>, outgoing: HalfEdgeID? = nil) {
        self.position = position
        self.outgoing = outgoing
    }
}

public struct HalfEdge: CustomDebugStringConvertible {
    // Convention: half-edge points FROM (prev.toVertex) TO (toVertex)
    public var toVertex: VertexID
    public var fromVertex: VertexID
    public var next: HalfEdgeID
    public var prev: HalfEdgeID
    public var twin: HalfEdgeID?      // nil until stitched
    public var edge: EdgeID
    public var loop: LoopID
    public var face: FaceID
    public var id: HalfEdgeID
    
    public var debugDescription: String {
        var str =  "<HalfEdge>(ID: \(id.raw)): vertex-\(fromVertex.raw) ---> vertex-\(toVertex.raw), previous halfEdge ID: \(prev.raw), next halfEdge ID: \(next.raw), loop ID: \(loop.raw), face ID: \(face.raw)"
        
        if let twin = twin {
            str += ", twin halfEdge ID: \(twin.raw)"
        }
        
        return str
    }
    
    public func isOpposite(of other: HalfEdge) -> Bool {
        return (fromVertex == other.toVertex) && (toVertex == other.fromVertex)
    }
    
    public func isOppositeOf(from: VertexID, to: VertexID) -> Bool {
        return (fromVertex == to) && (toVertex == from)
    }
}

public struct Edge {
    /// One of the two half-edges.
    public var halfEdge: HalfEdgeID

    public init(halfEdge: HalfEdgeID) {
        self.halfEdge = halfEdge
    }
}

public struct Loop {
    /// A representative half-edge on this loop.
    public var halfEdge: HalfEdgeID
    /// The face this loop bounds.
    public var face: FaceID

    public init(halfEdge: HalfEdgeID, face: FaceID) {
        self.halfEdge = halfEdge
        self.face = face
    }
}

public struct Face {
    /// Outer boundary loop
    public var outer: LoopID
    /// Optional holes
    public var holes: [LoopID] = []

    public init(outer: LoopID, holes: [LoopID] = []) {
        self.outer = outer
        self.holes = holes
    }
}

// MARK: - BRep Container

public struct BRep {
    public private(set) var vertices: [Vertex] = []
    public private(set) var halfEdges: [HalfEdge] = []
    public private(set) var edges: [Edge] = []
    public private(set) var loops: [Loop] = []
    public private(set) var faces: [Face] = []

    public init() {}

    // MARK: Allocation helpers

    @discardableResult
    public mutating func addVertex(at p: SIMD3<Float>) -> VertexID {
        let id = VertexID(raw: vertices.count)
        vertices.append(Vertex(position: p))
        return id
    }
    
    @discardableResult
    public mutating func addVertex(_ v: Vertex) -> VertexID {
        let id = VertexID(raw: vertices.count)
        vertices.append(v)
        return id        
    }

    @discardableResult
    public mutating func addFacePlaceholder() -> FaceID {
        // We create face after loop exists; this is just to reserve an ID if you prefer.
        let id = FaceID(raw: faces.count)
        // Temporary dummy; will be overwritten by caller.
        faces.append(Face(outer: LoopID(raw: 0)))
        return id
    }

    // MARK: - Core Construction: Build a single polygon face
    //
    // Creates:
    // - 1 Face
    // - 1 Loop (outer)
    // - N directed half-edges around the face
    // - N twin half-edges for the "outside" (unbounded) side
    // - N edges
    //
    // NOTE: This builds a surface patch with an implicit "outside" loop not assigned to a face.
    // For learning: it's okay. For solids: you'd stitch faces so each edge is shared by 2 faces.

//    public mutating func makePolygonFace(vertexIDs: [VertexID]) -> FaceID {
//        precondition(vertexIDs.count >= 3, "Need at least 3 vertices for a face.")
//
//        // Create face and loop IDs up front
//        let faceID = FaceID(raw: faces.count)
//        let loopID = LoopID(raw: loops.count)
//
//        // We'll create half-edges in pairs: (he, heTwin)
//        // he belongs to the face's loop, heTwin is the opposite direction (unbounded outside for now).
//        let n = vertexIDs.count
//
//        // Reserve slots
//        let baseHE = halfEdges.count
//        let baseEdge = edges.count
//
//        halfEdges.reserveCapacity(halfEdges.count + 2*n)
//        edges.reserveCapacity(edges.count + n)
//
//        // We need placeholder objects to fill references (next/prev/twin) after allocation.
//        // So allocate dummy items first.
//        for i in 0..<(2*n) {
//            let dummy = HalfEdge(
//                toVertex: vertexIDs[0],
//                next: HalfEdgeID(raw: 0),
//                prev: HalfEdgeID(raw: 0),
//                twin: HalfEdgeID(raw: 0),
//                edge: EdgeID(raw: 0),
//                loop: loopID
//            )
//            halfEdges.append(dummy)
//        }
//
//        for i in 0..<n {
//            edges.append(Edge(halfEdge: HalfEdgeID(raw: baseHE + 2*i)))
//        }
//
//        // Create the loop & face
//        loops.append(Loop(halfEdge: HalfEdgeID(raw: baseHE), face: faceID))
//        faces.append(Face(outer: loopID))
//
//        // Populate connectivity
//        for i in 0..<n {
//            let a = vertexIDs[i]
//            let b = vertexIDs[(i + 1) % n]
//
//            let heID = HalfEdgeID(raw: baseHE + 2*i)
//            let twinID = HalfEdgeID(raw: baseHE + 2*i + 1)
//            let edgeID = EdgeID(raw: baseEdge + i)
//
//            let nextHeID = HalfEdgeID(raw: baseHE + 2*((i + 1) % n))
//            let prevHeID = HalfEdgeID(raw: baseHE + 2*((i - 1 + n) % n))
//
//            // Half-edge along the face boundary goes a -> b, and stores "toVertex = b"
//            halfEdges[heID.raw] = HalfEdge(
//                toVertex: b,
//                next: nextHeID,
//                prev: prevHeID,
//                twin: twinID,
//                edge: edgeID,
//                loop: loopID
//            )
//
//            // Twin goes b -> a. For now, it's in the same loop ID as a placeholder; in a full structure,
//            // you'd attach it to the adjacent face's loop when you stitch faces.
//            halfEdges[twinID.raw] = HalfEdge(
//                toVertex: a,
//                next: twinID, // self-loop placeholders for the "outside" side
//                prev: twinID,
//                twin: heID,
//                edge: edgeID,
//                loop: loopID
//            )
//
//            // Point vertex outgoing half-edge if not set (handy for traversal)
//            if vertices[a.raw].outgoing == nil {
//                vertices[a.raw].outgoing = heID
//            }
//        }
//
//        return faceID
//    }

    // MARK: - Traversal utilities

    public func loopHalfEdges(_ loopID: LoopID) -> [HalfEdgeID] {
        let start = loops[loopID.raw].halfEdge
        var result: [HalfEdgeID] = []
        var h = start
        var visited = Set<Int>()
        while !visited.contains(h.raw) {
            visited.insert(h.raw)
            result.append(h)
            h = halfEdges[h.raw].next
        }
        return result
    }

    public func faceVertexCycle(_ faceID: FaceID) -> [VertexID] {
        let loopID = faces[faceID.raw].outer
        let hes = loopHalfEdges(loopID)
        // Since half-edge stores "toVertex", the cycle is the sequence of toVertices.
        // If you want "from" vertices, use prev.toVertex.
        return hes.map { halfEdges[$0.raw].toVertex }
    }

    public func halfEdgeFromVertex(_ he: HalfEdgeID) -> VertexID {
        // If half-edge points to B, then it comes from prev.toVertex.
        let prevHE = halfEdges[he.raw].prev
        return halfEdges[prevHE.raw].toVertex
    }
    
    public func halfEdgeSegment(_ he: HalfEdgeID) -> (SIMD3<Float>, SIMD3<Float>) {
        let a = halfEdgeFromVertex(he)
        let b = halfEdges[he.raw].toVertex
        return (vertices[a.raw].position, vertices[b.raw].position)
    }

    // MARK: - Basic geometry: face normal (planar polygon assumption)
    // Newell's method for polygon normal.
    public func faceNormalApprox(_ faceID: FaceID) -> SIMD3<Float> {
        let loopID = faces[faceID.raw].outer
        let hes = loopHalfEdges(loopID)

        var nx: Float = 0.0, ny: Float = 0.0, nz: Float = 0.0
        for he in hes {
            let (p0, p1) = halfEdgeSegment(he)
            nx += (p0.y - p1.y) * (p0.z + p1.z)
            ny += (p0.z - p1.z) * (p0.x + p1.x)
            nz += (p0.x - p1.x) * (p0.y + p1.y)
        }
        let n = SIMD3<Float>(nx, ny, nz)
        let len = simd_length(n)
        return len > 1e-12 ? (n / len) : SIMD3<Float>(0, 0, 0)
    }

    // MARK: - Sanity checks (helps learning)

    public func validateFace(_ faceID: FaceID) -> [String] {
        var issues: [String] = []
        let loopID = faces[faceID.raw].outer
        let hes = loopHalfEdges(loopID)

        if hes.count < 3 { issues.append("Face has fewer than 3 half-edges.") }

        for he in hes {
            let heObj = halfEdges[he.raw]
            // next/prev consistency
            let next = halfEdges[heObj.next.raw]
            let prev = halfEdges[heObj.prev.raw]
            if next.prev.raw != he.raw { issues.append("next.prev mismatch at half-edge \(he.raw).") }
            if prev.next.raw != he.raw { issues.append("prev.next mismatch at half-edge \(he.raw).") }

            // twin consistency
            let twin = halfEdges[heObj.twin!.raw]
            if twin.twin!.raw != he.raw { issues.append("twin.twin mismatch at half-edge \(he.raw).") }

            // edge consistency
            if edges[heObj.edge.raw].halfEdge.raw % 2 != 0 {
                issues.append("Edge representative is unexpectedly a twin half-edge (learning impl detail).")
            }
        }

        return issues
    }
}

extension BRep {
    
    /// Build a parametric "half-room": floor + back wall + left wall.
    ///
    /// Coordinate system used:
    /// - X increases to the right
    /// - Y increases upward
    /// - Z increases into the room (depth)
    ///
    /// Room occupies:
    /// - x ∈ [0, width]
    /// - y ∈ [0, height]
    /// - z ∈ [0, depth]
    ///
    /// Faces created (interior normals):
    /// - Floor:   +Y
    /// - Back:    +Z  (plane z = 0, facing into the room)
    /// - Left:    +X  (plane x = 0, facing into the room)
    ///
    public static func halfRoomFeature(width: Float, height: Float, depth: Float) -> BRep {
        precondition(width > 0 && height > 0 && depth > 0)
    
        var brep = BRep()
        
        // Create 7 vertices for the halfroom
        
        let vID0 = brep.addVertex(at: [0, 0, 0]) // back-left bottom
        let vID1 = brep.addVertex(at: [width, 0, 0]) // back-right bottom
        let vID2 = brep.addVertex(at: [0, 0, depth]) // front-left bottom
        let vID3 = brep.addVertex(at: [width, 0, depth]) // front-right bottom
                
        let vID4 = brep.addVertex(at: [0, height, 0]) // back-left top
        let vID5 = brep.addVertex(at: [width, height, 0]) // back-right top
        let vID6 = brep.addVertex(at: [0, height, depth]) // front-left bottom
        
        // Build 3 interior faces
        
        // Winding chosen so the normals point "into the room"
        // - Floor (+Y): CCW when viewed from +Y
        // - Back (+Z): CCW in x-y plane
        // - Left (+X): CCW in y-z plane
        let floorFace = brep.addPlanarFace([vID0, vID2, vID3, vID1])
        let backFace = brep.addPlanarFace([vID0, vID1, vID5, vID4])
        let leftFace = brep.addPlanarFace([vID2, vID0, vID4, vID6])
        
        // TODO: seal with boundary face
        
        return brep
    }
        
    func findOppositeHalfEdge(from: VertexID, to: VertexID) -> HalfEdgeID? {
        for i in 0..<halfEdges.count {
            let halfEdge = halfEdges[i]
            if halfEdge.isOppositeOf(from: from, to: to) {
                return HalfEdgeID(raw: i)
            }
        }
        
        return nil
    }
    
    mutating func addPlanarFace(_ vertices: [VertexID]) -> FaceID {
        precondition(vertices.count >= 3)
        
        let faceID = FaceID(raw: faces.count)
        let loopID = LoopID(raw: loops.count)
                
        // Create new Face and Loop instances without putting them into the arrays yet.
        let face = Face(outer: loopID)
        let loop = Loop(halfEdge: HalfEdgeID(raw: -1), face: faceID)
        faces.append(face)
        loops.append(loop)
        
        // Create one half-edge per polygon edge
        let n = vertices.count
        let baseHE = halfEdges.count
        
        // Allocate half-edges
        halfEdges.reserveCapacity(halfEdges.count + n)
        
        var halfEdgeIDs: [HalfEdgeID] = []
        halfEdgeIDs.reserveCapacity(n)
        
        // Create edges / half-edges
        for i in 0..<n {
            let a = vertices[i]
            let b = vertices[(i + 1) % n]
            
            // Either reuse an existing undirected edge (if the opposite half-edge exists) or create a new edge.
            let opposite = findOppositeHalfEdge(from: a, to: b)
            let edgeID: EdgeID
            
            if let opp = opposite {
                edgeID = halfEdges[opp.raw].edge
            } else {
                edgeID = EdgeID(raw: edges.count)
                // Temporary representative = we'll set to this half-edge after we create it
                edges.append(Edge(halfEdge: HalfEdgeID(raw: -1)))
            }
            
            let halfEdgeID = HalfEdgeID(raw: baseHE + i)
            halfEdgeIDs.append(halfEdgeID)
            
            // Placeholder next/prev (set later)
            halfEdges.append(
                HalfEdge(
                    toVertex: b,
                    fromVertex: a,
                    next: HalfEdgeID(raw: -1),
                    prev: HalfEdgeID(raw: -1),
                    twin: nil,
                    edge: edgeID,
                    loop: loopID,
                    face: faceID,
                    id: halfEdgeID
                )
            )
            
            // Set edge representative if this is a newly created edge
            if edges[edgeID.raw].halfEdge.raw == -1 {
                edges[edgeID.raw].halfEdge = halfEdgeID
            }
         
            // Stich if possible
            if let opp = opposite {
                halfEdges[halfEdgeID.raw].twin = opp
                halfEdges[opp.raw].twin = halfEdgeID
            }
            
            // Set an outgoing pointer on the source vertex if empty
            if self.vertices[a.raw].outgoing == nil {
                self.vertices[a.raw].outgoing = halfEdgeID
            }
        }
        
        // Set next/prev around the loop
        for i in 0..<n {
            let halfEdge = halfEdgeIDs[i]
            let next = halfEdgeIDs[(i + 1) % n]
            let prev = halfEdgeIDs[(i - 1 + n) % n] // TODO: this is different from ChatGPT's code: let prev = heIDs[(i - 1 + n) % n]
            halfEdges[halfEdge.raw].next = next
            halfEdges[halfEdge.raw].prev = prev
        }
        
        // Set loop representative
        loops[loopID.raw].halfEdge = halfEdgeIDs[0]
        
        return faceID
    }
    
    // MARK: - Parametric box builder

    public enum BoxAnchor {
        case minCorner   // origin is (minX,minY,minZ)
        case center      // origin is box center
    }

    /// Builds a closed manifold B-Rep box with outward-facing normals.
    /// width/height/depth must be > 0.
    ///
    /// Coordinates: +Y up, +Z forward, +X right (RealityKit-friendly).
    public static func makeBox(
        width: Float,
        height: Float,
        depth: Float,
        origin: SIMD3<Float> = .zero,
        anchor: BoxAnchor = .minCorner
    ) -> BRep {
        precondition(width > 0 && height > 0 && depth > 0)

        // Compute min corner
        let minCorner: SIMD3<Float>
        switch anchor {
        case .minCorner:
            minCorner = origin
        case .center:
            minCorner = origin - SIMD3<Float>(width * 0.5, height * 0.5, depth * 0.5)
        }

        let x0 = minCorner.x
        let y0 = minCorner.y
        let z0 = minCorner.z
        let x1 = x0 + width
        let y1 = y0 + height
        let z1 = z0 + depth

        var brep = BRep()

        // 8 corners
        // Bottom (y0)
        let vLeftBottomBack   = brep.addVertex(at: [x0, y0, z0]) // left  bottom back
        let vRightBottomBack  = brep.addVertex(at: [x1, y0, z0]) // right bottom back
        let vRightBottomFront = brep.addVertex(at: [x1, y0, z1]) // right bottom front
        let vLeftBottomFront  = brep.addVertex(at: [x0, y0, z1]) // left  bottom front

        // Top (y1)
        let vLeftTopBack   = brep.addVertex(at: [x0, y1, z0]) // left  top back
        let vRightTopBack  = brep.addVertex(at: [x1, y1, z0]) // right top back
        let vRightTopFront = brep.addVertex(at: [x1, y1, z1]) // right top front
        let vLeftTopFront  = brep.addVertex(at: [x0, y1, z1]) // left  top front

        // 6 faces, CCW when viewed from outside (outward normals)
        //
        // Bottom face normal: -Y (outside is downward)
        _ = brep.addPlanarFace([vLeftBottomBack, vRightBottomBack, vRightBottomFront, vLeftBottomFront])

        // Top face normal: +Y
        _ = brep.addPlanarFace([vLeftTopFront, vRightTopFront, vRightTopBack, vLeftTopBack])

        // Back face normal: -Z
        _ = brep.addPlanarFace([vRightBottomBack, vLeftBottomBack, vLeftTopBack, vRightTopBack])

        // Front face normal: +Z
        _ = brep.addPlanarFace([vLeftBottomFront, vRightBottomFront, vRightTopFront, vLeftTopFront])

        // Left face normal: -X
        _ = brep.addPlanarFace([vLeftBottomBack, vLeftBottomFront, vLeftTopFront, vLeftTopBack])

        // Right face normal: +X
        _ = brep.addPlanarFace([vRightBottomFront, vRightBottomBack, vRightTopBack, vRightTopFront])

        return brep
    }
}
