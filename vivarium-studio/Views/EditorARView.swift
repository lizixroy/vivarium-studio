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

    private var isTranslating = false
        
    // Rotate about an axis n distance away in the lookAt direction.
    override func scrollWheel(with event: NSEvent) {
        // natural scrolling varies; you may want to invert sign to taste
        // print("deltaX: \(deltaX), deltaY: \(deltaY)")
        
        let shiftHeld = event.modifierFlags.contains(.shift)
    
        if !shiftHeld && isTranslating {
            isTranslating = false
            return
        }
        
        if shiftHeld {
            isTranslating = true
            lateralTranslation(with: event)
        }
        else {
            orbit(with: event)
        }
    }
    
    override func magnify(with event: NSEvent) {
        print("magnifying: \(event.magnification)")
        cam.dolly(delta: Float(event.magnification) * 0.5)
    }
    
    private func lateralTranslation(with event: NSEvent) {
        if abs(event.scrollingDeltaX) == abs(event.scrollingDeltaY) {
            return
        }
        let lateralTranslationDelta = Float(event.scrollingDeltaX * 0.0005 * 0.5)
        let verticalTranslationDelta = Float(event.scrollingDeltaY * 0.0005 * 0.5)
        cam.applyLateralTranslation(delta: -lateralTranslationDelta)
        cam.applyVerticalTranslation(delta: verticalTranslationDelta)
    }
    
    private func orbit(with event: NSEvent) {
        if abs(event.scrollingDeltaX) == abs(event.scrollingDeltaY) {
            return
        }
        
        if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            let angleToRotate = Float.pi * Float(event.scrollingDeltaX) * 0.0005 * 0.5
            cam.applyYaw(delta: -angleToRotate)
        }
        else {
            print("==RL== vertical")
            let angleToRotate = Float.pi * Float(event.scrollingDeltaY) * 0.0005
            cam.applyPitch(deltaY: angleToRotate)
        }
    }
}
