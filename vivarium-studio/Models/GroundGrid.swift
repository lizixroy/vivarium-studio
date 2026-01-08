//
//  GroundGrid.swift
//  vivarium-studio
//
//  Created by Roy Li on 1/7/26.
//

import Foundation
import RealityKit
import Metal
import simd
import Combine

extension ModelEntity {
    /// Safely mutate this entity's ModelComponent materials in-place.
    func updateMaterials(_ body: (inout [Material]) -> Void) {
        guard var model = self.components[ModelComponent.self] else { return }
        var mats = model.materials
        body(&mats)
        model.materials = mats
        self.components.set(model)
    }
}
/// RealityKit ↔ Metal uniform buffer layout must match GridUniforms in .metal
struct GridUniforms {
    var cameraWorld: SIMD3<Float> = .zero
    var _pad0: Float = 0

    var gridOrigin: SIMD3<Float> = .zero
    var _pad1: Float = 0

    var baseCell: Float = 0.1          // meters
    var majorEvery: Float = 10.0
    var axisWidth: Float = 2.0
    var gridFadeDistance: Float = 80.0

    var minorIntensity: Float = 0.20
    var majorIntensity: Float = 0.45
    var axisIntensity: Float = 0.85
}

final class GroundGridController {
    let entity: ModelEntity
    private var updateSub: Cancellable?
    private var uniforms = GridUniforms()

    /// Create a big plane, shaded procedurally as a grid.
    init?(planeSize: Float = 2000,
          y: Float = 0,
          baseCell: Float = 0.1)
    {
        // 1) Load the Metal function into a CustomMaterial surface shader program.
        // The shader is invoked as a surface shader and receives surface_parameters.  [oai_citation:4‡Apple Developer](https://developer.apple.com/metal/Metal-RealityKit-APIs.pdf)
//        let device = MTLCreateSystemDefaultDevice()!
//        let library = device.makeDefaultLibrary()!
//        let surface = CustomMaterial.SurfaceShader(named: "groundGridSurface", in: library)
//
//        // 2) Start from an Unlit custom material (editor grid usually wants emissive lines).
//        // If you prefer PBR lighting, switch to .lit.
//        guard var mat = try? CustomMaterial(from: UnlitMaterial(),
//                                            surfaceShader: surface) else { return nil }
//
//        // 3) Provide mutable uniforms so we can update camera position every frame.  [oai_citation:5‡Apple Developer](https://developer.apple.com/documentation/realitykit/custommaterial/withmutableuniforms%28oftype%3Astage%3A_%3A%29?utm_source=chatgpt.com)
//        uniforms.baseCell = baseCell
//        mat.withMutableUniforms(ofType: GridUniforms.self)
        
        let device = MTLCreateSystemDefaultDevice()!
        let library = device.makeDefaultLibrary()!

        let surface = CustomMaterial.SurfaceShader(
            named: "groundGridSurface",
            in: library
        )

        var mat = try! CustomMaterial(surfaceShader: surface, lightingModel: .unlit)
        mat.withMutableUniforms(ofType: GridUniforms.self, stage: .surfaceShader) { u, _ in
            // Set initial values (optional but nice)
            u.baseCell = 0.1
            u.majorEvery = 10
            u.axisWidth = 2
            u.gridFadeDistance = 80
            u.minorIntensity = 0.20
            u.majorIntensity = 0.45
            u.axisIntensity = 0.85
        }
        
        // 4) Create the plane mesh and entity.
        let mesh = MeshResource.generatePlane(width: planeSize, depth: planeSize)
        entity = ModelEntity(mesh: mesh, materials: [mat])

        // Place the plane at y = 0, facing up.
        entity.position = [0, y, 0]
        entity.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])

        // Disable shadows for an editor grid feel.
        entity.components.set(ModelComponent(mesh: mesh, materials: [mat]))
    }

    /// Call once after your camera entity exists.
    /// - Parameters:
    ///   - scene: RealityKit scene
    ///   - cameraEntity: your editor camera entity
    func startUpdating(scene: Scene, cameraEntity: Entity) {
        updateSub = scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            guard let self else { return }

            // Camera world position:
            let camPos = cameraEntity.position(relativeTo: nil)
            self.uniforms.cameraWorld = camPos

            // Keep the grid centered under the camera (XZ), so the plane acts infinite.
            // Optional: snap to avoid jitter.
            let snap = max(self.uniforms.baseCell, 1e-3) * self.uniforms.majorEvery
            let snappedX = floor(camPos.x / snap) * snap
            let snappedZ = floor(camPos.z / snap) * snap
            self.entity.position.x = snappedX
            self.entity.position.z = snappedZ

            // Push uniforms into the material.
            
            self.entity.updateMaterials { materials in
                guard var cm = materials[0] as? CustomMaterial else { return }

                // Update your uniforms (closure-based API on macOS)
                cm.withMutableUniforms(ofType: GridUniforms.self, stage: .surfaceShader) { u, _ in
                    u.cameraWorld = camPos
                }

                materials[0] = cm
            }
        }
    }

    func stopUpdating() {
        updateSub?.cancel()
        updateSub = nil
    }
}

