#[compute]
#version 460

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba32f, binding = 1) restrict uniform image2DArray _SpectrumTextures;
layout(rgba32f, binding = 2) restrict uniform image2DArray _DisplacementTextures;
layout(rg32f, binding = 3) restrict uniform image2DArray _SlopeTextures;
layout(r32f, binding = 4) restrict uniform image2D _BuoyancyData;
layout(std430, binding = 0) restrict buffer param_uniforms {
    vec2 _Lambda;
    float _FoamBias;
    float _FoamDecayRate;
    float _FoamAdd;
    float _FoamThreshold;
};

vec4 Permute(vec4 data, vec3 id) {
    return data * (1.0f - 2.0f * mod(id.x + id.y, 2.0f));
}


void main() {
    uvec3 id = gl_GlobalInvocationID;

    for (int i = 0; i < 4; ++i) {
        vec4 htildeDisplacement = Permute(imageLoad(_SpectrumTextures, ivec3(id.xy, i * 2)), id);
        vec4 htildeSlope = Permute(imageLoad(_SpectrumTextures, ivec3(id.xy, i * 2 + 1)), id);

        vec2 dxdz = htildeDisplacement.rg;
        vec2 dydxz = htildeDisplacement.ba;
        vec2 dyxdyz = htildeSlope.rg;
        vec2 dxxdzz = htildeSlope.ba;
        
        float jacobian = (1.0f + _Lambda.x * dxxdzz.x) * (1.0f + _Lambda.y * dxxdzz.y) - _Lambda.x * _Lambda.y * dydxz.y * dydxz.y;

        vec3 displacement = vec3(_Lambda.x * dxdz.x, dydxz.x, _Lambda.y * dxdz.y);

        vec2 slopes = dyxdyz.xy / (1 + abs(dxxdzz * _Lambda));
        float covariance = slopes.x * slopes.y;

        float foam = imageLoad(_DisplacementTextures, ivec3(id.xy, i)).a;
        foam *= exp(-_FoamDecayRate);
        foam = clamp(foam, 0.0, 1.0);

        float biasedJacobian = max(0.0f, -(jacobian - _FoamBias));

        if (biasedJacobian > _FoamThreshold)
            foam += _FoamAdd * biasedJacobian;


        imageStore(_DisplacementTextures, ivec3(id.xy, i), vec4(displacement, foam));
        imageStore(_SlopeTextures, ivec3(id.xy, i), vec4(slopes, 0.0, 1.0));

        if (i == 0) {
            imageStore(_BuoyancyData, ivec2(id.xy), vec4(displacement.y, 0.0, 0.0, 1.0));
        }
    }
}