//
//  Tessellation.swift
//  vivarium-studio
//
//  Created by Roy Li on 1/1/26.
//

import Foundation
import simd
import RealityKit

public struct TessellationOptions {
    /// Duplicate vertices per face and use a single constant normal per face.
    /// This produces sharp edges (correct for a box).
    public var flatShaded: Bool = true

    /// If true, we will enforce a consistent triangle winding per face by comparing
    /// computed polygon normal with the face's "expected" normal hint if provided externally.
    /// For a pure box from makeBox() you can keep this false.
    public var fixWinding: Bool = false

    /// If fixWinding is enabled, this is used when the face normal is degenerate.
    public var fallbackNormal: SIMD3<Float> = SIMD3<Float>(0, 1, 0)

    public init(flatShaded: Bool = true,
                fixWinding: Bool = false,
                fallbackNormal: SIMD3<Float> = SIMD3<Float>(0, 1, 0)) {
        self.flatShaded = flatShaded
        self.fixWinding = fixWinding
        self.fallbackNormal = fallbackNormal
    }
}

public enum TessellationError: Error {
    case invalidFaceLoop(face: Int)
    case notEnoughVertices(face: Int)
}

/// Tessellate a (planar) B-Rep into a RealityKit MeshResource.
/// This implementation supports convex planar faces (e.g. box quads).
///
/// - For a box: perfect.
/// - For concave faces: you'd swap fan triangulation with ear clipping (later).
public func tessellateBoxBRepToRealityKitMesh(
    _ brep: BRep,
    options: TessellationOptions = .init()
) throws -> MeshResource {

    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []

    // Rough capacity guesses: 6 faces * 4 verts = 24, 12 triangles = 36 indices
    positions.reserveCapacity(max(24, brep.faces.count * 4))
    normals.reserveCapacity(positions.capacity)
    indices.reserveCapacity(max(36, brep.faces.count * 6))

    // MARK: - Helpers

    func loopVertexIDs(for faceID: FaceID) throws -> [VertexID] {
        let face = brep.faces[faceID.raw]
        let loop = brep.loops[face.outer.raw]
        let start = loop.halfEdge

        guard start.raw >= 0 && start.raw < brep.halfEdges.count else {
            throw TessellationError.invalidFaceLoop(face: faceID.raw)
        }

        var result: [VertexID] = []
        var visited = Set<Int>()

        var he = start
        while !visited.contains(he.raw) {
            visited.insert(he.raw)
            let h = brep.halfEdges[he.raw]
            // Use fromVertex to produce a ring: v0,v1,v2,... around the loop
            result.append(h.fromVertex)
            he = h.next

            if he.raw < 0 || he.raw >= brep.halfEdges.count {
                throw TessellationError.invalidFaceLoop(face: faceID.raw)
            }
        }

        return result
    }

    // Newell normal (stable for polygons)
    func polygonNormal(_ vids: [VertexID], fallback: SIMD3<Float>) -> SIMD3<Float> {
        var n = SIMD3<Float>(repeating: 0)
        let m = vids.count
        for i in 0..<m {
            let p0 = brep.vertices[vids[i].raw].position
            let p1 = brep.vertices[vids[(i + 1) % m].raw].position
            n.x += (p0.y - p1.y) * (p0.z + p1.z)
            n.y += (p0.z - p1.z) * (p0.x + p1.x)
            n.z += (p0.x - p1.x) * (p0.y + p1.y)
        }
        let len = simd_length(n)
        return (len > 1e-8) ? (n / len) : simd_normalize(fallback)
    }

    // Optional expected normal for a box face based on its dominant axis.
    // This lets fixWinding work without storing face.normalHint.
    func expectedBoxNormal(for vids: [VertexID]) -> SIMD3<Float>? {
        // Compute axis-aligned normal from bbox of the face:
        // if all x are equal -> +/-X, all y equal -> +/-Y, all z equal -> +/-Z.
        // Then sign is inferred from computed normal.
        let pts = vids.map { brep.vertices[$0.raw].position }
        guard let p0 = pts.first else { return nil }

        var allX = true, allY = true, allZ = true
        for p in pts.dropFirst() {
            allX = allX && abs(p.x - p0.x) < 1e-6
            allY = allY && abs(p.y - p0.y) < 1e-6
            allZ = allZ && abs(p.z - p0.z) < 1e-6
        }
        if allX { return SIMD3<Float>(1, 0, 0) } // direction (sign fixed later)
        if allY { return SIMD3<Float>(0, 1, 0) }
        if allZ { return SIMD3<Float>(0, 0, 1) }
        return nil
    }

    // Fan triangulation indices for a convex polygon with vertices 0..(m-1)
    func emitFanTriangles(base: UInt32, vertexCount m: Int, into indices: inout [UInt32]) {
        guard m >= 3 else { return }
        for i in 1..<(m - 1) {
            indices.append(base + 0)
            indices.append(base + UInt32(i))
            indices.append(base + UInt32(i + 1))
        }
    }

    // MARK: - Tessellate faces

    for f in 0..<brep.faces.count {
        let faceID = FaceID(raw: f)
        let vids = try loopVertexIDs(for: faceID)
        guard vids.count >= 3 else { throw TessellationError.notEnoughVertices(face: f) }

        // Compute normal from current winding.
        let n = polygonNormal(vids, fallback: options.fallbackNormal)
        
        // Flat shading = duplicate vertices per face (perfect for a box)
        let base = UInt32(positions.count)

        positions.reserveCapacity(positions.count + vids.count)
        normals.reserveCapacity(normals.count + vids.count)

        for vid in vids {
            positions.append(brep.vertices[vid.raw].position)
            normals.append(n)
        }

        emitFanTriangles(base: base, vertexCount: vids.count, into: &indices)
    }

    // MARK: - Build RealityKit MeshResource

    var desc = MeshDescriptor()
    desc.positions = MeshBuffers.Positions(positions)
    desc.normals   = MeshBuffers.Normals(normals)
    desc.primitives = .triangles(indices)

    return try MeshResource.generate(from: [desc])
}
