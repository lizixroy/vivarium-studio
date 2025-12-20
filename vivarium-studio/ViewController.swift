//
//  ViewController.swift
//  vivarium-studio
//
//  Created by Roy Li on 12/14/25.
//

import Cocoa
import RealityKit

class ViewController: NSViewController {

    @IBOutlet weak var arView: EditorARView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        arView.environment.background = .color(.black)
        
        // Do any additional setup after loading the view.
        let light = DirectionalLight()
        light.light.intensity = 2500
        light.look(at: .zero, from: [2, 3, 2], relativeTo: nil)

        let lightHolder = Entity()
        lightHolder.addChild(light)

        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(lightHolder)
        
        arView.scene.addAnchor(anchor)
        
        let cube = ModelEntity(mesh: .generateBox(size: 0.2),
                               materials: [SimpleMaterial(color: .systemTeal, isMetallic: false)])
        // cube.position = [0, 0.2, 0]
        cube.position = [0, 0.0, 0]
        anchor.addChild(cube)
        
//        let angle: Float = .pi / 6
//        let axis = SIMD3<Float>(0, 1, 0)
//        arView.cam.rig.orientation = simd_quatf(angle: angle, axis: axis)
//         arView.cam.position = [0, 0.3, 1]
        arView.cam.position = [0, 0, 1]
        arView.cam.applyTransforms()
        
        // Use 1 as the pivot distance for testing.
//        let pivot = findYAxisRotationPivot(forward: arView.cam.forward, from: arView.cam.position, distance: 1)
//        orbitCamera(camera: arView.cam.rig, pivotWorld: pivot, orbitDelta: simd_quatf(angle: .pi / 2, axis: [0, 1, 0]))
        
        print("cam's position \(arView.cam.position) and yaw: \(arView.cam.yaw) pitch: \(arView.cam.pitch)")
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

