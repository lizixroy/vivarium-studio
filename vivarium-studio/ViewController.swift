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
        // anchor.addChild(cube)
                
        arView.cam.position = [0, 0, 0]
        arView.cam.applyTransforms()
        
        // TODO: B-Rep test:
        
//        let box = BRep.makeBox(width: 1, height: 1, depth: 1)
//        let mesh = try! tessellateBoxBRepToRealityKitMesh(box)
//        print("mesh from BRep: \(mesh)")
//        let entity = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .gray, isMetallic: false)])
//        
//        anchor.addChild(entity)

        /* Cylinder test */
//        var cylinder = BRep()
//        let (sideFaceID, topFaceID, bottomFaceID) = cylinder.addAnalyticCylinder(radius: 0.5, height: 0.5, center: [0, 0, 0])
//        let tri = cylinder.tessellateAnalyticCylinder(sideFaceID: sideFaceID, topFaceID: topFaceID, bottomFaceID: bottomFaceID)
//        let mesh = try! meshResource(from: tri, name: "AnalyticCylinder")
//        let material = SimpleMaterial(color: .blue, isMetallic: false)
//        let model = ModelEntity(mesh: mesh, materials: [material])
//        anchor.addChild(model)


        // In your scene setup:
//        let room = Room(params: .init(width: 8, depth: 10, height: 3.2),
//                        displayMode: .half)

        let room = Room(params: .init(width: 1, depth: 1, height: 0.6, wallThickness: 0.05, floorThickness: 0.05, ceilingThickness: 0.05),
                        displayMode: .half)

        // Move/rotate the whole room as one grouped object:
        room.transform.translation = [0, 0, 0]
//        room.transform.rotation = simd_quatf(angle: .pi / 6, axis: [0, 1, 0])

        anchor.addChild(room.rootEntity)

        // Toggle modes later:
        // room.displayMode = .full
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

