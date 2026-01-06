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


public enum Surface {
    case plane(origin: SIMD3<Float>, u: SIMD3<Float>, v: SIMD3<Float>) // u,v orthonormal in plane
    case cylinder(origin: SIMD3<Float>, axis: SIMD3<Float>, radius: Float,
                  xDir: SIMD3<Float>, zDir: SIMD3<Float>) // xDir,zDir ⟂ axis, define angle u frame
}

public enum Curve3D {
    case line(p0: SIMD3<Float>, p1: SIMD3<Float>)
    case circle(center: SIMD3<Float>, normal: SIMD3<Float>, radius: Float,
                xDir: SIMD3<Float>, zDir: SIMD3<Float>) // parameter t in [0, 2π)
}

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
    var curve: Curve3D?
    var vStart: VertexID?
    var vEnd: VertexID?
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
    public var surface: Surface?

    public init(outer: LoopID, holes: [LoopID] = []) {
        self.outer = outer
        self.holes = holes
    }
    
    public init(outer: LoopID, surface: Surface?) {
        self.outer = outer
        self.surface = surface
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
//            if edges[heObj.edge.raw].halfEdge.raw % 2 != 0 {
//                issues.append("Edge representative is unexpectedly a twin half-edge (learning impl detail).")
//            }
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
                edges.append(Edge())
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
            let prev = halfEdgeIDs[(i - 1 + n) % n]
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
    
    mutating func addFace(surface: Surface) -> FaceID {
        // Create placeholder loop; we'll patch outer later.
        let faceID = FaceID(raw: faces.count)
        let loopID = LoopID(raw: loops.count)
        loops.append(Loop(halfEdge: HalfEdgeID(raw: -1), face: faceID))
        faces.append(Face(outer: loopID, surface: surface))
        return faceID
    }
        
    mutating func addEdge(curve: Curve3D, vStart: VertexID, vEnd: VertexID) -> EdgeID {
        let id = EdgeID(raw: edges.count)
        edges.append(Edge(curve: curve, vStart: vStart, vEnd: vEnd))
        return id
    }
    
    // 2D curve in surface parameter space (u,v)
    enum PCurve2D {
        case line(p0: SIMD2<Float>, p1: SIMD2<Float>)
        case circle(center: SIMD2<Float>, radius: Float) // in a plane's (u,v) coords
    }
    
    mutating func addHalfEdge(
        edge: EdgeID,
        face: FaceID,
        loop: LoopID,
        pcurve: PCurve2D,
        forward: Bool
    ) -> HalfEdgeID {
        let id = HalfEdgeID(raw: halfEdges.count)
        
        let edgeObject = edges[edge.raw]
        guard let fromVertexID = edgeObject.vStart else { fatalError() }
        guard let toVertexID = edgeObject.vEnd else { fatalError() }
                        
        let halfEdge = HalfEdge(toVertex: toVertexID, fromVertex: fromVertexID, next: HalfEdgeID(raw: -1), prev: HalfEdgeID(raw: -1), twin: nil, edge: edge, loop: loop, face: face, id: id)
        halfEdges.append(halfEdge)
        return id
    }

    mutating func setTwin(_ a: HalfEdgeID, _ b: HalfEdgeID) {
        halfEdges[a.raw].twin = b
        halfEdges[b.raw].twin = a
    }

    mutating func linkCycle(_ hes: [HalfEdgeID]) {
        precondition(!hes.isEmpty)
        for i in 0..<hes.count {
            let a = hes[i]
            let b = hes[(i + 1) % hes.count]
            let p = hes[(i - 1 + hes.count) % hes.count]
            halfEdges[a.raw].next = b
            halfEdges[a.raw].prev = p
        }
    }

    mutating func setLoop(_ loop: LoopID, halfEdge he: HalfEdgeID) {
        loops[loop.raw].halfEdge = he
    }

    /// True analytic cylinder B-Rep:
    /// - side face is a single cylindrical surface
    /// - caps are planes
    /// - top/bottom circle edges are shared with the side
    /// - seam is represented by one 3D edge used twice with different pcurves (u=0 and u=2π)
    mutating func addAnalyticCylinder(
        radius: Float,
        height: Float,
        center: SIMD3<Float> = .zero
    ) -> (side: FaceID, top: FaceID, bottom: FaceID) {
        precondition(radius > 0 && height > 0)

        let yTop = center.y + height * 0.5
        let yBot = center.y - height * 0.5

        // Cylinder axis is +Y; define local frame for angle u:
        let axis: SIMD3<Float> = [0, 1, 0]
        let xDir: SIMD3<Float> = [1, 0, 0]   // u=0 points along +X
        let zDir: SIMD3<Float> = [0, 0, 1]   // u=π/2 points along +Z

        // Seam points at u=0: (center.x + r, y, center.z)
        let pBotSeam: SIMD3<Float> = [center.x + radius, yBot, center.z]
        let pTopSeam: SIMD3<Float> = [center.x + radius, yTop, center.z]

        // Vertices: seam endpoints (also used as "start/end" for closed circles)
        let vBot = addVertex(at: pBotSeam)
        let vTop = addVertex(at: pTopSeam)

        // --- Create faces (surface geometry) ---
        // Top plane: origin at center on yTop; plane axes u=x, v=z
        let topFace = addFace(surface: .plane(
            origin: [center.x, yTop, center.z],
            u: xDir, v: zDir
        ))

        // Bottom plane: same axes (orientation handled by loop winding / normals later)
        let bottomFace = addFace(surface: .plane(
            origin: [center.x, yBot, center.z],
            u: xDir, v: zDir
        ))

        let sideFace = addFace(surface: .cylinder(
            origin: center,
            axis: axis,
            radius: radius,
            xDir: xDir,
            zDir: zDir
        ))

        let topLoop = faces[topFace.raw].outer
        let bottomLoop = faces[bottomFace.raw].outer
        let sideLoop = faces[sideFace.raw].outer

        // --- Create 3D edges ---
        // Top circle in plane y=yTop, centered at (center.x, yTop, center.z)
        let topCircleEdge = addEdge(
            curve: .circle(center: [center.x, yTop, center.z],
                           normal: axis,
                           radius: radius,
                           xDir: xDir, zDir: zDir),
            vStart: vTop,
            vEnd: vTop // closed
        )

        // Bottom circle
        let bottomCircleEdge = addEdge(
            curve: .circle(center: [center.x, yBot, center.z],
                           normal: axis,
                           radius: radius,
                           xDir: xDir, zDir: zDir),
            vStart: vBot,
            vEnd: vBot // closed
        )

        // Seam line (in 3D, a line). Used twice on side face with different pcurves.
        let seamEdge = addEdge(
            curve: .line(p0: pBotSeam, p1: pTopSeam),
            vStart: vBot,
            vEnd: vTop
        )

        // --- Create half-edges + pcurves ---
        // Parameter conventions:
        // Side cylinder params: u = angle in [0, 2π], v = height offset in [0, height]
        // We'll set v=0 at yBot and v=height at yTop.

        // Top cap loop: a circle in plane param space centered at (0,0) with radius r.
        // (Plane coords: u along +X, v along +Z)
        let heTop_onTop = addHalfEdge(
            edge: topCircleEdge,
            face: topFace,
            loop: topLoop,
            pcurve: .circle(center: [0, 0], radius: radius),
            forward: true
        )

        // Same 3D top circle edge as seen from the side face:
        // On cylinder surface, the top boundary is v=height, u runs 0..2π (a line in (u,v)).
        let heTop_onSide = addHalfEdge(
            edge: topCircleEdge,
            face: sideFace,
            loop: sideLoop,
            pcurve: .line(p0: [0, height], p1: [2 * .pi, height]),
            forward: true
        )
        setTwin(heTop_onTop, heTop_onSide)

        // Bottom cap loop: circle in plane coords; typically we want opposite winding vs top for outward normals.
        let heBot_onBottom = addHalfEdge(
            edge: bottomCircleEdge,
            face: bottomFace,
            loop: bottomLoop,
            pcurve: .circle(center: [0, 0], radius: radius),
            forward: true
        )

        // Bottom boundary on side face: v=0, u runs 0..2π
        let heBot_onSide = addHalfEdge(
            edge: bottomCircleEdge,
            face: sideFace,
            loop: sideLoop,
            pcurve: .line(p0: [2 * .pi, 0], p1: [0, 0]), // reversed so the loop closes consistently
            forward: true
        )
        setTwin(heBot_onBottom, heBot_onSide)

        // Seam appears twice in the side face loop:
        // One at u=2π (right boundary), one at u=0 (left boundary).
        let heSeam_u2pi = addHalfEdge(
            edge: seamEdge,
            face: sideFace,
            loop: sideLoop,
            pcurve: .line(p0: [2 * .pi, 0], p1: [2 * .pi, height]),
            forward: true
        )

        let heSeam_u0 = addHalfEdge(
            edge: seamEdge,
            face: sideFace,
            loop: sideLoop,
            pcurve: .line(p0: [0, height], p1: [0, 0]),
            forward: false
        )

        // These two coedges are twins of each other (the seam is not a boundary in a closed cylinder side).
        setTwin(heSeam_u2pi, heSeam_u0)

        // --- Close loops (half-edge cycles) ---
        // Side loop is a rectangle in (u,v): (0,0)->(2π,0)->(2π,h)->(0,h)->back.
        // We'll order: bottom boundary -> seam u=2π -> top boundary -> seam u=0
        linkCycle([heBot_onSide, heSeam_u2pi, heTop_onSide, heSeam_u0])
        setLoop(sideLoop, halfEdge: heBot_onSide)

        // Caps are single-edge loops (closed circle edge)
        linkCycle([heTop_onTop])
        setLoop(topLoop, halfEdge: heTop_onTop)

        linkCycle([heBot_onBottom])
        setLoop(bottomLoop, halfEdge: heBot_onBottom)

        return (sideFace, topFace, bottomFace)
    }
}

public struct TriMesh {
    public var positions: [SIMD3<Float>]
    public var normals:   [SIMD3<Float>]
    public var uvs:       [SIMD2<Float>]
    public var indices:   [UInt32]
}

extension BRep {
    
    /// Cylinder parameterization used here:
    /// - u = angle in radians
    /// - v = axial distance along axis from a chosen v0 origin
    ///
    /// We map v as world distance along axis from a base point.
    /// If your addAnalyticCylinder assumed axis = +Y and v measured from yBot,
    /// this supports that, but it also supports any axis via projection.
    private func cylinderFrame(axisRaw: SIMD3<Float>, xDirRaw: SIMD3<Float>, zDirRaw: SIMD3<Float>) -> (a: SIMD3<Float>, x: SIMD3<Float>, z: SIMD3<Float>) {
        let a = simd_normalize(axisRaw)
        // Orthonormalize xDir and zDir against axis (defensive)
        var x = xDirRaw - simd_dot(xDirRaw, a) * a
        let xl = simd_length(x)
        x = (xl > 1e-8) ? (x / xl) : orthonormalFallback(to: a)
        var z = simd_cross(a, x) // ensures right-handed
        z = simd_normalize(z)
        return (a, x, z)
    }

    private func orthonormalFallback(to a: SIMD3<Float>) -> SIMD3<Float> {
        // pick a vector not parallel to a
        let t: SIMD3<Float> = (abs(a.y) < 0.9) ? [0,1,0] : [1,0,0]
        return simd_normalize(simd_cross(t, a))
    }
    
    @inline(__always)
    private func planeNormal(u: SIMD3<Float>, v: SIMD3<Float>) -> SIMD3<Float> {
        simd_normalize(simd_cross(u, v))
    }

    @inline(__always)
    private func cylinderEval(
        origin: SIMD3<Float>,
        axis: SIMD3<Float>,
        radius: Float,
        xDir: SIMD3<Float>,
        zDir: SIMD3<Float>,
        u: Float,
        v: Float,
        v0Point: SIMD3<Float>
    ) -> (p: SIMD3<Float>, n: SIMD3<Float>) {
        // Point on axis line at parameter v, anchored at v0Point:
        // axisPoint(v) = v0Point + v * axis
        let axisPoint = v0Point + v * axis
        let radial = cos(u) * xDir + sin(u) * zDir
        let p = axisPoint + radius * radial
        let n = simd_normalize(radial)
        return (p, n)
    }

    @inline(__always)
    private func planeEval(origin: SIMD3<Float>, u: SIMD3<Float>, v: SIMD3<Float>, uv: SIMD2<Float>) -> SIMD3<Float> {
        origin + uv.x * u + uv.y * v
    }

    /// Tessellate an analytic cylinder B-Rep that follows the conventions of the earlier `addAnalyticCylinder`:
    /// - side face: `.cylinder(origin:center, axis, radius, xDir, zDir)`
    /// - top/bottom faces: `.plane(origin at cap center, u=xDir, v=zDir)`
    ///
    /// Assumptions:
    /// - The cylinder trimming is the standard rectangle in (u,v): u ∈ [0, 2π], v ∈ [0, height].
    /// - The cap trimming is a disk of radius `radius` in the plane’s (u,v) coords.
    ///
    /// Returns a mesh with duplicated vertices for side vs caps (correct shading).
    func tessellateAnalyticCylinder(
        sideFaceID: FaceID,
        topFaceID: FaceID,
        bottomFaceID: FaceID,
        radialSegments: Int = 64,
        heightSegments: Int = 1
    ) -> TriMesh {
        precondition(radialSegments >= 3)
        precondition(heightSegments >= 1)

        // --- Extract surfaces ---
        guard case let .cylinder(center, axisRaw, radius, xDirRaw, zDirRaw) = faces[sideFaceID.raw].surface else {
            preconditionFailure("sideFaceID is not a cylinder surface.")
        }
        guard case let .plane(topO, topU, topV) = faces[topFaceID.raw].surface else {
            preconditionFailure("topFaceID is not a plane surface.")
        }
        guard case let .plane(botO, botU, botV) = faces[bottomFaceID.raw].surface else {
            preconditionFailure("bottomFaceID is not a plane surface.")
        }

        let (axis, xDir, zDir) = cylinderFrame(axisRaw: axisRaw, xDirRaw: xDirRaw, zDirRaw: zDirRaw)

        // Height from cap plane origins projected onto axis.
        // This works even if the cylinder axis isn’t +Y.
        let height = simd_dot((topO - botO), axis)
        precondition(height > 0, "Top and bottom planes must be separated along the cylinder axis.")

        // We want v=0 at bottom cap, v=height at top cap.
        // Choose v0Point as the point on the axis line aligned with the bottom cap center.
        // For a standard cylinder, botO is already on the axis; if not, project to axis line through `center`.
        // Axis line: L(t) = center + t*axis. Find t minimizing |(center + t*axis) - botO|.
        let t0 = simd_dot((botO - center), axis)
        let v0Point = center + t0 * axis  // this corresponds to v=0

        // Output buffers
        var positions: [SIMD3<Float>] = []
        var normals:   [SIMD3<Float>] = []
        var uvs:       [SIMD2<Float>] = []
        var indices:   [UInt32] = []

        positions.reserveCapacity((radialSegments + 1) * (heightSegments + 1) + 2 * (radialSegments + 1) + 2)
        normals.reserveCapacity(positions.capacity)
        uvs.reserveCapacity(positions.capacity)

        @inline(__always)
        func addVertex(_ p: SIMD3<Float>, _ n: SIMD3<Float>, _ uv: SIMD2<Float>) -> UInt32 {
            let i = UInt32(positions.count)
            positions.append(p)
            normals.append(n)
            uvs.append(uv)
            return i
        }

        // -------------------------
        // 1) Side (u,v rectangle)
        // -------------------------
        // Duplicate seam column (radialSegments+1) so UVs wrap cleanly.
        let cols = radialSegments + 1
        let rows = heightSegments + 1
        var sideVID = Array(repeating: UInt32(0), count: rows * cols)

        for r in 0..<rows {
            let tv = Float(r) / Float(heightSegments) // 0..1
            let v = tv * height

            for c in 0..<cols {
                let tu = Float(c) / Float(radialSegments) // 0..1 (with last == 1 at seam)
                let u = tu * (2 * Float.pi)

                let (p, n) = cylinderEval(origin: center, axis: axis, radius: radius, xDir: xDir, zDir: zDir,
                                         u: u, v: v, v0Point: v0Point)

                sideVID[r * cols + c] = addVertex(p, n, [tu, tv])
            }
        }

        // Side triangles
        for r in 0..<heightSegments {
            for c in 0..<radialSegments {
                let i00 = sideVID[r * cols + c]
                let i10 = sideVID[r * cols + (c + 1)]
                let i01 = sideVID[(r + 1) * cols + c]
                let i11 = sideVID[(r + 1) * cols + (c + 1)]

                // CCW when viewed from outside
                indices += [i00, i10, i11]
                indices += [i00, i11, i01]
            }
        }

        // -------------------------
        // 2) Top cap (disk)
        // -------------------------
        // Cap normal: for outward normal, it should point away from the solid.
        // For a cylinder with axis pointing "up", top cap outward is +axis.
        // But planeNormal(topU, topV) might be +axis or -axis depending on your basis.
        // We'll force it to +axis.
        var nTop = planeNormal(u: topU, v: topV)
        if simd_dot(nTop, axis) < 0 { nTop = -nTop }

        let topCenter = addVertex(topO, nTop, [0.5, 0.5])

        var topRing: [UInt32] = []
        topRing.reserveCapacity(radialSegments)

        for i in 0..<radialSegments {
            let t = (Float(i) / Float(radialSegments)) * (2 * Float.pi)
            let du = radius * cos(t)
            let dv = radius * sin(t)

            // In plane parameter coords, use (du,dv)
            let p = planeEval(origin: topO, u: topU, v: topV, uv: [du, dv])
            
            // Simple disk UV mapping (optional; stable)
            let uv = SIMD2<Float>(0.5 + du / (2 * radius), 0.5 + dv / (2 * radius))
            topRing.append(addVertex(p, nTop, uv))
        }

        for i in 0..<radialSegments {
            let j = (i + 1) % radialSegments
            // Ensure CCW when viewed along outward normal
            indices += [topCenter, topRing[j], topRing[i]]
        }

        // -------------------------
        // 3) Bottom cap (disk)
        // -------------------------
        // Outward bottom is -axis. Force plane normal to -axis.
        var nBot = planeNormal(u: botU, v: botV)
        if simd_dot(nBot, axis) > 0 { nBot = -nBot }

        let botCenter = addVertex(botO, nBot, [0.5, 0.5])

        var botRing: [UInt32] = []
        botRing.reserveCapacity(radialSegments)

        for i in 0..<radialSegments {
            let t = (Float(i) / Float(radialSegments)) * (2 * Float.pi)
            let du = radius * cos(t)
            let dv = radius * sin(t)

            let p = planeEval(origin: botO, u: botU, v: botV, uv: [du, dv])
            let uv = SIMD2<Float>(0.5 + du / (2 * radius), 0.5 + dv / (2 * radius))
            botRing.append(addVertex(p, nBot, uv))
        }

        for i in 0..<radialSegments {
            let j = (i + 1) % radialSegments
            // Flip winding relative to top
            indices += [botCenter, botRing[i], botRing[j]]
        }

        return TriMesh(positions: positions, normals: normals, uvs: uvs, indices: indices)
    }
}
