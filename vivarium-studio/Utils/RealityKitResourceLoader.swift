//
//  RealityKitResourceLoader.swift
//  vivarium-studio
//
//  Created by Roy Li on 1/25/26.
//
//  A single entry point for loading 3D assets into RealityKit.
//
//  Supports:
//   - .usdz / .usd / .reality via RealityKit’s native loader
//   - .glb via your pure-Swift GLB importer (e.g. GLBRealityKitLoader / GLBIngestor)
//
//  Notes:
//   - RealityKit does NOT natively load glTF/GLB, so .glb is delegated to your importer.
//

import Foundation
import RealityKit

// MARK: - Public API

public enum RealityAssetType: Equatable, Sendable {
    case usdz
    case usd          // may or may not work depending on platform/packaging; usdz is safest
    case reality
    case glb

    /// Convenience: infer from file extension (lowercased).
    public static func infer(from url: URL) -> RealityAssetType? {
        switch url.pathExtension.lowercased() {
        case "usdz": return .usdz
        case "usd", "usda", "usdc": return .usd
        case "reality": return .reality
        case "glb": return .glb
        default: return nil
        }
    }
}

public enum RealityKitLoaderError: Error, CustomStringConvertible {
    case unsupportedType(RealityAssetType)
    case cannotInferType(String)
    case notAFileURL(URL)
    case missingGLBImporter(expectedSymbol: String)
    case underlying(Error)

    public var description: String {
        switch self {
        case .unsupportedType(let t):
            return "Unsupported asset type: \(t)"
        case .cannotInferType(let ext):
            return "Cannot infer asset type from extension: .\(ext)"
        case .notAFileURL(let url):
            return "URL must be a file URL: \(url)"
        case .missingGLBImporter(let sym):
            return "GLB importer not found. Expected to have a symbol named \(sym) in your project."
        case .underlying(let e):
            return "Underlying error: \(e)"
        }
    }
}

/// Central loader. Add more cases if you later support FBX/OBJ/etc via converters.
public final class RealityKitLoader {

    public static let shared = RealityKitLoader()

    private init() {}

    /// Load an entity from a file URL, given an explicit type.
    public func loadEntity(from url: URL, type: RealityAssetType) async throws -> VVEntity? {
        guard url.isFileURL else { throw RealityKitLoaderError.notAFileURL(url) }

        do {
            switch type {
            case .usdz, .usd, .reality:
                // Native RealityKit loading path
//                let entity = try await Entity(contentsOf: url)
                // return entity
                return nil
                
                
            case .glb:
                // Delegate to your pure-Swift importer.
                // Pick ONE of the adapters below and keep it consistent with your project.
                return try await loadGLBEntity(url)
            }
        } catch {
            throw RealityKitLoaderError.underlying(error)
        }
    }

    /// Convenience overload: infer type from file extension.
    public func loadEntity(from url: URL) async throws -> VVEntity? {
        let ext = url.pathExtension.lowercased()
        guard let t = RealityAssetType.infer(from: url) else {
            throw RealityKitLoaderError.cannotInferType(ext)
        }
        return try await loadEntity(from: url, type: t)
    }
}


// MARK: - GLB adapter (choose the symbol you actually have)

private extension RealityKitLoader {

    /// Adapter for GLB import.
    /// Update the symbol below to match your importer’s entry point.
    func loadGLBEntity(_ url: URL) async throws -> VVEntity {

        // --- Option A: if you have GLBRealityKitLoader.loadEntity(from:) ---
        // Uncomment this block if your importer is named GLBRealityKitLoader.

        /*
        return try await GLBRealityKitLoader.loadEntity(from: url)
        */

        // --- Option B: if you have GLBIngestor.loadEntity(fromGLB:) (from earlier snippet) ---
        // Uncomment this block if your importer is named GLBIngestor.

        return try await GLBRealityKitLoader.loadEntity2(from: url)

        // --- If neither symbol exists, fail loudly with a clear message.
//        throw RealityKitLoaderError.missingGLBImporter(
//            expectedSymbol: "GLBRealityKitLoader.loadEntity(from:)  OR  GLBIngestor.loadEntity(fromGLB:)"
//        )
    }
}
