//
//  VVMeshResource.swift
//  vivarium-studio
//
//  Created by Roy Li on 1/26/26.
//

import Foundation
import simd
import CoreImage
import AppKit

private let defaultBaseColorFactor = SIMD4<Float>(1, 1, 1, 1)

public class VVEntity {
        
    var matrix: float4x4 = matrix_identity_float4x4
    var translation: SIMD3<Float> = .zero
    var rotation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    var scale: SIMD3<Float> = SIMD3<Float>(repeating: 1)
    
    var children: [VVEntity] = []
    
    func addChild(_ child: VVEntity) {
        children.append(child)
    }
}

class VVModelEntity: VVEntity {
    var positions: [SIMD3<Float>]? = nil
    var normals: [SIMD3<Float>]? = nil
    var uvs: [SIMD2<Float>]? = nil
    var indices: [UInt32]? = nil
    var material: VVEntityMaterial? = nil
}

/// Creates an opacity object using a single value or a texture.
///
/// This initializer allows you to create an instance using either a
/// single value for the entire material or a UV-mapped image. If
/// `texture` is non-`nil`, RealityKit uses that image to determine the
/// material’s opacity and ignores `scale`. If `texture` is `nil`, then
/// it uses `scale` for the entire material.
///
enum VVEntityMaterialBlendingMode {
    case opaque
    case transparent(opacity: Float)
}

class VVEntityMaterial {
    
    // Base color
    var baseColorFactor: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1)
    var baseColorMap: CGImage?
    
    // Roughness
    var roughnessFloatLiteral: Float?
    var roughnessMap: CGImage?
    
    // Metallic
    var metallicFloatLiteral: Float?
    var metallicMap: CGImage?
    
    // Normal
    var normalMap: CGImage?
    
    // Emission
    var emissiveColor: NSColor?
    var emissiveColorMap: CGImage?
    
    // Opacity
    var blendingMode: VVEntityMaterialBlendingMode?
    var blendingModeMap: CGImage?
    
    var opacityThreshold: Float = 0.5
    var doubleSided: Bool = false
}

//class VVMaterial {
//    var floatLiteral: Float?
//    var textureImage: CGImage?
//}
//
//class VVMaterialMetallic: VVMaterial {}
//class VVMaterialRoughness: VVMaterial {}

/* RealityKit related support */
extension VVEntity {
    
}
