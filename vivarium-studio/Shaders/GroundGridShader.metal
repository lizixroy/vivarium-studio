//
//  GroundGridShader.metal
//  vivarium-studio
//
//  Created by Roy Li on 1/7/26.
//

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

struct GridUniforms
{
    float4 cameraWorld;
    float4 gridOrigin;
    float4 params1;   // x=baseCell, y=majorEvery, z=axisWidth, w=gridFadeDistance
    float4 params2;   // x=minorIntensity, y=majorIntensity, z=axisIntensity, w=worldCameraHeight
    float4 params3;   // x=viewportSizeWdith, y=viewportSizeHeight, z=unused, w=unused
};

struct Uniforms {
    float4x4 viewProj;        // Projection * View (or ViewProjection)
    float2   viewportSize;    // in pixels, e.g. (width, height)
};

// Anti-aliased line function for a 2D grid in coordinate space "u" where integer lines occur at ...,-1,0,1,...
static inline float gridLineAA(float2 u)
{
    // Distance to nearest integer line in each axis, 0 at line, 0.5 at cell center.
    float2 du = abs(fract(u) - 0.5);
    // Convert to "distance in cells" from the nearest line.
    float2 distToLine = 0.5 - du;

    // Screen-space derivative for AA (works well for procedural lines).
    float2 w = fwidth(u);
    w = max(w, float2(1e-6));

    float2 a = smoothstep(float2(0.0), w, distToLine);
    // a is 0 near line? Actually smoothstep increases away from 0; we want bright at line -> invert:
    float lineX = 1.0 - a.x;
    float lineY = 1.0 - a.y;

    // Union of vertical/horizontal lines
    return max(lineX, lineY);
}

// Axis line (X=0 or Z=0) in world space with AA, width in meters.
static inline float axisLineAA(float coord, float widthMeters)
{
    float w = fwidth(coord);
    w = max(w, 1e-6);
    // Bright when |coord| is small
    return 1.0 - smoothstep(widthMeters - w, widthMeters + w, abs(coord));
}

#include <metal_stdlib>
using namespace metal;

// ---------- Helpers ----------

static inline float3 homogenize(float4 p)
{
    return p.xyz / p.w;
}

// Build a world-space ray from NDC (x,y) at two depths.
// For Metal, NDC z is typically [0..1] (near=0, far=1).
static inline void rayFromNDC(
    float2 ndcXY,
    float4x4 invViewProj,
    thread float3 &outOrigin,
    thread float3 &outDir)
{
    // NDC points on near and far planes
    float4 pNearH = float4(ndcXY, 0.0, 1.0);
    float4 pFarH  = float4(ndcXY, 1.0, 1.0);

    // Unproject to world
    float3 pNearW = homogenize(invViewProj * pNearH);
    float3 pFarW  = homogenize(invViewProj * pFarH);

    outOrigin = pNearW;
    outDir    = normalize(pFarW - pNearW);
}

// Intersect ray with ground plane y=0.
// Returns false if parallel or behind origin.
static inline bool intersectGroundY0(
    float3 origin,
    float3 dir,
    thread float3 &outHit)
{
    const float eps = 1e-6;
    if (fabs(dir.y) < eps) return false;

    float t = -origin.y / dir.y;
    if (t < 0.0) return false;

    outHit = origin + t * dir;
    return true;
}

// Project a world point to screen pixels using view-projection and viewport size.
// Assumes Metal NDC range x,y in [-1,1].
static inline float2 worldToScreenPx(
    float3 worldPos,
    const float4x4 viewProj,
    float2 viewportSizePx)
{
    float4 clip = viewProj * float4(worldPos, 1.0);
    float3 ndc  = clip.xyz / clip.w; // perspective divide

    // NDC -> screen (origin at top-left)
    float x = (ndc.x * 0.5 + 0.5) * viewportSizePx.x;
    float y = (1.0 - (ndc.y * 0.5 + 0.5)) * viewportSizePx.y;
    return float2(x, y);
}

static inline float4x4 invertRigidWorldToView(float4x4 W2V)
{
    // Extract rotation (upper-left 3x3, column-major)
    float3x3 R = float3x3(
        W2V[0].xyz,
        W2V[1].xyz,
        W2V[2].xyz
    );

    // Extract translation
    float3 t = W2V[3].xyz;

    // Invert rigid transform
    float3x3 Rt = transpose(R);
    float3 invT = -(Rt * t);

    return float4x4(
        float4(Rt[0], 0.0),
        float4(Rt[1], 0.0),
        float4(Rt[2], 0.0),
        float4(invT,  1.0)
    );
}

//// Drop-in replacement for your current groundGridSurface.
//// Keeps your overall structure but adds smooth decade (×10) cross-fade
//// so major lines don’t pop back to 100% when cell promotes.
//[[ stitchable ]]
//void groundGridSurface(realitykit::surface_parameters params, constant GridUniforms& u)
//{
//    // --- Inputs ---
//    float3 wp = params.geometry().world_position();
//
//    float baseCell       = u.params1.x;   // smallest cell in world units (e.g. 0.1m)
//    float majorEvery     = u.params1.y;   // major cell = minor * majorEvery
//    float axisWidth      = u.params1.z;   // unused here (keep for future)
//    float fadeDistance   = u.params1.w;   // unused here (keep for future)
//
//    float minorIntensity = u.params2.x;
//    float majorIntensity = u.params2.y;
//    float axisIntensity  = u.params2.z;   // unused here (keep for future)
//    float worldCameraHeight = u.params2.w; // unused here (keep for future)
//
//    float viewportSizeWidth  = u.params3.x;
//    float viewportSizeHeight = u.params3.y;
//
//    float2 viewportSize = float2(viewportSizeWidth, viewportSizeHeight);
//
//    // --- Build a camera ray through NDC (0,0) and intersect ground y=0 ---
//    float3 rayO, rayD;
//    float4x4 invVP = invertRigidWorldToView(params.uniforms().world_to_view())
//                   * params.uniforms().projection_to_view();
//
//    rayFromNDC(float2(0.0, 0.0), invVP, rayO, rayD);
//
//    float3 Pref;
//    bool ok = intersectGroundY0(rayO, rayD, Pref);
//
//    if (!ok) {
//        half3 magenta = half3(1.0h, 0.0h, 1.0h);
//        params.surface().set_base_color(magenta);
//        params.surface().set_emissive_color(magenta);
//        params.surface().set_roughness(1.0h);
//        params.surface().set_metallic(0.0h);
//        params.surface().set_opacity(half(0.95h));
//        return;
//    }
//
//    // --- Pixel spacing measurement at Pref ---
//    const float4x4 viewProjectionMatrix =
//        params.uniforms().view_to_projection() * params.uniforms().world_to_view();
//
//    float3 P0 = Pref;
//    float3 P1 = Pref + float3(baseCell, 0.0, 0.0); // baseCell step on ground
//
//    float2 s0 = worldToScreenPx(P0, viewProjectionMatrix, viewportSize);
//    float2 s1 = worldToScreenPx(P1, viewProjectionMatrix, viewportSize);
//
//    float pxPerBaseCell = length(s1 - s0);
//
//    // --- Your fade window (in pixels) ---
//    float fadingStartDistance = 12.0; // above this: fully visible
//    float vanishDistance      = 3.0;  // below this: should vanish
//
//    // Helper: pixel length -> fade in [0,1]
//    auto fadeFromPx = [&](float px) -> float {
//        float denom = max(fadingStartDistance - vanishDistance, 1e-6);
//        float f = (px - vanishDistance) / denom;
//        return clamp(f, 0.0, 1.0);
//    };
//
//    // --- Smooth decade promotion (stateless) ---
//    // kf increases smoothly as base cell gets denser than vanishDistance.
//    float kf = log10(vanishDistance / max(pxPerBaseCell, 1e-6));
//    kf = max(kf, 0.0);
//
//    float k0 = floor(kf);
//    float t  = clamp(kf - k0, 0.0, 1.0);
//
//    // Ease the blend so it doesn’t feel linear
//    float blend = smoothstep(0.0, 1.0, t);
//
//    // Two neighboring decades
//    float cell0 = baseCell * pow(10.0, k0);
//    float cell1 = cell0 * 10.0;
//
//    float majorCell0 = cell0 * majorEvery;
//    float majorCell1 = cell1 * majorEvery;
//
//    // Measure pixel lengths for cell0 and cell1 (for per-decade fading)
//    float2 sCell0 = worldToScreenPx(Pref + float3(cell0, 0.0, 0.0), viewProjectionMatrix, viewportSize);
//    float2 sCell1 = worldToScreenPx(Pref + float3(cell1, 0.0, 0.0), viewProjectionMatrix, viewportSize);
//
//    float px0 = length(sCell0 - s0);
//    float px1 = length(sCell1 - s0);
//
//    float fade0 = fadeFromPx(px0);
//    float fade1 = fadeFromPx(px1);
//
//    // --- Grid evaluation in world XZ ---
//    float2 p = (wp.xz - u.gridOrigin.xz);
//
//    float minor0 = gridLineAA(p / cell0);
//    float major0 = gridLineAA(p / majorCell0);
//
//    float minor1 = gridLineAA(p / cell1);
//    float major1 = gridLineAA(p / majorCell1);
//
//    // --- Compose intensity per decade (close to your original intent) ---
//    // Each decade uses its own fade0/fade1 so they gracefully fade as they get too dense.
//    float line0;
//    if (major0 > 0.0) {
//        float base = minor0 * minorIntensity;
//        float target = (major0 * majorIntensity + minor0 * minorIntensity) * fade0;
//        line0 = mix(base, target, fade0);
//    } else {
//        line0 = minor0 * minorIntensity * fade0;
//    }
//
//    float line1;
//    if (major1 > 0.0) {
//        float base = minor1 * minorIntensity;
//        float target = (major1 * majorIntensity + minor1 * minorIntensity) * fade1;
//        line1 = mix(base, target, fade1);
//    } else {
//        line1 = minor1 * minorIntensity * fade1;
//    }
//
//    // --- Cross-fade between decades (prevents popping at promotion boundaries) ---
//    float line = mix(line0, line1, blend);
//
//    // Optional safety clamp (emissive can look harsh if >1)
//    line = clamp(line, 0.0, 1.0);
//
//    half3 outC = half3(line);
//
//    params.surface().set_emissive_color(outC);
//    params.surface().set_roughness(1.0h);
//    params.surface().set_metallic(0.0h);
//    params.surface().set_opacity(half(0.95h));
//}

[[ stitchable ]]
void groundGridSurface(realitykit::surface_parameters params, constant GridUniforms& u)
{
    // Read per-fragment world position of the underlying plane mesh.
    float3 wp = params.geometry().world_position(); // available via geometry()  [oai_citation:3‡Apple Developer](https://developer.apple.com/metal/Metal-RealityKit-APIs.pdf)
    
    float baseCell       = u.params1.x;
    float majorEvery     = u.params1.y;
    float axisWidth      = u.params1.z;
    float fadeDistance   = u.params1.w;

    float minorIntensity = u.params2.x;
    float majorIntensity = u.params2.y;
    float axisIntensity  = u.params2.z;
    float worldCameraHeight = u.params2.w;
    
    float viewportSizeWidth = u.params3.x;
    float viewportSizeHeight = u.params3.y;
        
    float minorWorld = baseCell; // also passed from Swift, e.g. 0.1 meters
    float3 rayO, rayD;
    float4x4 invVP = invertRigidWorldToView(params.uniforms().world_to_view()) * params.uniforms().projection_to_view();
    rayFromNDC(float2(0.0, 0.0), invVP, rayO, rayD);

    float3 Pref;
    bool ok = intersectGroundY0(rayO, rayD, Pref);

    if (!ok) {
        half3 base = half3(1.0h, 0.0h, 1.0h);
        params.surface().set_base_color( base ); // RED
        params.surface().set_emissive_color( base ); // RED
        return;
    }
    
    // Fallback if looking parallel to ground: use camera ray origin projected to y=0
    if (!ok) {
        Pref = float3(rayO.x, 0.0, rayO.z);
        half3 base = half3(1.0h, 0.0h, 1.0h);
        params.surface().set_base_color(base);
        params.surface().set_emissive_color(base);
        return;
    }
    
    // Measure pixel spacing at Pref along +X on the ground
    float3 P0 = Pref;
    float3 P1 = Pref + float3(minorWorld, 0.0, 0.0);

    const float4x4 viewProjectionMatrix = params.uniforms().view_to_projection() * params.uniforms().world_to_view();
    float2 viewportSize = {viewportSizeWidth, viewportSizeHeight};
    float2 s0 = worldToScreenPx(P0, viewProjectionMatrix, viewportSize);
    float2 s1 = worldToScreenPx(P1, viewProjectionMatrix, viewportSize);
    
    float majorToMinorFade = 1.0;
    float baseCellLengthInPixels = length(s1 - s0);
        
    float fadingStartDistance = 12;
    float vanishDistance = 3;
    float fadingFraction = 1.0;
    
    float k = ceil(log10(vanishDistance / baseCellLengthInPixels));
    k = max(k, 0.0);
    float cell = baseCell * pow(10.0, k);
    
    float3 P2 = Pref + float3(cell, 0.0, 0.0);
    float2 s2 = worldToScreenPx(P2, viewProjectionMatrix, viewportSize);
    float currentCellLengthInPixels = length(s2 - s0);
    
    if (currentCellLengthInPixels < fadingStartDistance) {
        float totalDistance = fadingStartDistance - vanishDistance;
        float actualDistance = currentCellLengthInPixels - vanishDistance;
        fadingFraction = actualDistance / totalDistance;
        majorToMinorFade = fadingFraction;
    }
    float majorCell = cell * majorEvery;

    // Convert world xz to grid coordinate space.
    float2 p = (wp.xz - u.gridOrigin.xz);
    
    // Minor and major grids:
    float minor = gridLineAA(p / cell);
    float major = gridLineAA(p / majorCell);
            
    half3 line = half3(0.0);
    if (major > 0) {
        float base = minor * minorIntensity;
        float target = (major * majorIntensity + minor * minorIntensity) * fadingFraction;
        line = mix(base, target, fadingFraction);
    }
    else {
        line = minor * minorIntensity * fadingFraction;
    }
    
    params.surface().set_emissive_color(line);
    params.surface().set_roughness(1.0h);
    params.surface().set_metallic(0.0h);
    // Keep plane present but subtle; you can drop this if you only want lines.
    params.surface().set_opacity(half(0.95h));
}
