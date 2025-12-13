#[compute]
#version 460

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba32f, binding = 1) restrict uniform image2DArray _InitialSpectrumTextures;
layout(rgba32f, binding = 2) restrict uniform image2DArray _SpectrumTextures;
layout(std430, binding = 0) restrict buffer param_uniforms {
    vec4 _LengthScales;
    uint _N;
    float _Gravity;
    float _RepeatTime;
    float _FrameTime;
};

#define PI 3.14159265358979323846

vec2 ComplexMult(vec2 a, vec2 b) {
    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

vec2 EulerFormula(float x) {
    return vec2(cos(x), sin(x));
}


void main() {
    uvec3 id = gl_GlobalInvocationID;
    
    float lengthScales[4] = { _LengthScales.x, _LengthScales.y, _LengthScales.z, _LengthScales.w };

    for (int i = 0; i < 4; ++i) {
        vec4 initialSignal = imageLoad(_InitialSpectrumTextures, ivec3(id.xy, i));
        vec2 h0 = initialSignal.xy;
        vec2 h0conj = initialSignal.zw;

        float halfN = _N / 2.0f;
        vec2 K = (id.xy - halfN) * 2.0f * PI / lengthScales[i];
        float kMag = length(K);
        float kMagRcp = kMag < 0.0001f ? 1.0f : 1.0/kMag;

        float w_0 = 2.0f * PI / _RepeatTime;
        float dispersion = floor(sqrt(_Gravity * kMag) / w_0) * w_0 * _FrameTime;

        vec2 exponent = EulerFormula(dispersion);

        vec2 htilde = ComplexMult(h0, exponent) + ComplexMult(h0conj, vec2(exponent.x, -exponent.y));
        vec2 ih = vec2(-htilde.y, htilde.x);

        vec2 displacementX = ih * K.x * kMagRcp;
        vec2 displacementY = htilde;
        vec2 displacementZ = ih * K.y * kMagRcp;

        vec2 displacementX_dx = -htilde * K.x * K.x * kMagRcp;
        vec2 displacementY_dx = ih * K.x;
        vec2 displacementZ_dx = -htilde * K.x * K.y * kMagRcp;

        vec2 displacementY_dz = ih * K.y;
        vec2 displacementZ_dz = -htilde * K.y * K.y * kMagRcp;

        vec2 htildeDisplacementX = vec2(displacementX.x - displacementZ.y, displacementX.y + displacementZ.x);
        vec2 htildeDisplacementZ = vec2(displacementY.x - displacementZ_dx.y, displacementY.y + displacementZ_dx.x);
        
        vec2 htildeSlopeX = vec2(displacementY_dx.x - displacementY_dz.y, displacementY_dx.y + displacementY_dz.x);
        vec2 htildeSlopeZ = vec2(displacementX_dx.x - displacementZ_dz.y, displacementX_dx.y + displacementZ_dz.x);

        imageStore(_SpectrumTextures, ivec3(id.xy, i * 2), vec4(htildeDisplacementX, htildeDisplacementZ));
        imageStore(_SpectrumTextures, ivec3(id.xy, i * 2 + 1), vec4(htildeSlopeX, htildeSlopeZ));
    }
}
