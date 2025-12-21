//
//  EditorARView.swift
//  vivarium-studio
//
//  Created by Roy Li on 12/17/25.
//

import Cocoa
import AppKit
import RealityKit

final class EditorARView: ARView {
    let cam = EditorCameraController(position: [0, 0, 1])

    private var isLooking = false
    private var isPanning = false
    private var lastMouse = CGPoint.zero

    required init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        cam.attach(to: self)
        window?.makeFirstResponder(self)
    }

    @objc required dynamic init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
         cam.attach(to: self)
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        lastMouse = convert(event.locationInWindow, from: nil)
        // Example: RMB-look, MMB-pan. (You can also use modifiers.)
        if event.type == .rightMouseDown {
            isLooking = true
        } else {
            // LMB does nothing by default for editor nav; your app may use it for selection.
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        lastMouse = convert(event.locationInWindow, from: nil)
        isLooking = true
    }

    override func otherMouseDown(with event: NSEvent) {
        lastMouse = convert(event.locationInWindow, from: nil)
        isPanning = true
    }

    override func mouseUp(with event: NSEvent) { isLooking = false; isPanning = false }
    override func rightMouseUp(with event: NSEvent) { isLooking = false }
    override func otherMouseUp(with event: NSEvent) { isPanning = false }

    override func mouseDragged(with event: NSEvent) { handleDrag(event) }
    override func rightMouseDragged(with event: NSEvent) { handleDrag(event) }
    override func otherMouseDragged(with event: NSEvent) { handleDrag(event) }

    private func handleDrag(_ event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let dx = Float(p.x - lastMouse.x)
        let dy = Float(p.y - lastMouse.y)
        lastMouse = p

        if isLooking {
            camYawPitch(dx: dx, dy: dy)
        } else if isPanning {
            camPan(dx: dx, dy: dy)
        }
    }
    
    private func camYawPitch(dx: Float, dy: Float) {
        camYawPitchImpl(dx: dx, dy: dy)
    }

    private func camYawPitchImpl(dx: Float, dy: Float) {
        cam.yaw += dx * cam.lookSensitivity
        cam.pitch += dy * cam.lookSensitivity
        cam.applyTransforms()
    }

    private func camPan(dx: Float, dy: Float) {
        // screen drag -> move camera right/up
        cam.position += (-dx * cam.panSensitivity) * cam.right
        cam.position += ( dy * cam.panSensitivity) * cam.up
        cam.applyTransforms()
    }

    // Rotate about an axis n distance away in the lookAt direction.
    override func scrollWheel(with event: NSEvent) {
        // natural scrolling varies; you may want to invert sign to taste
        // print("deltaX: \(deltaX), deltaY: \(deltaY)")
        
        if abs(event.scrollingDeltaX) == abs(event.scrollingDeltaY) {
            return
        }
        
        if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            let angleToRotate = Float.pi * Float(event.scrollingDeltaX) * 0.0005 * 0.5
            cam.yaw(angle: -angleToRotate)
        }
        else {
            print("==RL== vertical")
        }
        print("==RL== event.scrollingDeltaX: \(event.scrollingDeltaX), event.scrollingDeltaY: \(event.scrollingDeltaY)")
        
        // TODO: how to make a rotation axis
        // let rotationAxis = simd_quatf(angle:   , axis: <#T##SIMD3<Float>#>)
        
         // cam.forward
    }
}
