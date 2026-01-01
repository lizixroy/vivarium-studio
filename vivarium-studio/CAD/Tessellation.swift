//
//  Tessellation.swift
//  vivarium-studio
//
//  Created by Roy Li on 1/1/26.
//

import Foundation

import RealityKit

public struct TessellationOptions {
    public var flatShaded: Bool = true
    public init(flatShaded: Bool = true) { self.flatShaded = flatShaded }
}

//public func tessellateToRealityKitMesh(_ brep: BRep, options: TessellationOptions = .init()) throws -> MeshResource {
//    var positions: [SIMD3<Float>] = []
//    var normals: [SIMD3<Float>] = []
//    var indices: [UInt32] = []
//
//    positions.reserveCapacity(brep.faces.count * 6) // rough
//    normals.reserveCapacity(brep.faces.count * 6)
//    indices.reserveCapacity(brep.faces.count * 6)
//
//    func loopVertexIDs(for face: Face) -> [VertexID] {
//        let loop = brep.loops[face.outerLoop.raw]
//        var result: [VertexID] = []
//
//        var start = loop.anyHalfEdge
//        var he = start
//        repeat {
//            let originVID = brep.halfEdges[he.raw].origin
//            result.append(originVID)
//            guard let next = brep.halfEdges[he.raw].next else { break }
//            he = next
//        } while he != start
//
//        return result
//    }
//
//    func polygonNormal(_ vids: [VertexID], fallback: SIMD3<Float>) -> SIMD3<Float> {
//        // Use cached hint if present (already normalized)
//        // But recompute from positions to be safe with edits.
//        var n = SIMD3<Float>(repeating: 0)
//        let m = vids.count
//        for i in 0..<m {
//            let p0 = brep.vertices[vids[i].raw].position
//            let p1 = brep.vertices[vids[(i + 1) % m].raw].position
//            n.x += (p0.y - p1.y) * (p0.z + p1.z)
//            n.y += (p0.z - p1.z) * (p0.x + p1.x)
//            n.z += (p0.x - p1.x) * (p0.y + p1.y)
//        }
//        let len = simd_length(n)
//        return (len > 1e-8) ? (n / len) : fallback
//    }
//
//    for face in brep.faces {
//        let vids = loopVertexIDs(for: face)
//        guard vids.count >= 3 else { continue }
//
//        let faceN = polygonNormal(vids, fallback: face.normalHint ?? SIMD3<Float>(0, 1, 0))
//
//        if options.flatShaded {
//            // Duplicate vertices per face, so each face gets a constant normal (sharp edges).
//            let base = UInt32(positions.count)
//
//            // Emit polygon vertices
//            for vid in vids {
//                positions.append(brep.vertices[vid.raw].position)
//                normals.append(faceN)
//            }
//
//            // Fan triangulation: (0, i, i+1)
//            for i in 1..<(vids.count - 1) {
//                indices.append(base + 0)
//                indices.append(base + UInt32(i))
//                indices.append(base + UInt32(i + 1))
//            }
//        } else {
//            // Shared-vertex mode (smooth shading). For a real CAD tessellator you’d
//            // want vertex normal averaging + crease handling. Here we keep it simple.
//            //
//            // We'll still duplicate per face to avoid building a global index map,
//            // but we compute per-triangle normals instead (still mostly flat).
//            let base = UInt32(positions.count)
//            for vid in vids {
//                positions.append(brep.vertices[vid.raw].position)
//                normals.append(faceN) // simplistic
//            }
//            for i in 1..<(vids.count - 1) {
//                indices.append(base + 0)
//                indices.append(base + UInt32(i))
//                indices.append(base + UInt32(i + 1))
//            }
//        }
//    }
//
//    var desc = MeshDescriptor()
//
//    desc.positions = MeshBuffers.Positions(positions)
//    desc.normals   = MeshBuffers.Normals(normals)
//    desc.primitives = .triangles(indices)
//
//    return try MeshResource.generate(from: [desc])
//}
