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
        
        // TODO: test only. Add a CSG derived room mesh
        let roomParams = RoomParams(innerWidth: 2, innerDepth: 2, wallHeight: 3, wallThickness: 0.02)
         let csg = RoomBuilder.makeThreeWallRoomCSG(roomParams)
//        let csg = RoomBuilder.makeHalfRoom(roomParams)
        let instances = CSGEvaluator.evaluate(csg)
        
        let wallMat = SimpleMaterial(
            color: .init(white: 0.85, alpha: 1.0),
            roughness: 0.9,
            isMetallic: false
        )
        
        for inst in instances {
            let e = RealityKitBridge.makeEntity(for: inst, material: wallMat)
            anchor.addChild(e)
        }
        
        arView.cam.position = [0, 0, 0]
        arView.cam.applyTransforms()
        
        // TODO: test area
        let box = BRep.makeBox(width: 1, height: 1, depth: 1)
        print("box B-Rep: \(box)")
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

