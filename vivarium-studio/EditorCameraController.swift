//
//  EditorCameraController.swift
//  vivarium-studio
//
//  Created by Roy Li on 12/17/25.
//

import Foundation
import RealityKit
import simd

// The distance between the position of the camera fig and the orbit pivot. This should be adjustable by the user later.
private let distanceFromPositionToPivot: Float = 1

final class EditorCameraController {
    private let rig = Entity()
    private let pitchNode = Entity()
    let camera = PerspectiveCamera()

    // State
    var yaw: Float = 0
    var pitch: Float = 0
    var position: SIMD3<Float>
    
    // Tunables
    var lookSensitivity: Float = 0.004
    var moveSpeed: Float = 2.5          // m/s
    var fastMultiplier: Float = 4.0
    var panSensitivity: Float = 0.002
    var scrollSensitivity: Float = 0.15

    init(position: SIMD3<Float> = .zero) {
        self.position = position
        rig.position = position
        rig.addChild(pitchNode)
        pitchNode.addChild(camera)

        camera.camera.near = 0.01
        camera.camera.far = 2000
    }

    func attach(to arView: ARView) {
        arView.scene.addAnchor(AnchorEntity(world: .zero)) // if you don't already have one
        arView.scene.anchors[0].addChild(rig)
        applyTransforms()
    }

    func applyTransforms() {
        // Clamp pitch to avoid flipping
        pitch = max(-(.pi * 0.49), min(.pi * 0.49, pitch))
        rig.position = position
        rig.orientation = simd_quatf(angle: yaw, axis: [0,1,0])
        pitchNode.orientation = simd_quatf(angle: pitch, axis: [1,0,0])
    }

    // Helpers to get camera basis vectors in world space
    var forward: SIMD3<Float> {
        // -Z is forward in RealityKit camera space
        let q = rig.orientation * pitchNode.orientation
        return simd_normalize(q.act([0,0,-1]))
    }
    var right: SIMD3<Float> {
        let q = rig.orientation * pitchNode.orientation
        return simd_normalize(q.act([1,0,0]))
    }
    var up: SIMD3<Float> { [0,1,0] } // world-up pan feels “editor like”
    
    var projectionOntoXZPlane: SIMD3<Float> {
        return forward.projectionOntoXZPlane
    }

    func yawPivot() -> SIMD3<Float> {
        return (forward.normalizedProjectionOntoXZPlane) * distanceFromPositionToPivot + position
    }
    
    func yaw(angle: Float) {
        let pivot = yawPivot()
        self.yaw += angle
        let yawDelta = simd_quatf(angle: angle, axis: [0,1,0])
        
        // Position: rotate the offset vector around the pivot.
        let C = rig.position(relativeTo: nil)
        let r = C - pivot
        let r2 = yawDelta.act(r)
        let C2 = pivot + r2
        position = C2
        
        // Orientation: look at the pivot.
        let toPivot = normalize(pivot - C2)
        let up: SIMD3<Float> = [0, 1, 0]
        rig.setOrientation(lookRotation(forward: toPivot, up: up), relativeTo: nil)
        applyTransforms()
    }

    private func lookRotation(forward desiredLook: SIMD3<Float>, up worldUp: SIMD3<Float>) -> simd_quatf {
        // RealityKit camera looks along local -Z, so local +Z should point opposite desired look
        let f = normalize(-desiredLook)
        
        var r = cross(worldUp, f)
        let rl = simd_length(r)
        if rl < 1e-6 {
            // forward almost parallel to up; choose fallback up
            let fallbackUp: SIMD3<Float> = abs(f.y) < 0.99 ? [0,1,0] : [0,0,1]
            r = cross(fallbackUp, f)
        }
        r = normalize(r)
        let u2 = cross(f, r) // corrected up, orthogonal
        
        let m = float3x3(columns: (r, u2, f))
        return simd_quatf(m)
    }

}
