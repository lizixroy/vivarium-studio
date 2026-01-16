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
    
    float minorPx = length(s1 - s0);
    if (minorPx < 12) {
         baseCell *= 10;
//        half3 base = half3(1.0h, 0.0h, 1.0h);
//        params.surface().set_base_color(base);
//        params.surface().set_emissive_color(base);
//        return;
    }
    
    // TODO: test only. Cap the dist at 0.6
    float dist = max(worldCameraHeight, 0.6);
        
    float cell  = baseCell;
    float majorCell = cell * majorEvery;

    // Convert world xz to grid coordinate space.
    float2 p = (wp.xz - u.gridOrigin.xz);
    
    // Minor and major grids:
    float minor = gridLineAA(p / cell);
    float major = gridLineAA(p / majorCell);
    
    // Axis lines at world X=0 (Z axis line) and world Z=0 (X axis line).
    // Use width proportional to cell so it stays visible.
    float axisW = cell * 0.05 * axisWidth;
    float axisX = axisLineAA(wp.x, axisW); // plane X==0 -> Z axis
    float axisZ = axisLineAA(wp.z, axisW); // plane Z==0 -> X axis

    // Fade grid out with distance (keeps the “infinite” plane from looking like a giant billboard).
    float fade = 1.0 - smoothstep(fadeDistance * 0.6, fadeDistance, dist);

    // Combine intensities.
    float g =
        minor * minorIntensity +
        major * majorIntensity +
        max(axisX, axisZ) * axisIntensity;

    g *= fade;

    // Slightly dark base with emissive lines (works well for editor-style look).
    // half3 base = half3(0.06h, 0.06h, 0.065h);
    half3 base = half3(1.0h, 0.5h, 1.0h);
    half3 line = half3(g);

    params.surface().set_base_color(base);
    params.surface().set_emissive_color(line);
    params.surface().set_roughness(1.0h);
    params.surface().set_metallic(0.0h);

    // Keep plane present but subtle; you can drop this if you only want lines.
    params.surface().set_opacity(half(0.95h));
}
