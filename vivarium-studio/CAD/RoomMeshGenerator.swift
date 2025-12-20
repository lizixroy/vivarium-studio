import Foundation
import RealityKit
import simd

enum RoomMeshGenerator {

    enum Face: CaseIterable, Hashable {
        case left, right, front, back, top, bottom
    }

    static func makeRoom(
        innerSize: SIMD3<Float>,
        wallThickness: Float,
        openFaces: Set<Face>,
        inwardNormals: Bool
    ) -> MeshResource {

        let w = innerSize.x
        let h = innerSize.y
        let d = innerSize.z
        _ = wallThickness

        let xL: Float = -w/2
        let xR: Float =  w/2
        let yB: Float = -h/2
        let yT: Float =  h/2
        let zF: Float =  d/2
        let zBk: Float = -d/2

        struct Quad {
            var face: Face
            var p0: SIMD3<Float>
            var p1: SIMD3<Float>
            var p2: SIMD3<Float>
            var p3: SIMD3<Float>
            var n: SIMD3<Float>
        }

        var quads: [Quad] = [
            Quad(face: .left,
                 p0: [xL, yB, zBk], p1: [xL, yB, zF], p2: [xL, yT, zF], p3: [xL, yT, zBk],
                 n:  [ 1, 0, 0]),
            Quad(face: .right,
                 p0: [xR, yB, zF], p1: [xR, yB, zBk], p2: [xR, yT, zBk], p3: [xR, yT, zF],
                 n:  [-1, 0, 0]),
            Quad(face: .front,
                 p0: [xL, yB, zF], p1: [xR, yB, zF], p2: [xR, yT, zF], p3: [xL, yT, zF],
                 n:  [0, 0,-1]),
            Quad(face: .back,
                 p0: [xR, yB, zBk], p1: [xL, yB, zBk], p2: [xL, yT, zBk], p3: [xR, yT, zBk],
                 n:  [0, 0, 1]),
            Quad(face: .top,
                 p0: [xL, yT, zF], p1: [xR, yT, zF], p2: [xR, yT, zBk], p3: [xL, yT, zBk],
                 n:  [0,-1, 0]),
            Quad(face: .bottom,
                 p0: [xL, yB, zBk], p1: [xR, yB, zBk], p2: [xR, yB, zF], p3: [xL, yB, zF],
                 n:  [0, 1, 0]),
        ]

        quads.removeAll { openFaces.contains($0.face) }

//        if !inwardNormals {
            for i in quads.indices {
                quads[i].n *= -1
                let tmp = quads[i].p1
                quads[i].p1 = quads[i].p3
                quads[i].p3 = tmp
            }
//        }

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for q in quads {
            let base = UInt32(positions.count)
            positions.append(contentsOf: [q.p0, q.p1, q.p2, q.p3])
            normals.append(contentsOf: [q.n, q.n, q.n, q.n])
            indices.append(contentsOf: [
                base + 0, base + 1, base + 2,
                base + 0, base + 2, base + 3
            ])
        }

        var desc = MeshDescriptor(name: "ProceduralRoom")
        desc.positions = MeshBuffers.Positions(positions)
        desc.normals = MeshBuffers.Normals(normals)
        desc.primitives = .triangles(indices)

        do { return try MeshResource.generate(from: [desc]) }
        catch { return .generateBox(size: 0.001) }
    }
}
