//
//  GLBIngestor.swift
//  vivarium-studio
//
//  Created by Roy Li on 1/25/26.
//

import Foundation
import ImageIO
import simd
import CoreGraphics


enum RKTexSemantic {
    case colorSRGB      // baseColor / emissive
    case linear         // metallic, roughness, normal, ao
}

// MARK: - Extract single channel grayscale CGImage from an RGBA CGImage
// channelIndex: 0=R, 1=G, 2=B, 3=A

func extractGrayscaleChannel(from src: CGImage, channelIndex: Int) throws -> CGImage {
    precondition((0...3).contains(channelIndex))

    let width = src.width
    let height = src.height

    // We’ll render into an 8-bit grayscale buffer.
    let bytesPerRow = width
    var out = [UInt8](repeating: 0, count: width * height)

    // Draw source into a known RGBA8 layout first.
    let rgbaBytesPerRow = width * 4
    var rgba = [UInt8](repeating: 0, count: rgbaBytesPerRow * height)

    guard let ctx = CGContext(
        data: &rgba,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: rgbaBytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "GLTF", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create RGBA context"])
    }

    // Important: this does not do gamma conversion; it just gets bytes.
    ctx.draw(src, in: CGRect(x: 0, y: 0, width: width, height: height))

    // Pull out the requested channel.
    for y in 0..<height {
        let rowStartRGBA = y * rgbaBytesPerRow
        let rowStartOut = y * bytesPerRow
        for x in 0..<width {
            out[rowStartOut + x] = rgba[rowStartRGBA + x * 4 + channelIndex]
        }
    }

    guard let grayCtx = CGContext(
        data: &out,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    ) else {
        throw NSError(domain: "GLTF", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create grayscale context"])
    }

    guard let gray = grayCtx.makeImage() else {
        throw NSError(domain: "GLTF", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create grayscale CGImage"])
    }
    return gray
}

// MARK: - Public entry

enum GLBRealityKitLoader {
//    static func loadEntity(from glbURL: URL) async throws -> Entity {
//        let data = try Data(contentsOf: glbURL)
//        let glb = try GLB.parse(data)
//
//        let decoder = JSONDecoder()
//        let gltf = try decoder.decode(GLTF.self, from: glb.jsonChunk)
//
//        // GLB has exactly one BIN chunk in typical cases.
//        let bin = glb.binChunk ?? Data()
//
//        // Build entities from default scene (or scene 0)
//        let sceneIndex = gltf.scene ?? 0
//        guard let scene = gltf.scenes?.safe(sceneIndex) else {
//            throw LoaderError.missingScene
//        }
//
//        let root = await Entity()
//        if let nodeIndices = scene.nodes {
//            for ni in nodeIndices {
//                let child = try buildNodeEntity(gltf: gltf, bin: bin, nodeIndex: ni, baseURL: glbURL.deletingLastPathComponent())
//                await root.addChild(child)
//            }
//        }
//        return root
//    }
    
    static func loadEntity2(from glbURL: URL) async throws -> VVEntity {
        let data = try Data(contentsOf: glbURL)
        let glb = try GLB.parse(data)

        let decoder = JSONDecoder()
        let gltf = try decoder.decode(GLTF.self, from: glb.jsonChunk)

        // GLB has exactly one BIN chunk in typical cases.
        let bin = glb.binChunk ?? Data()

        // Build entities from default scene (or scene 0)
        let sceneIndex = gltf.scene ?? 0
        guard let scene = gltf.scenes?.safe(sceneIndex) else {
            throw LoaderError.missingScene
        }

        let root = VVEntity()
        if let nodeIndices = scene.nodes {
            for ni in nodeIndices {
                // let child = try buildNodeEntity(gltf: gltf, bin: bin, nodeIndex: ni, baseURL: glbURL.deletingLastPathComponent())                
                let child = try buildEntity(gltf: gltf, bin: bin, nodeIndex: ni, baseURL: glbURL.deletingLastPathComponent())
                
                root.addChild(child)
            }
        }
        return root
    }
}

// MARK: - Core build (Node -> Entity)

//private func buildNodeEntity(gltf: GLTF, bin: Data, nodeIndex: Int, baseURL: URL) throws -> Entity {
//    guard let node = gltf.nodes?.safe(nodeIndex) else { throw LoaderError.badIndex("node") }
//
//    let e = Entity()
//
//    // Transform (matrix OR TRS). We'll support both.
//    if let m = node.matrix, m.count == 16 {
//        // glTF is column-major 4x4
//        var mat = simd_float4x4()
//        mat.columns.0 = [m[0],  m[1],  m[2],  m[3]]
//        mat.columns.1 = [m[4],  m[5],  m[6],  m[7]]
//        mat.columns.2 = [m[8],  m[9],  m[10], m[11]]
//        mat.columns.3 = [m[12], m[13], m[14], m[15]]
//        e.transform.matrix = mat
//    } else {
//        let t = node.translation ?? [0,0,0]
//        let r = node.rotation ?? [0,0,0,1]
//        let s = node.scale ?? [1,1,1]
//        e.transform.translation = [t[0], t[1], t[2]]
//        e.transform.rotation = simd_quatf(ix: r[0], iy: r[1], iz: r[2], r: r[3])
//        e.transform.scale = [s[0], s[1], s[2]]
//    }
//
//    // Mesh -> ModelEntity
//    if let meshIndex = node.mesh, let mesh = gltf.meshes?.safe(meshIndex) {
//        // Many GLTF meshes have multiple primitives; we’ll create a parent entity containing them.
//        let meshRoot = Entity()
//
//        for prim in (mesh.primitives ?? []) {
//            let model = try buildPrimitiveModelEntity(gltf: gltf, bin: bin, primitive: prim, baseURL: baseURL)
//            meshRoot.addChild(model)
//        }
//        e.addChild(meshRoot)
//    }
//
//    // Children
//    if let children = node.children {
//        for ci in children {
//            let c = try buildNodeEntity(gltf: gltf, bin: bin, nodeIndex: ci, baseURL: baseURL)
//            e.addChild(c)
//        }
//    }
//
//    return e
//}

private func buildEntity(gltf: GLTF, bin: Data, nodeIndex: Int, baseURL: URL) throws -> VVEntity {
    
    guard let node = gltf.nodes?.safe(nodeIndex) else { throw LoaderError.badIndex("node") }
    let entity = VVEntity()

    // Transform (matrix OR TRS). We'll support both.
    if let m = node.matrix, m.count == 16 {
        // glTF is column-major 4x4
        var mat = simd_float4x4()
        mat.columns.0 = [m[0],  m[1],  m[2],  m[3]]
        mat.columns.1 = [m[4],  m[5],  m[6],  m[7]]
        mat.columns.2 = [m[8],  m[9],  m[10], m[11]]
        mat.columns.3 = [m[12], m[13], m[14], m[15]]
        entity.matrix = mat
    } else {
        let t = node.translation ?? [0,0,0]
        let r = node.rotation ?? [0,0,0,1]
        let s = node.scale ?? [1,1,1]
        entity.translation = [t[0], t[1], t[2]]
        entity.rotation = simd_quatf(ix: r[0], iy: r[1], iz: r[2], r: r[3])
        entity.scale = [s[0], s[1], s[2]]
    }

    // Mesh -> ModelEntity
    if let meshIndex = node.mesh, let mesh = gltf.meshes?.safe(meshIndex) {
        // Many GLTF meshes have multiple primitives; we’ll create a parent entity containing them.
        // let meshRoot = Entity()
        let meshResourceRoot = VVEntity()

        for prim in (mesh.primitives ?? []) {
            let modelEntity = try buildModelEntity(gltf: gltf, bin: bin, primitive: prim, baseURL: baseURL)
            meshResourceRoot.addChild(modelEntity)
        }
        entity.addChild(meshResourceRoot)
    }

    // Children
    if let children = node.children {
        for ci in children {
            let c = try buildEntity(gltf: gltf, bin: bin, nodeIndex: ci, baseURL: baseURL)
            entity.addChild(c)
        }
    }

    return entity

}


// MARK: - Primitive -> ModelEntity

//private func buildPrimitiveModelEntity(gltf: GLTF, bin: Data, primitive: GLTF.Mesh.Primitive, baseURL: URL) throws -> ModelEntity {
//    guard primitive.mode == nil || primitive.mode == 4 else {
//        // 4 = TRIANGLES
//        throw LoaderError.unsupported("Only TRIANGLES primitives are supported in this MVP.")
//    }
//
//    // Accessors
//    guard let posAccIndex = primitive.attributes["POSITION"] else { throw LoaderError.missing("POSITION") }
//    let norAccIndex = primitive.attributes["NORMAL"]
//    let uvAccIndex  = primitive.attributes["TEXCOORD_0"]
//    let idxAccIndex = primitive.indices
//
//    let positions: [SIMD3<Float>] = try readVec3Accessor(gltf: gltf, bin: bin, accessorIndex: posAccIndex)
//    let normals:   [SIMD3<Float>] = (norAccIndex != nil) ? (try readVec3Accessor(gltf: gltf, bin: bin, accessorIndex: norAccIndex!)) : []
//    let uvs:       [SIMD2<Float>] = (uvAccIndex  != nil) ? (try readVec2Accessor(gltf: gltf, bin: bin, accessorIndex: uvAccIndex!))  : []
//
//    let indices: [UInt32]
//    if let idxAccIndex {
//        indices = try readIndexAccessorAsUInt32(gltf: gltf, bin: bin, accessorIndex: idxAccIndex)
//    } else {
//        // No indices => implicit 0..n-1
//        indices = Array(0..<UInt32(positions.count))
//    }
//
//    // Build MeshResource
//    var desc = MeshDescriptor()
//
//    desc.positions = MeshBuffers.Positions(positions)
//    if !normals.isEmpty {
//        desc.normals = MeshBuffers.Normals(normals)
//    }
//    if !uvs.isEmpty {
//        desc.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
//    }
//    desc.primitives = .triangles(indices)
//
//    let meshResource = try MeshResource.generate(from: [desc])
//
//    // Material
//    let material = try buildMaterial(gltf: gltf, bin: bin, primitive: primitive, baseURL: baseURL)
//
//    return ModelEntity(mesh: meshResource, materials: [material])
//}

private func buildModelEntity(gltf: GLTF, bin: Data, primitive: GLTF.Mesh.Primitive, baseURL: URL) throws -> VVModelEntity {
    
    guard primitive.mode == nil || primitive.mode == 4 else {
        // 4 = TRIANGLES
        throw LoaderError.unsupported("Only TRIANGLES primitives are supported in this MVP.")
    }

    // Accessors
    guard let posAccIndex = primitive.attributes["POSITION"] else { throw LoaderError.missing("POSITION") }
    let norAccIndex = primitive.attributes["NORMAL"]
    let uvAccIndex  = primitive.attributes["TEXCOORD_0"]
    let idxAccIndex = primitive.indices

    let positions: [SIMD3<Float>] = try readVec3Accessor(gltf: gltf, bin: bin, accessorIndex: posAccIndex)
    let normals:   [SIMD3<Float>] = (norAccIndex != nil) ? (try readVec3Accessor(gltf: gltf, bin: bin, accessorIndex: norAccIndex!)) : []
    let uvs:       [SIMD2<Float>] = (uvAccIndex  != nil) ? (try readVec2Accessor(gltf: gltf, bin: bin, accessorIndex: uvAccIndex!))  : []

    let indices: [UInt32]
    if let idxAccIndex {
        indices = try readIndexAccessorAsUInt32(gltf: gltf, bin: bin, accessorIndex: idxAccIndex)
    } else {
        // No indices => implicit 0..n-1
        indices = Array(0..<UInt32(positions.count))
    }

    // Material
    let material = try buildEntityMaterial(gltf: gltf, bin: bin, primitive: primitive, baseURL: baseURL)
        
    let modelEntity = VVModelEntity()
    modelEntity.positions = positions
    modelEntity.normals = normals
    modelEntity.uvs = uvs
    modelEntity.indices = indices
    modelEntity.material = material
    
    return modelEntity
}


// MARK: - Material (PBR Metallic-Roughness)

//private func buildMaterial(gltf: GLTF, bin: Data, primitive: GLTF.Mesh.Primitive, baseURL: URL) throws -> PhysicallyBasedMaterial {
//    var m = PhysicallyBasedMaterial()
//
//    let matIndex = primitive.material ?? 0
//    let gltfMat = gltf.materials?.safe(matIndex)
//
//    // Defaults
//    var baseColorFactor: SIMD4<Float> = [1,1,1,1]
//    var metallic: Float = 1.0
//    var roughness: Float = 1.0
//
//    if let pbr = gltfMat?.pbrMetallicRoughness {
//        if let f = pbr.baseColorFactor, f.count == 4 {
//            baseColorFactor = [f[0], f[1], f[2], f[3]]
//        }
//        metallic  = pbr.metallicFactor ?? metallic
//        roughness = pbr.roughnessFactor ?? roughness
//
//        // Base color texture
//        if let texInfo = pbr.baseColorTexture {
//            
//            if let tex = try loadTextureResource(gltf: gltf, bin: bin, textureIndex: texInfo.index, baseURL: baseURL, semantic: .colorSRGB) {
//                m.baseColor = .init(texture: .init(tex))
//            } else {
//                m.baseColor = .init(tint: .init(red: CGFloat(baseColorFactor.x), green: CGFloat(baseColorFactor.y), blue: CGFloat(baseColorFactor.z), alpha: CGFloat(baseColorFactor.w)))
//            }
//        } else {
//            m.baseColor = .init(tint: .init(red: CGFloat(baseColorFactor.x), green: CGFloat(baseColorFactor.y), blue: CGFloat(baseColorFactor.z), alpha: CGFloat(baseColorFactor.w)))
//        }
//
//        // Metallic-Roughness texture (B=metallic, G=roughness) is the glTF convention.
//        m.metallic  = .init(floatLiteral: metallic)
//        m.roughness = .init(floatLiteral: roughness)
//        
//        if let mrInfo = pbr.metallicRoughnessTexture,
//            let mrCG = try loadTextureCGImage(gltf: gltf, bin: bin, textureIndex: mrInfo.index, baseURL: baseURL) {
//            
//            // Extract channels into grayscale images
//            let roughCG = try extractGrayscaleChannel(from: mrCG, channelIndex: 1) // G
//            let metalCG = try extractGrayscaleChannel(from: mrCG, channelIndex: 2) // B
//
//             // Create *linear/data* textures (NOT sRGB)
//            let roughTex = try TextureResource.init(image: roughCG, options: .init(semantic: .raw))
//            let metalTex = try TextureResource.init(image: metalCG, options: .init(semantic: .raw))
//            
//            // Feed into RealityKit PBR slots
//            m.roughness = .init(texture: .init(roughTex))
//            m.metallic  = .init(texture: .init(metalTex))
//        }
//    } else {
//        m.baseColor = .init(tint: .white)
//        m.metallic  = .init(floatLiteral: metallic)
//        m.roughness = .init(floatLiteral: roughness)
//    }
//
//    // Normal map
//    if let n = gltfMat?.normalTexture {
//        if let tex = try loadTextureResource(gltf: gltf, bin: bin, textureIndex: n.index, baseURL: baseURL, semantic: .linear) {
//            m.normal = .init(texture: .init(tex))
//        }
//    }
//
//    // Emissive
//    if let e = gltfMat?.emissiveFactor, e.count == 3 {
//        m.emissiveColor = .init(color: .init(red: CGFloat(e[0]), green: CGFloat(e[1]), blue: CGFloat(e[2]), alpha: CGFloat(1)))
//    }
//    if let et = gltfMat?.emissiveTexture {
//        if let tex = try loadTextureResource(gltf: gltf, bin: bin, textureIndex: et.index, baseURL: baseURL, semantic: .colorSRGB) {
//            m.emissiveColor = .init(texture: .init(tex))
//        }
//    }
//
//    // Alpha mode (very minimal)
//    switch gltfMat?.alphaMode ?? "OPAQUE" {
//    case "BLEND":
//        m.blending = .transparent(opacity: 1.0)
//    case "MASK":
//        m.blending = .transparent(opacity: 1.0)
//        m.opacityThreshold = gltfMat?.alphaCutoff ?? 0.5
//    default:
//        break
//    }
//
//    // Double-sided
//    if gltfMat?.doubleSided == true {
//        m.faceCulling = .none
//    }
//
//    return m
//}

private func buildEntityMaterial(gltf: GLTF, bin: Data, primitive: GLTF.Mesh.Primitive, baseURL: URL) throws -> VVEntityMaterial {
    let m = VVEntityMaterial()
    let matIndex = primitive.material ?? 0
    let gltfMat = gltf.materials?.safe(matIndex)

    // Defaults
    var baseColorFactor: SIMD4<Float> = [1,1,1,1]
    var metallic: Float = 1.0
    var roughness: Float = 1.0

    if let pbr = gltfMat?.pbrMetallicRoughness {
        if let f = pbr.baseColorFactor, f.count == 4 {
            baseColorFactor = [f[0], f[1], f[2], f[3]]
        }
        metallic  = pbr.metallicFactor ?? metallic
        roughness = pbr.roughnessFactor ?? roughness

        // Base color texture
        if let texInfo = pbr.baseColorTexture {
            if let baseColorMap = try loadTextureCGImage(gltf: gltf, bin: bin, textureIndex: texInfo.index, baseURL: baseURL) {
                m.baseColorMap = baseColorMap
            }
            else {
                m.baseColorFactor = baseColorFactor
            }
        } else {
            m.baseColorFactor = baseColorFactor
        }

        // Metallic-Roughness texture (B=metallic, G=roughness) is the glTF convention.
        m.metallicFloatLiteral = metallic
        m.roughnessFloatLiteral = roughness
        
        if let mrInfo = pbr.metallicRoughnessTexture,
            let mrCG = try loadTextureCGImage(gltf: gltf, bin: bin, textureIndex: mrInfo.index, baseURL: baseURL) {
            
            // Extract channels into grayscale images
            let roughCG = try extractGrayscaleChannel(from: mrCG, channelIndex: 1) // G
            let metalCG = try extractGrayscaleChannel(from: mrCG, channelIndex: 2) // B

             // Create *linear/data* textures (NOT sRGB)
//            let roughTex = try TextureResource.init(image: roughCG, options: .init(semantic: .raw))
//            let metalTex = try TextureResource.init(image: metalCG, options: .init(semantic: .raw))
            
            m.roughnessMap = roughCG
            m.metallicMap  = metalCG
            
        }
    } else {
        m.metallicFloatLiteral = metallic
        m.roughnessFloatLiteral = roughness
    }

    // Normal map
    if let n = gltfMat?.normalTexture {
        if let normalMap = try loadTextureCGImage(gltf: gltf, bin: bin, textureIndex: n.index, baseURL: baseURL) {
            m.normalMap = normalMap
        }
    }

    // Emissive
    if let e = gltfMat?.emissiveFactor, e.count == 3 {
        m.emissiveColor = .init(red: CGFloat(e[0]), green: CGFloat(e[1]), blue: CGFloat(e[2]), alpha: CGFloat(1))
    }
    if let et = gltfMat?.emissiveTexture {
        if let emissiveMap = try loadTextureCGImage(gltf: gltf, bin: bin, textureIndex: et.index, baseURL: baseURL) {
            m.emissiveColorMap = emissiveMap
        }
    }

    // Alpha mode (very minimal)
    // TODO: support using UV-mapped texture for blending.
    switch gltfMat?.alphaMode ?? "OPAQUE" {
    case "BLEND":
        m.blendingMode = .transparent(opacity: 1.0)
    case "MASK":
        m.blendingMode = .transparent(opacity: 1.0)
        m.opacityThreshold = gltfMat?.alphaCutoff ?? 0.5
    default:
        break
    }

    // Double-sided
    m.doubleSided = gltfMat?.doubleSided ?? false

    return m
}

// MARK: - Texture loading (GLB embedded bufferView or external URI)

private func loadTextureCGImage(gltf: GLTF, bin: Data, textureIndex: Int, baseURL: URL) throws -> CGImage? {
    guard let texture = gltf.textures?.safe(textureIndex) else { return nil }
    guard let sourceIndex = texture.source, let image = gltf.images?.safe(sourceIndex) else { return nil }

    let imgData: Data
    if let bvIndex = image.bufferView {
        imgData = try readBufferView(gltf: gltf, bin: bin, bufferViewIndex: bvIndex)
    } else if let uri = image.uri {
        imgData = try Data(contentsOf: baseURL.appendingPathComponent(uri))
    } else {
        return nil
    }

    return decodeCGImage(from: imgData)
}

//private func loadTextureResource(gltf: GLTF, bin: Data, textureIndex: Int, baseURL: URL, semantic: RKTexSemantic) throws -> TextureResource? {
//    guard let cg = try loadTextureCGImage(gltf: gltf, bin: bin, textureIndex: textureIndex, baseURL: baseURL) else { return nil }
//
//    let opts = TextureResource.CreateOptions(semantic: (semantic == .colorSRGB) ? .color : .raw)
//    return try TextureResource(image: cg, options: opts)
//}

private func decodeCGImage(from data: Data) -> CGImage? {
    let cfData = data as CFData
    guard let src = CGImageSourceCreateWithData(cfData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

// MARK: - Accessor reading

private func readVec3Accessor(gltf: GLTF, bin: Data, accessorIndex: Int) throws -> [SIMD3<Float>] {
    let (raw, count, stride, _) = try readAccessorBytes(gltf: gltf, bin: bin, accessorIndex: accessorIndex, expectedType: "VEC3", expectedComponentType: 5126 /*FLOAT*/)
    var out: [SIMD3<Float>] = []
    out.reserveCapacity(count)

    raw.withUnsafeBytes { (p: UnsafeRawBufferPointer) in
        for i in 0..<count {
            let base = i * stride
            let x = p.load(fromByteOffset: base + 0, as: Float.self)
            let y = p.load(fromByteOffset: base + 4, as: Float.self)
            let z = p.load(fromByteOffset: base + 8, as: Float.self)
            out.append([x, y, z])
        }
    }
    return out
}

private func readVec2Accessor(gltf: GLTF, bin: Data, accessorIndex: Int) throws -> [SIMD2<Float>] {
    let (raw, count, stride, _) = try readAccessorBytes(gltf: gltf, bin: bin, accessorIndex: accessorIndex, expectedType: "VEC2", expectedComponentType: 5126 /*FLOAT*/)
    var out: [SIMD2<Float>] = []
    out.reserveCapacity(count)

    raw.withUnsafeBytes { (p: UnsafeRawBufferPointer) in
        for i in 0..<count {
            let base = i * stride
            let x = p.load(fromByteOffset: base + 0, as: Float.self)
            let y = p.load(fromByteOffset: base + 4, as: Float.self)
            out.append([x, y])
        }
    }
    return out
}

private func readIndexAccessorAsUInt32(gltf: GLTF, bin: Data, accessorIndex: Int) throws -> [UInt32] {
    guard let acc = gltf.accessors?.safe(accessorIndex) else { throw LoaderError.badIndex("accessor") }
    guard acc.type == "SCALAR" else { throw LoaderError.unsupported("Index accessor must be SCALAR") }
    guard let ct = acc.componentType else { throw LoaderError.missing("componentType") }

    let (raw, count, stride, _) = try readAccessorBytes(gltf: gltf, bin: bin, accessorIndex: accessorIndex, expectedType: "SCALAR", expectedComponentType: ct)

    var out: [UInt32] = []
    out.reserveCapacity(count)

    try raw.withUnsafeBytes { (p: UnsafeRawBufferPointer) in
        for i in 0..<count {
            let base = i * stride
            switch ct {
            case 5123: // UNSIGNED_SHORT
                let v = p.load(fromByteOffset: base, as: UInt16.self)
                out.append(UInt32(v))
            case 5125: // UNSIGNED_INT
                let v = p.load(fromByteOffset: base, as: UInt32.self)
                out.append(v)
            default:
                // Some files use UNSIGNED_BYTE, etc.
                throw LoaderError.unsupported("Index componentType \(ct) not supported in MVP")
            }
        }
    }
    return out
}

private func readAccessorBytes(
    gltf: GLTF,
    bin: Data,
    accessorIndex: Int,
    expectedType: String,
    expectedComponentType: Int
) throws -> (bytes: Data, count: Int, stride: Int, componentType: Int) {

    guard let acc = gltf.accessors?.safe(accessorIndex) else { throw LoaderError.badIndex("accessor") }
    guard acc.type == expectedType else { throw LoaderError.unsupported("Accessor type \(acc.type ?? "nil") != \(expectedType)") }
    guard let ct = acc.componentType else { throw LoaderError.missing("componentType") }
    guard ct == expectedComponentType else {
        throw LoaderError.unsupported("componentType \(ct) != expected \(expectedComponentType)")
    }
    guard let count = acc.count else { throw LoaderError.missing("count") }
    guard let bvIndex = acc.bufferView else { throw LoaderError.missing("bufferView") }

    let componentSize = componentTypeByteSize(ct)
    let componentsPerElem = numComponents(for: expectedType)
    let elemSize = componentSize * componentsPerElem

    let rawBV = try readBufferView(gltf: gltf, bin: bin, bufferViewIndex: bvIndex)

    let bv = try require(gltf.bufferViews?.safe(bvIndex), "bufferView")
    let bvStride = bv.byteStride ?? 0
    let stride = (bvStride != 0) ? bvStride : elemSize

    let accessorOffset = acc.byteOffset ?? 0

    let needed: Int
    if count == 0 {
        needed = accessorOffset
    } else {
        needed = accessorOffset + (count - 1) * stride + elemSize
    }

    guard rawBV.count >= needed else {
        print("Failed to read accessor bytes: out of range (\(rawBV.count)/\(needed)) stride=\(stride) elemSize=\(elemSize) count=\(count) offset=\(accessorOffset)")
        throw LoaderError.outOfRange("accessor read out of range")
    }

    let slice = rawBV.subdata(in: accessorOffset..<needed)
    return (slice, count, stride, ct)
}

private func readBufferView(gltf: GLTF, bin: Data, bufferViewIndex: Int) throws -> Data {
    let bv = try require(gltf.bufferViews?.safe(bufferViewIndex), "bufferView")
    let bufferIndex = bv.buffer ?? 0
    guard bufferIndex == 0 else { throw LoaderError.unsupported("Only GLB buffer 0 supported in MVP") }

    let offset = bv.byteOffset ?? 0
    let length = bv.byteLength ?? 0
    guard bin.count >= offset + length else { throw LoaderError.outOfRange("bufferView out of range") }

    return bin.subdata(in: offset..<(offset + length))
}

private func componentTypeByteSize(_ ct: Int) -> Int {
    switch ct {
    case 5120, 5121: return 1 // BYTE, UNSIGNED_BYTE
    case 5122, 5123: return 2 // SHORT, UNSIGNED_SHORT
    case 5125, 5126: return 4 // UNSIGNED_INT, FLOAT
    default: return 0
    }
}

private func numComponents(for accessorType: String) -> Int {
    switch accessorType {
    case "SCALAR": return 1
    case "VEC2":   return 2
    case "VEC3":   return 3
    case "VEC4":   return 4
    case "MAT4":   return 16
    default:       return 0
    }
}

// MARK: - GLB parsing

private struct GLB {
    let jsonChunk: Data
    let binChunk: Data?

    static func parse(_ data: Data) throws -> GLB {
        // https://github.com/KhronosGroup/glTF/tree/main/specification/2.0#glb-file-format-specification
        // (We’re implementing only what we need.)
        var r = DataReader(data)

        let magic = try r.u32()
        guard magic == 0x46546C67 else { throw LoaderError.badGLB("bad magic") } // 'glTF'
        _ = try r.u32() // version
        _ = try r.u32() // length

        var json: Data?
        var bin: Data?

        while !r.isAtEnd {
            let chunkLength = Int(try r.u32())
            let chunkType   = try r.u32()
            let chunkData   = try r.bytes(count: chunkLength)

            switch chunkType {
            case 0x4E4F534A: // 'JSON'
                json = chunkData
            case 0x004E4942: // 'BIN\0'
                bin = chunkData
            default:
                // ignore unknown chunks
                break
            }
        }

        guard let j = json else { throw LoaderError.badGLB("missing JSON chunk") }
        return GLB(jsonChunk: j, binChunk: bin)
    }
}

private struct DataReader {
    let data: Data
    var offset: Int = 0
    init(_ d: Data) { self.data = d }

    var isAtEnd: Bool { offset >= data.count }

    mutating func u32() throws -> UInt32 {
        let n = 4
        guard offset + n <= data.count else { throw LoaderError.outOfRange("read u32") }
        let v = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
        offset += n
        return v
    }

    mutating func bytes(count: Int) throws -> Data {
        guard offset + count <= data.count else { throw LoaderError.outOfRange("read bytes") }
        let out = data.subdata(in: offset..<(offset + count))
        offset += count
        return out
    }
}

// MARK: - Minimal glTF JSON model

private struct GLTF: Decodable {
    var scene: Int?
    var scenes: [Scene]?
    var nodes: [Node]?
    var meshes: [Mesh]?
    var accessors: [Accessor]?
    var bufferViews: [BufferView]?
    var materials: [Material]?
    var textures: [Texture]?
    var images: [Image]?

    struct Scene: Decodable { var nodes: [Int]? }

    struct Node: Decodable {
        var mesh: Int?
        var children: [Int]?
        var matrix: [Float]?
        var translation: [Float]?
        var rotation: [Float]?
        var scale: [Float]?
    }

    struct Mesh: Decodable {
        var primitives: [Primitive]?

        struct Primitive: Decodable {
            var attributes: [String: Int]
            var indices: Int?
            var material: Int?
            var mode: Int? // 4 = TRIANGLES
        }
    }

    struct Accessor: Decodable {
        var bufferView: Int?
        var byteOffset: Int?
        var componentType: Int?
        var count: Int?
        var type: String?
    }

    struct BufferView: Decodable {
        var buffer: Int?
        var byteOffset: Int?
        var byteLength: Int?
        var byteStride: Int?
    }

    struct Material: Decodable {
        var pbrMetallicRoughness: PBR?
        var normalTexture: TextureInfo?
        var emissiveTexture: TextureInfo?
        var emissiveFactor: [Float]?
        var alphaMode: String?
        var alphaCutoff: Float?
        var doubleSided: Bool?

        struct PBR: Decodable {
            var baseColorFactor: [Float]?
            var baseColorTexture: TextureInfo?
            var metallicFactor: Float?
            var roughnessFactor: Float?
            var metallicRoughnessTexture: TextureInfo?
        }
    }

    struct Texture: Decodable { var source: Int? }

    struct Image: Decodable {
        var uri: String?
        var bufferView: Int?
        var mimeType: String?
    }

    struct TextureInfo: Decodable { var index: Int }
}

// MARK: - Helpers / Errors

private enum LoaderError: Error {
    case missingScene
    case badIndex(String)
    case missing(String)
    case unsupported(String)
    case badGLB(String)
    case outOfRange(String)
}

private func require<T>(_ v: T?, _ name: String) throws -> T {
    guard let v else { throw LoaderError.missing(name) }
    return v
}

private extension Array {
    func safe(_ i: Int) -> Element? { (i >= 0 && i < count) ? self[i] : nil }
}

