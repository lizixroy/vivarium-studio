import Foundation
import RealityKit
import simd

public enum MeshBuilder {
    /// Generates a rectangular prism mesh centered at the origin.
    public static func makePrism(width: Float, height: Float, length: Float) -> MeshResource {
        let hx = width / 2
        let hy = height / 2
        let hz = length / 2

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []

        func addFace(_ p0: SIMD3<Float>, _ p1: SIMD3<Float>, _ p2: SIMD3<Float>, _ p3: SIMD3<Float>, n: SIMD3<Float>) {
            positions.append(contentsOf: [p0,p1,p2,p3])
            normals.append(contentsOf: [n,n,n,n])
            uvs.append(contentsOf: [SIMD2<Float>(0,0), SIMD2<Float>(1,0), SIMD2<Float>(1,1), SIMD2<Float>(0,1)])
        }

        addFace([ -hx,  hy, -hz], [  hx,  hy, -hz], [  hx,  hy,  hz], [ -hx,  hy,  hz], n: [0,1,0])
        addFace([ -hx, -hy,  hz], [  hx, -hy,  hz], [  hx, -hy, -hz], [ -hx, -hy, -hz], n: [0,-1,0])
        addFace([ -hx, -hy,  hz], [  hx, -hy,  hz], [  hx,  hy,  hz], [ -hx,  hy,  hz], n: [0,0,1])
        addFace([  hx, -hy, -hz], [ -hx, -hy, -hz], [ -hx,  hy, -hz], [  hx,  hy, -hz], n: [0,0,-1])
        addFace([  hx, -hy,  hz], [  hx, -hy, -hz], [  hx,  hy, -hz], [  hx,  hy,  hz], n: [1,0,0])
        addFace([ -hx, -hy, -hz], [ -hx, -hy,  hz], [ -hx,  hy,  hz], [ -hx,  hy, -hz], n: [-1,0,0])

        var indices: [UInt32] = []
        indices.reserveCapacity(36)
        for f in 0..<6 {
            let i = UInt32(f * 4)
            indices.append(contentsOf: [i+0, i+1, i+2, i+0, i+2, i+3])
        }

        var desc = MeshDescriptor()
        desc.positions = MeshBuffer(positions)
        desc.normals = MeshBuffer(normals)
        desc.textureCoordinates = MeshBuffer(uvs)
        desc.primitives = .triangles(indices)

        do { return try MeshResource.generate(from: [desc]) }
        catch { return .generateBox(size: [width, height, length]) }
    }

    public static func mesh(for primitive: Primitive) -> MeshResource {
        switch primitive {
        case let .box(w, h, l):
            return makePrism(width: w, height: h, length: l)
        }
    }
}
