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

import simd

extension SIMD4 where Scalar == Float {
    init(v3 v: SIMD3<Float>, w: Float = 0) {
        self.init(v.x, v.y, v.z, w)
    }
}

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
    var cameraWorld: SIMD4<Float> = .zero
    var gridOrigin: SIMD4<Float> = .zero
    // baseCell, majorEvery, axisWidth, gridFadeDistance
    var params1: SIMD4<Float> = [0.1, 10.0, 2.0, 80.0];
    // minorIntensity, majorIntensity, axisIntensity, worldCameraHeight (TODO: figure a good default value).
    var params2: SIMD4<Float> = [0.20, 0.45, 0.85, 0.0];
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
            u.params1.x = 0.1 // baseCell
            u.params1.y = 10; // majorEvery
            u.params1.z = 2; // axisWidth
            u.params1.w = 80; // gridFadeDistance
            u.params2.x = 0.20; // minorIntensiy
            u.params2.y = 0.45; // majorIntensity
            u.params2.z = 0.85; // axisIntensity
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
            self.uniforms.cameraWorld = SIMD4<Float>(v3: camPos)

            // Keep the grid centered under the camera (XZ), so the plane acts infinite.
            // Optional: snap to avoid jitter.
//            let snap = max(self.uniforms.params1.x, 1e-3) * self.uniforms.params1.y
//            let snappedX = floor(camPos.x / snap) * snap
//            let snappedZ = floor(camPos.z / snap) * snap
//            self.entity.position.x = snappedX
//            self.entity.position.z = snappedZ

            // Push uniforms into the material.
            
            self.entity.updateMaterials { materials in
                guard var cm = materials[0] as? CustomMaterial else { return }

                // Update your uniforms (closure-based API on macOS)
                cm.withMutableUniforms(ofType: GridUniforms.self, stage: .surfaceShader) { u, _ in
                    u.cameraWorld = SIMD4<Float>(v3: camPos)
                    let camPos = cameraEntity.position(relativeTo: nil)
                    u.params2.w = max(abs(camPos.y), 1e-3)
                    print("camera height: \(camPos.y)")
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

