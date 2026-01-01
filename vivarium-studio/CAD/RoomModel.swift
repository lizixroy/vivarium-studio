import Foundation
import simd

public struct RoomParams: Equatable, Sendable {
    public var innerWidth: Float
    public var innerDepth: Float
    public var wallHeight: Float
    public var wallThickness: Float

    public init(innerWidth: Float = 3.0,
                innerDepth: Float = 4.0,
                wallHeight: Float = 2.5,
                wallThickness: Float = 0.15) {
        self.innerWidth = max(0.1, innerWidth)
        self.innerDepth = max(0.1, innerDepth)
        self.wallHeight = max(0.1, wallHeight)
        self.wallThickness = max(0.01, wallThickness)
    }
}

public enum RoomBuilder {

    /// Builds a CSG tree:
    ///   (OuterBlock - InnerVoid) - FrontWallCut
    /// Result is a U-shape: 3 walls, open front.
    public static func makeThreeWallRoomCSG(_ p: RoomParams) -> CSGNode {
        let w = p.innerWidth
        let d = p.innerDepth
        let h = p.wallHeight
        let t = p.wallThickness

        let outerW = w + 2*t
        let outerD = d + 2*t

        let outer = CSGNode.primitive(
            .box(width: outerW, height: h, length: outerD),
            local: Transform3D(position: SIMD3<Float>(0, h/2, 0))
        )

        let inner = CSGNode.primitive(
            .box(width: w, height: h, length: d),
            local: Transform3D(position: SIMD3<Float>(0, h/2, 0))
        )

        // Cut the front wall slab to open the room.
//        let frontCut = CSGNode.primitive(
//            .box(width: outerW + 0.01, height: h + 0.01, length: t + 0.02),
//            local: Transform3D(position: SIMD3<Float>(0, h/2, +outerD/2 - t/2))
//        )
        let frontCut = CSGNode.primitive(
            .box(width: outerW + 0.01, height: h + 0.01, length: t + 0.02),
            local: Transform3D(position: SIMD3<Float>(0, h/2, +outerD/2 - t/2))
        )

        return .subtract(.subtract(outer, inner), frontCut)
    }
    
    public static func makeHalfRoom(_ p: RoomParams) -> CSGNode {
        
        let w = p.innerWidth
        let d = p.innerDepth
        let h = p.wallHeight
        let t = p.wallThickness

        let outerW = w + 2 * t
        let outerD = d + 2 * t
        let outerH = h + 2 * t

        let outer = CSGNode.primitive(
            .box(width: outerW, height: outerH, length: outerD),
            local: Transform3D(position: SIMD3<Float>(0, 0, 0))
        )

        let inner = CSGNode.primitive(
            .box(width: w, height: h, length: d),
            local: Transform3D(position: SIMD3<Float>(0, 0, 0))
        )

        let leftCut = CSGNode.primitive(
            .box(width: t, height: h, length: outerD),
            local: Transform3D(position: SIMD3<Float>(0, 0, 0))
        )
        
        return .subtract(outer, inner)
    }
}
