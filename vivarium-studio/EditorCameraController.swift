//
//  EditorCameraController.swift
//  vivarium-studio
//
//  Created by Roy Li on 12/17/25.
//

import Foundation
import RealityKit
import simd

final class EditorCameraController {
    let rig = Entity()
    private let pitchNode = Entity()
    let camera = PerspectiveCamera()

    // State
    var yaw: Float = 0
    var pitch: Float = 0
    // var position = SIMD3<Float>(0, 1.6, 3) // start a bit back

    var position: SIMD3<Float>
    
    // Tunables
    var lookSensitivity: Float = 0.004
    var moveSpeed: Float = 2.5          // m/s
    var fastMultiplier: Float = 4.0
    var panSensitivity: Float = 0.002
    var scrollSensitivity: Float = 0.15

    init(position: SIMD3<Float> = .zero) {
        self.position = position
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
    
    
}
