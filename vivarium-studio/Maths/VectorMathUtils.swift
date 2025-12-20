//
//  VectorMathUtils.swift
//  vivarium-studio
//
//  Created by Roy Li on 12/18/25.
//

import Foundation
import simd
import RealityKit

let pivotDistance: Float = 5.0

extension SIMD3<Float> {
    var projectionOntoXZPlane: SIMD3<Float> {
        let xzPlaneNormal = SIMD3<Float>(0, 1, 0)
        return self - simd_dot(self, xzPlaneNormal) * xzPlaneNormal
    }
    
    var normalizedProjectionOntoXZPlane: SIMD3<Float> {
        return simd_normalize(projectionOntoXZPlane)
    }
    
//    static func findYAxisRotationPivot(forward: SIMD3<Float>, from point: SIMD3<Float>, distance: Float) -> SIMD3<Float> {
//        return (forward.normalizedProjectionOntoXZPlane) * distance + point
//    }
    
//    func findYAxisRotationPivot() -> SIMD3<Float> {
//        let pivotDirection = normalizedProjectionOntoXZPlane
//        return pivotDirection * pivotDirection + self
//    }
}

func findYAxisRotationPivot(forward: SIMD3<Float>, from point: SIMD3<Float>, distance: Float) -> SIMD3<Float> {
    return (forward.normalizedProjectionOntoXZPlane) * distance + point
}

func orbitCamera(camera: Entity, pivotWorld P: SIMD3<Float>, orbitDelta: simd_quatf) {
    // Position: rotate the offset vector around the pivot.
    let C = camera.position(relativeTo: nil)
    let r = C - P
    let r2 = orbitDelta.act(r)
    let C2 = P + r2
    camera.setPosition(C2, relativeTo: nil)
    
    // Orientation: look at the pivot.
    let toPivot = normalize(P - C2)
    // let forward = -toPivot
    let up: SIMD3<Float> = [0, 1, 0]
    // camera.setOrientation(lookRotation(forward: forward, up: up), relativeTo: nil)
    camera.setOrientation(lookRotation(forward: toPivot, up: up), relativeTo: nil)
}

//func lookRotation(forward f: SIMD3<Float>, up u: SIMD3<Float>) -> simd_quatf {
//    let f = normalize(f)
//    let right = normalize(cross(f, u))
//    let u2 = cross(right, f)
//    let m = float3x3(columns: (right, u2, -f))
//    return simd_quatf(m)
//}

// In the following function, I onky understand `let f = normalize(-desiredLook)`. This is done because we want the local +Z axis to point opposite the desired look direction. After this what's the principle that guides us to figure out what local X and Y axes should end up in the world? Should the local y (the up vector) align with the global y axis?

func lookRotation(forward desiredLook: SIMD3<Float>, up worldUp: SIMD3<Float>) -> simd_quatf {
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
    
    // TODO: this makes the u point down. Why is this correct? 8
    let u2 = cross(f, r) // corrected up, orthogonal
    
    let m = float3x3(columns: (r, u2, f))
    return simd_quatf(m)
}

// After the rotation, the cube I'm looking at is no longer in view, so I'm suspecting the camera is now facing the opposite direction. Can you spot any issues in the following method that creates the oreitnation matrix for the rig node?
