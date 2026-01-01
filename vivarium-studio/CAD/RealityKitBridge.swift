import Foundation
import RealityKit
import simd

public enum RealityKitBridge {
    public static func makeEntity(for instance: PrimitiveInstance, material: Material) -> ModelEntity {
        let mesh = MeshBuilder.mesh(for: instance.primitive)
        let entity = ModelEntity(mesh: mesh, materials: [material])

        var t = Transform()
        t.translation = instance.world.position
        t.rotation = instance.world.rotation
        t.scale = instance.world.scale
        entity.transform = t

        return entity
    }
}
