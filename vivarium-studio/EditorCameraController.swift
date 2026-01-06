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
// private let distanceFromPositionToPivot: Float = 1

final class EditorCameraController {
    private let rig = Entity()
    private let pitchNode = Entity()
    let camera = PerspectiveCamera()

    // State
    var yaw: Float = 0
    var pitch: Float = 0
    var position: SIMD3<Float>
    // The distance in the z direction between the camera node and the pitch ndoe.
    var cameraDistance: Float = 0.5
    
    // Tunables
    var lookSensitivity: Float = 0.004
    var moveSpeed: Float = 2.5          // m/s
    var fastMultiplier: Float = 4.0
    var panSensitivity: Float = 0.002
    var scrollSensitivity: Float = 0.15

    init(position: SIMD3<Float> = .zero) {
        self.position = position
        // cameraDistance = distanceFromPositionToPivot
        rig.position = position
        rig.addChild(pitchNode)
        pitchNode.addChild(camera)

        camera.camera.near = 0.01
        camera.camera.far = 2000
        camera.setPosition([0, 0, cameraDistance], relativeTo: pitchNode)
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

//    func yawPivot() -> SIMD3<Float> {
//        // TODO: guard against (near)parallel projection here
//        // return (forward.normalizedProjectionOntoXZPlane) * distanceFromPositionToPivot + position
//        return (forward.normalizedProjectionOntoXZPlane) * distanceFromPositionToPivot + position
//    }
    
    func safeNormalize(_ v: SIMD3<Float>, eps: Float = 1e-6) -> SIMD3<Float>? {
        let l = simd_length(v)
        guard l > eps else { return nil }
        return v / l
    }
    
//    func pitchPivot() -> SIMD3<Float> {
//        let r = simd_normalize(right)
//        let f = simd_normalize(forward)
//        let projected = f - dot(f, r) * r
//        
//        // If forward is nearly parallel to right, pick a stable fallback direction in the plane ⟂ r
//        let fPlane: SIMD3<Float> =
//            safeNormalize(projected) ??
//            safeNormalize(simd_cross(r, SIMD3<Float>(0,1,0))) ??   // try worldUp
//            simd_normalize(simd_cross(r, SIMD3<Float>(0,0,1)))      // last resort
//        
//        let pivot = position + fPlane * distanceFromPositionToPivot
//        return pivot
//    }
    
    // TODO: change the name to yawAboutPivot
//    func yaw(angle: Float) {
//        let pivot = yawPivot()
//        self.yaw += angle
//        let yawDelta = simd_quatf(angle: angle, axis: [0,1,0])
//        
//        // Position: rotate the offset vector around the pivot.
//        let C = rig.position(relativeTo: nil)
//        let r = C - pivot
//        let r2 = yawDelta.act(r)
//        let C2 = pivot + r2
//        position = C2
//        
//        // Orientation: look at the pivot.
//        let toPivot = normalize(pivot - C2)
//        let up: SIMD3<Float> = [0, 1, 0]
//        rig.setOrientation(lookRotation(forward: toPivot, up: up), relativeTo: nil)
//        applyTransforms()
//    }
    
    /// Updates pitch for an orbit camera (Godot-style)
    ///
    /// - Parameters:
    ///   - deltaY: mouse / trackpad vertical delta (positive = mouse moved down)
    ///   - sensitivity: radians per pixel (e.g. 0.005)
    ///   - pitch: current pitch angle (inout)
    func applyPitch(
        deltaY: Float
    ) {
        // 1. Accumulate pitch (invert sign if you want natural mouse)
        pitch -= deltaY

        // 2. Clamp pitch to avoid flipping over the poles
        let limit: Float = .pi / 2 - 0.001
        pitch = min(max(pitch, -limit), limit)
        
        pitchNode.orientation = simd_quatf(angle: pitch, axis: [1, 0, 0])
        
        // Find the pivot
        // let pivot = pitchPivot()
        updateCamera(camera: camera, yaw: yaw, pitch: pitch)
    }
    
    func applyYaw(delta: Float) {
        yaw += delta
        rig.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        updateCamera(camera: camera, yaw: yaw, pitch: pitch )
    }
    
    func applyLateralTranslation(delta: Float) {
        position += right * delta
        rig.position = position
    }
    
    func applyVerticalTranslation(delta: Float) {
        position += up * delta
        rig.position = position
    }
    
    func dolly(delta: Float) {
        // Suppose camera is at [0, 0, radius] in pitchNode space
        var p = camera.position(relativeTo: pitchNode)
        let d = p.z - delta
        cameraDistance = max(0.01, d)
        p.z = cameraDistance // subtract to move closer if +Z is “back”
        camera.setPosition(p, relativeTo: pitchNode)
        
        // print("==RL== camera world position: \(camera.position(relativeTo: nil)), position relative to pitch node: \(camera.position(relativeTo: pitchNode))")
    }
    
//    func dolly(delta: Float) {
//        position += forward * delta
//        rig.position = position
//    }
    
    func updateCamera(
        camera: Entity,
        yaw: Float,
        pitch: Float
    ) {
        // Yaw around world up
        let qYaw = simd_quatf(angle: yaw, axis: [0, 1, 0])

        // Pitch around local X
        let qPitch = simd_quatf(angle: pitch, axis: [1, 0, 0])

        // Combined rotation (yaw first, then pitch)
        let q = qYaw * qPitch

        // Camera offset (RealityKit camera looks down -Z)
        let offset = q.act([0, 0, cameraDistance])

        // Final position
        let position = offset

        camera.setPosition(position, relativeTo: nil)

        // Look back at the pivot
        let forward = normalize(rig.position - position)
        let up: SIMD3<Float> = [0, 1, 0]
        camera.setOrientation(
            lookRotation(forward: forward, up: up),
            relativeTo: nil
        )
        
        print("rig's position: \(rig.position), pitch node's position: \(pitchNode.position), camera position: \(camera.position)")
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
