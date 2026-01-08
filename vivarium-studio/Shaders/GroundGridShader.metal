//
//  GroundGridShader.metal
//  vivarium-studio
//
//  Created by Roy Li on 1/7/26.
//

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

// Keep this tightly packed and 16-byte aligned where possible.
//struct GridUniforms
//{
//    packed_float4 cameraWorld;   float _pad0;
//    packed_float4 gridOrigin;    float _pad1;   // usually [0,0,0]
//    float baseCell;              // e.g. 0.1 meters
//    float majorEvery;            // e.g. 10 (major line each 10 minor cells)
//    float axisWidth;             // e.g. 2.0 (relative line thickness multiplier)
//    float gridFadeDistance;      // e.g. 80 meters (fade out far)
//    float minorIntensity;        // e.g. 0.20
//    float majorIntensity;        // e.g. 0.45
//    float axisIntensity;         // e.g. 0.85
//};

struct GridUniforms
{
    float4 cameraWorld;
    float4 gridOrigin;
    float4 params1;   // x=baseCell, y=majorEvery, z=axisWidth, w=gridFadeDistance
    float4 params2;   // x=minorIntensity, y=majorIntensity, z=axisIntensity, w=unused
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
    

    // Distance from camera to this fragment (for LOD / scale).
    float dist = length(u.cameraWorld.xyz - wp);

    // Choose grid cell size ~ powers of 10, blended smoothly.
    // Feel free to tune the constants to match your navigation feel.
    float d = max(dist, 1e-3);

    // "zoom" changes scale when camera moves away:
    // when d grows, cell grows.
    float logv = log10(d);
    float k = floor(logv);               // integer decade
    float t = smoothstep(0.2, 0.8, fract(logv)); // blend between decades

    float cellA = baseCell * pow(10.0, k);
    float cellB = baseCell * pow(10.0, k + 1.0);
    float cell  = mix(cellA, cellB, t);

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
