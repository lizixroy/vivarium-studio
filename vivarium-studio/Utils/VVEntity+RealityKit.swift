//
//  VVEntity+RealityKit.swift
//  vivarium-studio
//
//  Created by Roy Li on 1/27/26.
//

import Foundation
import RealityKit
import simd
import AppKit
import CoreGraphics

// MARK: - Public entry point

enum VVRealityKitConverter {
    /// Convert your VVEntity scene graph to RealityKit Entities for rendering.
    /// Must run on main actor (RealityKit resource creation / scene mutation).
    @MainActor
    static func makeRealityKitEntity(from vvRoot: VVEntity) throws -> Entity {
        return try convert(vvRoot)
    }
}

// MARK: - Core conversion

@MainActor
private func convert(_ vv: VVEntity) throws -> Entity {
    // 1) Create an RK entity for this node
    let rk: Entity

    if let vvModel = vv as? VVModelEntity {
        rk = try makeModelEntity(from: vvModel)
    } else {
        rk = Entity()
    }

    // 2) Apply transform
    applyTransform(from: vv, to: rk)

    // 3) Recurse children
    for c in vv.children {
        let childRK = try convert(c)
        rk.addChild(childRK)
    }

    return rk
}

@MainActor
private func applyTransform(from vv: VVEntity, to rk: Entity) {
    // VVEntity stores both matrix + TRS. Prefer matrix if it's not identity.
    if !vv.matrix.isApproximatelyIdentity {
        rk.transform.matrix = vv.matrix
    } else {
        rk.transform.translation = vv.translation
        rk.transform.rotation = vv.rotation
        rk.transform.scale = vv.scale
    }
}

// MARK: - VVModelEntity -> ModelEntity

@MainActor
private func makeModelEntity(from vv: VVModelEntity) throws -> ModelEntity {

    guard let positions = vv.positions, !positions.isEmpty else {
        // Empty mesh: represent as empty Entity (or throw)
        return ModelEntity() // safe placeholder
    }

    // Indices: if missing, generate 0..n-1
    let indices: [UInt32]
    if let vvIdx = vv.indices, !vvIdx.isEmpty {
        indices = vvIdx
    } else {
        indices = Array(0..<UInt32(positions.count))
    }

    // Build mesh descriptor
    var desc = MeshDescriptor()
    desc.positions = MeshBuffers.Positions(positions)

    if let normals = vv.normals, normals.count == positions.count {
        desc.normals = MeshBuffers.Normals(normals)
    }

    if let uvs = vv.uvs, uvs.count == positions.count {
        desc.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
    }

    desc.primitives = .triangles(indices)

    let mesh = try MeshResource.generate(from: [desc])

    // Material
    let mat: Material
    if let vvMat = vv.material {
        mat = try buildPhysicallyBasedMaterial(from: vvMat)
    } else {
        // reasonable default
        mat = SimpleMaterial(color: .lightGray, isMetallic: false)
    }

    let model = ModelEntity(mesh: mesh, materials: [mat])
    return model
}

// MARK: - VVEntityMaterial -> PhysicallyBasedMaterial

@MainActor
private func buildPhysicallyBasedMaterial(from vv: VVEntityMaterial) throws -> PhysicallyBasedMaterial {
    var m = PhysicallyBasedMaterial()

    // ---- Base Color (sRGB) ----
    if let baseMap = vv.baseColorMap {
        let tex = try TextureResource(
            image: baseMap,
            options: .init(semantic: .color) // sRGB-ish
        )
        m.baseColor = .init(texture: .init(tex))
    } else {
        let f = vv.baseColorFactor
        m.baseColor = .init(
            tint: .init(
                red: CGFloat(f.x),
                green: CGFloat(f.y),
                blue: CGFloat(f.z),
                alpha: CGFloat(f.w)
            )
        )
    }

    // ---- Roughness (linear/data) ----
    if let roughMap = vv.roughnessMap {
        let tex = try TextureResource(image: roughMap, options: .init(semantic: .raw))
        m.roughness = .init(texture: .init(tex))
    } else if let r = vv.roughnessFloatLiteral {
        m.roughness = .init(floatLiteral: r)
    }

    // ---- Metallic (linear/data) ----
    if let metalMap = vv.metallicMap {
        let tex = try TextureResource(image: metalMap, options: .init(semantic: .raw))
        m.metallic = .init(texture: .init(tex))
    } else if let mm = vv.metallicFloatLiteral {
        m.metallic = .init(floatLiteral: mm)
    }

    // ---- Normal (linear/data) ----
    if let normalMap = vv.normalMap {
        let tex = try TextureResource(image: normalMap, options: .init(semantic: .raw))
        m.normal = .init(texture: .init(tex))
    }

    // ---- Emissive (sRGB) ----
    if let emissiveMap = vv.emissiveColorMap {
        let tex = try TextureResource(image: emissiveMap, options: .init(semantic: .color))
        m.emissiveColor = .init(texture: .init(tex))
    } else if let emissive = vv.emissiveColor {
        m.emissiveColor = .init(color: emissive)
    }

    // ---- Opacity / Blending ----
    if let blending = vv.blendingMode {
        switch blending {
        case .opaque:
            // default
            break
        case .transparent(let opacity):
            m.blending = .transparent(opacity: .init(floatLiteral: opacity))
        }
    }

    // If you have an opacity texture map, RealityKit doesn't offer a direct
    // "opacityTexture" slot on PhysicallyBasedMaterial in the same way glTF does.
    // A common approach is to multiply alpha into baseColor, or use CustomMaterial.
    // Here we do a simple baseColor alpha modulation if provided.
    if let opacityMap = vv.blendingModeMap {
        // Treat as data
        let tex = try TextureResource(image: opacityMap, options: .init(semantic: .raw))
        // No direct slot => best-effort: attach as baseColor alpha via custom pipeline later.
        // For now, you can leave it unused or switch to CustomMaterial for true textured opacity.
        _ = tex
    }

    // Alpha test threshold (useful for MASK style)
    m.opacityThreshold = vv.opacityThreshold

    // ---- Double sided ----
    if vv.doubleSided {
        m.faceCulling = .none
    }

    return m
}

// MARK: - Utilities

private extension simd_float4x4 {
    var isApproximatelyIdentity: Bool {
        let I = matrix_identity_float4x4
        let eps: Float = 1e-6

        let colsA = [self.columns.0, self.columns.1, self.columns.2, self.columns.3]
        let colsB = [I.columns.0,    I.columns.1,    I.columns.2,    I.columns.3]

        for i in 0..<4 {
            let a = colsA[i], b = colsB[i]
            if abs(a.x - b.x) > eps || abs(a.y - b.y) > eps || abs(a.z - b.z) > eps || abs(a.w - b.w) > eps {
                return false
            }
        }
        return true
    }
}
