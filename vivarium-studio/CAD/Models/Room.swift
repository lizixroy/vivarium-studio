//
//  Room.swift
//  vivarium-studio
//
//  Created by Roy Li on 1/6/26.
//
// A "Room" is a group Entity that can be shown as:
//  - .full: 6 sides (floor, ceiling, left, right, back, front)
//  - .half: 3 sides (floor, right, back) — good for interior visualization
//
// Each side is represented as a minimal planar BRep (quads), tessellated to a MeshResource.
//

import Foundation
import simd
import RealityKit

// MARK: - Room

public final class Room {
    public enum DisplayMode {
        case full   // 6 sides: floor, ceiling, left, right, back, front
        case half   // 3 sides: floor, right, back
    }

    public enum Side: CaseIterable {
        case floor, ceiling, leftWall, rightWall, backWall, frontWall

        public var entityName: String {
            switch self {
            case .floor: return "Floor"
            case .ceiling: return "Ceiling"
            case .leftWall: return "LeftWall"
            case .rightWall: return "RightWall"
            case .backWall: return "BackWall"
            case .frontWall: return "FrontWall"
            }
        }
    }

    public struct Params {
        public var width: Float      // X extent
        public var depth: Float      // Z extent
        public var height: Float     // Y extent
        public var wallThickness: Float
        public var floorThickness: Float
        public var ceilingThickness: Float

        public init(width: Float = 6,
                    depth: Float = 8,
                    height: Float = 3,
                    wallThickness: Float = 0.12,
                    floorThickness: Float = 0.12,
                    ceilingThickness: Float = 0.12)
        {
            self.width = width
            self.depth = depth
            self.height = height
            self.wallThickness = wallThickness
            self.floorThickness = floorThickness
            self.ceilingThickness = ceilingThickness
        }
    }

    // Public state
    public private(set) var params: Params
    public var displayMode: DisplayMode {
        didSet { rebuild() }
    }

    /// Root entity you add to your RealityKit scene.
    public let rootEntity: Entity = Entity()
    public private(set) var breps: [Side: BRep] = [:]

    /// Optional materials per-side; if nil, uses `defaultMaterial`.
    public var materials: [Side: Material] = [:]
    public var defaultMaterial: Material = SimpleMaterial(color: .gray, isMetallic: false)

    // Internal: side entities
    private var sideEntities: [Side: ModelEntity] = [:]

    public init(params: Params = .init(), displayMode: DisplayMode = .half) {
        self.params = params
        self.displayMode = displayMode
        rootEntity.name = "Room"
        rebuild()
    }

    public func setParams(_ newParams: Params) {
        self.params = newParams
        rebuild()
    }

    /// Convenience: move/rotate the whole room by transforming rootEntity.
    public var transform: Transform {
        get { rootEntity.transform }
        set { rootEntity.transform = newValue }
    }

    // MARK: - Build

    private func visibleSides(for mode: DisplayMode) -> Set<Side> {
        switch mode {
        case .half:
            return [.floor, .rightWall, .backWall]
        case .full:
            return Set(Side.allCases)
        }
    }

    private func rebuild() {
        let visible = visibleSides(for: displayMode)

        // Build/update BReps for all sides (even hidden ones, so toggling mode is instant).
        breps = buildSideBReps(params: params)

        // Ensure ModelEntities exist and are updated for visible sides; remove hidden ones.
        for side in Side.allCases {
            if visible.contains(side) {
                upsertSideEntity(side)
            } else {
                if let e = sideEntities[side] {
                    e.removeFromParent()
                }
            }
        }
    }

    private func upsertSideEntity(_ side: Side) {
        guard let brep = breps[side] else { return }

        let mat = materials[side] ?? defaultMaterial

        do {
            
            let mesh = try tessellateBoxBRepToRealityKitMesh(brep)
            
            if let existing = sideEntities[side] {
                existing.model = ModelComponent(mesh: mesh, materials: [mat])
            } else {
                let e = ModelEntity(mesh: mesh, materials: [mat])
                e.name = side.entityName
                sideEntities[side] = e
                rootEntity.addChild(e)
            }
        } catch {
            // In production you might log and show a placeholder mesh.
            print("Room: tessellation failed for \(side): \(error)")
        }
    }

    /// Builds each side as its own thin box (a watertight solid), which is very robust.
    /// Coordinate convention:
    /// - Room interior spans x:[0..W], z:[0..D], y:[0..H]
    /// - Floor thickness extends slightly below y=0
    /// - Walls thickness extends outward from the interior bounds (but you can change that if you prefer).
    private func buildSideBReps(params p: Params) -> [Side: BRep] {
        let W = p.width
        let D = p.depth
        let H = p.height
        let wt = p.wallThickness
        let ft = p.floorThickness
        let ct = p.ceilingThickness
        
        var out: [Side: BRep] = [:]

        // In order to make sure that the interior volume is precise as defined by the user, we choose to extend the wall volumnes outward, however, the thickness of the ceiling, floor, and 4 walls will make the sides protrude, causing undesired visual effect. To work around this, we extend the width and depth of the ceiling and floor, as well as the width of the front and back walls.
        
        let ceilingW = W + 2 * wt
        let ceilingD = D + 2 * wt
        let floorW = W + 2 * wt
        let floorD = displayMode == .full ? ( D + 2 * wt ) : ( D + wt )
        
        let floorCenter: SIMD3<Float> = (displayMode == .full) ? [W * 0.5, -ft * 0.5, D * 0.5] : [W * 0.5, -ft * 0.5, D * 0.5 - wt / 2] // Shift the wall toward -Z by wt / 2 to hide the otherwise protruding extension intended for fixing wall volume, which doesn't exist in half-room display mode.
        
        let backWallW = W + 2 * wt
        let frontWallW = W + 2 * wt
        
        // Floor: y in [-ft, 0]
        do {
            // let center: SIMD3<Float> = [W * 0.5, -ft * 0.5, D * 0.5]
            let center: SIMD3<Float> = floorCenter
            out[.floor] = BRep.makeBox(width: floorW, height: ft, depth: floorD, origin: center, anchor: .center)
        }

        // Ceiling: y in [H, H+ct]
        do {
            let center: SIMD3<Float> = [W * 0.5, H + ct * 0.5, D * 0.5]
            out[.ceiling] = BRep.makeBox(width: ceilingW, height: ct, depth: ceilingD, origin: center, anchor: .center)
        }

        // Back wall at z=0 (thickness extends toward -Z): z in [-wt, 0]
        do {
            let center: SIMD3<Float> = [W * 0.5, H * 0.5, -wt * 0.5]
            out[.backWall] = BRep.makeBox(width: backWallW, height: H, depth: wt, origin: center, anchor: .center)
        }

        // Front wall at z=D (thickness extends toward +Z): z in [D, D+wt]
        do {
            let center: SIMD3<Float> = [W * 0.5, H * 0.5, D + wt * 0.5]
            out[.frontWall] = BRep.makeBox(width: frontWallW, height: H, depth: wt, origin: center, anchor: .center)
        }

        // Left wall at x=0 (thickness extends toward -X): x in [-wt, 0]
        do {
            let center: SIMD3<Float> = [-wt * 0.5, H * 0.5, D * 0.5]
            out[.leftWall] = BRep.makeBox(width: wt, height: H, depth: D, origin: center, anchor: .center)
        }

        // Right wall at x=W (thickness extends toward +X): x in [W, W+wt]
        do {
            let center: SIMD3<Float> = [W + wt * 0.5, H * 0.5, D * 0.5]
            out[.rightWall] = BRep.makeBox(width: wt, height: H, depth: D, origin: center, anchor: .center)
        }

        return out
    }
}
