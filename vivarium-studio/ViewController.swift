//
//  ViewController.swift
//  vivarium-studio
//
//  Created by Roy Li on 12/14/25.
//

import Cocoa
import RealityKit
import AppKit

private extension NSPasteboard.PasteboardType {
    static let assetID = NSPasteboard.PasteboardType("com.yourapp.asset-id")
}

final class ARDropOverlayView: NSView {

    weak var arView: ARView?
    weak var worldAnchor: AnchorEntity?

    private var previewEntity: ModelEntity?
    private let transparent1px: NSImage = {
        let img = NSImage(size: NSSize(width: 1, height: 1))
        img.lockFocus()
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        img.unlockFocus()
        return img
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.assetID])
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.assetID])
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    // MARK: Drag destination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.string(forType: .assetID) != nil else { return [] }
        hideDragImage(sender)
        updatePreview(sender)
        return .generic
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.string(forType: .assetID) != nil else { return [] }
        hideDragImage(sender)      // keep it hidden (prevents flicker)
        updatePreview(sender)      // move ghost
        return .generic
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        removePreview()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let arView,
              let anchor = worldAnchor,
              let assetID = sender.draggingPasteboard.string(forType: .assetID)
        else { return false }

        // Commit placement at current preview position (or compute again)
        guard let p = currentGroundHit(from: sender, in: arView) else {
            removePreview()
            return false
        }

        // TODO: Replace with your real placement (e.g. create Room by assetID)
        // For now, drop a solid box:
        let placed = ModelEntity(
            mesh: .generateBox(size: 0.2),
            materials: [SimpleMaterial(color: .systemTeal, isMetallic: false)]
        )
        placed.position = p
        anchor.addChild(placed)

        removePreview()
        return true
    }

    // MARK: Drag image hiding

    private func hideDragImage(_ sender: NSDraggingInfo) {
        // Replace dragged representation with a tiny transparent image.
        sender.enumerateDraggingItems(
            options: [],
            for: self,
            classes: [NSPasteboardItem.self],
            searchOptions: [:]
        ) { draggingItem, _, _ in
            let loc = self.convert(sender.draggingLocation, from: nil)
            draggingItem.setDraggingFrame(NSRect(x: loc.x, y: loc.y, width: 1, height: 1),
                                          contents: self.transparent1px)
        }
    }

    // MARK: Preview ghost

    private func ensurePreviewEntity(on anchor: AnchorEntity) -> ModelEntity {
        if let e = previewEntity { return e }

        let e = ModelEntity(
            mesh: .generateBox(size: 0.25),
            materials: [SimpleMaterial(color: NSColor.white.withAlphaComponent(0.25), isMetallic: false)]
        )
        // Optional: make it look “ghosty”
        e.components.set(OpacityComponent(opacity: 0.35))
        anchor.addChild(e)
        previewEntity = e
        return e
    }

    private func updatePreview(_ sender: NSDraggingInfo) {
        guard let arView, let anchor = worldAnchor else { return }
        guard let p = currentGroundHit(from: sender, in: arView) else {
            removePreview()
            return
        }
        let ghost = ensurePreviewEntity(on: anchor)
        ghost.position = p
    }

    private func removePreview() {
        previewEntity?.removeFromParent()
        previewEntity = nil
    }

    // MARK: Screen -> world (simple ground plane y=0)

    private func currentGroundHit(from sender: NSDraggingInfo, in arView: ARView) -> SIMD3<Float>? {
        // draggingLocation is in window base coords; convert into overlay coords first:
        let locInOverlay = convert(sender.draggingLocation, from: nil)

        guard let ray = arView.ray(through: locInOverlay) else { return nil }
        let o = ray.origin
        let d = ray.direction
        let eps: Float = 1e-6
        if abs(d.y) < eps { return nil }
        let t = -o.y / d.y
        if t < 0 { return nil }
        return o + t * d
    }
}

class ViewController: NSViewController {

    @IBOutlet weak var arView: EditorARView!
    
    private var gridController: GroundGridController?
    
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

        // Move/ro tate the whole room as one grouped object:
        room.transform.translation = [0, 0.05, 0]
//        room.transform.rotation = simd_quatf(angle: .pi / 6, axis: [0, 1, 0])

//        anchor.addChild(room.rootEntity)

        // Set up ground grid
        guard let grid = GroundGridController(
            viewportSizeWidth: Float(arView.bounds.size.width),
            viewportSizeHeight: Float(arView.bounds.size.height)) else {
            fatalError("Unable to create grid controller.")
        }
        
        gridController = grid
        
        anchor.addChild(grid.entity)
        grid.startUpdating(scene: arView.scene, cameraEntity: arView.cam.camera)

        Task {
            guard let url = Bundle.main.url(forResource: "Chair_Office_15-N", withExtension: "glb") else {
                fatalError("Missing Chair_Office_15-N.stp.glb in bundle")
            }

            if let entity = try await RealityKitLoader.shared.loadEntity(from: url, type: .glb) {
                // TODO: why are there two entities here?
                print("loaded entity: \(entity)")

                await MainActor.run {
                    let convertedEntity = try! VVRealityKitConverter.makeRealityKitEntity(from: entity)
                    anchor.addChild(convertedEntity)
                }
            }
        }
        
        // Add drop overlay on top of ARView
        let overlay = ARDropOverlayView(frame: arView.bounds)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.arView = arView
        overlay.worldAnchor = anchor

        arView.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: arView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: arView.bottomAnchor),
        ])
    
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

