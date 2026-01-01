import Foundation
import simd

// MARK: - Parametric primitives

public enum Primitive: Equatable, Sendable {
    case box(width: Float, height: Float, length: Float) // length == Z extent

    public var extents: SIMD3<Float> {
        switch self {
        case let .box(w, h, l): return SIMD3<Float>(w, h, l)
        }
    }
}

// MARK: - Minimal Transform (engine-agnostic)

public struct Transform3D: Equatable, Sendable {
    public var position: SIMD3<Float>
    public var rotation: simd_quatf
    public var scale: SIMD3<Float>

    public init(position: SIMD3<Float> = .zero,
                rotation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0)),
                scale: SIMD3<Float> = SIMD3<Float>(repeating: 1)) {
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }

    public static let identity = Transform3D()

    public func composed(with parent: Transform3D) -> Transform3D {
        // Parent-first composition: x_world = parent * self
        // Scale is simplified (uniform scale recommended for now).
        let rotatedPos = parent.rotation.act(self.position * parent.scale)
        return Transform3D(
            position: parent.position + rotatedPos,
            rotation: parent.rotation * self.rotation,
            scale: parent.scale * self.scale
        )
    }
}

// MARK: - CSG Tree

public indirect enum CSGNode: Sendable {
    case primitive(Primitive, local: Transform3D)
    case union([CSGNode])
    case subtract(CSGNode, CSGNode)
    case intersect(CSGNode, CSGNode) // placeholder
}

public struct PrimitiveInstance: Equatable, Sendable {
    public var primitive: Primitive
    public var world: Transform3D
    public init(primitive: Primitive, world: Transform3D) {
        self.primitive = primitive
        self.world = world
    }
}

// MARK: - Axis-aligned subtraction support

public struct AABB: Equatable, Sendable {
    public var min: SIMD3<Float>
    public var max: SIMD3<Float>
    public init(min: SIMD3<Float>, max: SIMD3<Float>) { self.min = min; self.max = max }
    public var size: SIMD3<Float> { max - min }
    public var center: SIMD3<Float> { (min + max) * 0.5 }
}

@inline(__always)
private func approxIdentity(_ q: simd_quatf, eps: Float = 1e-4) -> Bool {
    // Identity rotation is (0,0,0,1) or (0,0,0,-1)
    let v = q.vector
    return abs(v.x) < eps && abs(v.y) < eps && abs(v.z) < eps && abs(abs(v.w) - 1) < eps
}

// MARK: - Evaluation

public enum CSGEvaluator {

    /// Evaluate a CSG node into a list of box primitives.
    /// - union: flattens
    /// - subtract: implemented for axis-aligned boxes using AABB splitting
    /// - intersect: placeholder (returns A)
    public static func evaluate(_ node: CSGNode, parent: Transform3D = .identity) -> [PrimitiveInstance] {
        switch node {
        case let .primitive(p, local):
            return [PrimitiveInstance(primitive: p, world: local.composed(with: parent))]

        case let .union(children):
            return children.flatMap { evaluate($0, parent: parent) }

        case let .subtract(a, b):
            let A = evaluate(a, parent: parent)
            let B = evaluate(b, parent: parent)
            return subtract(A, by: B)

        case let .intersect(a, _):
            return evaluate(a, parent: parent)
        }
    }

    private static func subtract(_ aInstances: [PrimitiveInstance], by bInstances: [PrimitiveInstance]) -> [PrimitiveInstance] {
        var current = aInstances
        for b in bInstances {
            current = current.flatMap { subtractOne($0, by: b) }
            if current.isEmpty { break }
        }
        return current
    }

    private static func subtractOne(_ a: PrimitiveInstance, by b: PrimitiveInstance) -> [PrimitiveInstance] {
        guard case let .box(aw, ah, al) = a.primitive,
              case let .box(bw, bh, bl) = b.primitive else { return [a] }

        // MVP constraint: axis-aligned (identity rotation)
        guard approxIdentity(a.world.rotation), approxIdentity(b.world.rotation) else { return [a] }

        let aExt = SIMD3<Float>(aw, ah, al) * a.world.scale
        let bExt = SIMD3<Float>(bw, bh, bl) * b.world.scale

        let aHalf = aExt * 0.5
        let bHalf = bExt * 0.5

        let aAABB = AABB(min: a.world.position - aHalf, max: a.world.position + aHalf)
        let bAABB = AABB(min: b.world.position - bHalf, max: b.world.position + bHalf)

        let pieces = subtractAABB(aAABB, bAABB)
        return pieces.map(aabbToInstance)
    }

    /// Returns disjoint AABBs approximating A - (A ∩ B) for axis-aligned boxes.
    private static func subtractAABB(_ a: AABB, _ b: AABB, eps: Float = 1e-6) -> [AABB] {
        let iMin = simd_max(a.min, b.min)
        let iMax = simd_min(a.max, b.max)

        // No overlap
        if iMin.x >= iMax.x - eps || iMin.y >= iMax.y - eps || iMin.z >= iMax.z - eps {
            return [a]
        }

        // B fully covers A
        if b.min.x <= a.min.x + eps && b.max.x >= a.max.x - eps &&
           b.min.y <= a.min.y + eps && b.max.y >= a.max.y - eps &&
           b.min.z <= a.min.z + eps && b.max.z >= a.max.z - eps {
            return []
        }

        var out: [AABB] = []
        out.reserveCapacity(6)

        // Slabs around the intersection volume.
        if a.min.x < iMin.x - eps {
            out.append(AABB(min: SIMD3<Float>(a.min.x, a.min.y, a.min.z),
                            max: SIMD3<Float>(iMin.x,  a.max.y, a.max.z)))
        }
        if iMax.x < a.max.x - eps {
            out.append(AABB(min: SIMD3<Float>(iMax.x, a.min.y, a.min.z),
                            max: SIMD3<Float>(a.max.x, a.max.y, a.max.z)))
        }

        let mx0 = iMin.x, mx1 = iMax.x

        if a.min.y < iMin.y - eps {
            out.append(AABB(min: SIMD3<Float>(mx0, a.min.y, a.min.z),
                            max: SIMD3<Float>(mx1, iMin.y, a.max.z)))
        }
        if iMax.y < a.max.y - eps {
            out.append(AABB(min: SIMD3<Float>(mx0, iMax.y, a.min.z),
                            max: SIMD3<Float>(mx1, a.max.y, a.max.z)))
        }

        let my0 = iMin.y, my1 = iMax.y

        if a.min.z < iMin.z - eps {
            out.append(AABB(min: SIMD3<Float>(mx0, my0, a.min.z),
                            max: SIMD3<Float>(mx1, my1, iMin.z)))
        }
        if iMax.z < a.max.z - eps {
            out.append(AABB(min: SIMD3<Float>(mx0, my0, iMax.z),
                            max: SIMD3<Float>(mx1, my1, a.max.z)))
        }

        return out.filter { box in
            let s = box.size
            return s.x > eps && s.y > eps && s.z > eps
        }
    }

    private static func aabbToInstance(_ aabb: AABB) -> PrimitiveInstance {
        let s = aabb.size
        let p = Primitive.box(width: s.x, height: s.y, length: s.z)
        let t = Transform3D(position: aabb.center,
                            rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0)),
                            scale: SIMD3<Float>(repeating: 1))
        return PrimitiveInstance(primitive: p, world: t)
    }
}
