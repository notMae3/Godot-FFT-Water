#[compute]
#version 460

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba32f, binding = 1) restrict uniform image2DArray _InitialSpectrumTextures;
layout(std430, binding = 0) restrict buffer param_uniforms {
    uint _N;
};


void main() {
    uvec3 id = gl_GlobalInvocationID;

    for (uint i = 0; i < 4; ++i) {
        vec2 h0 = imageLoad(_InitialSpectrumTextures, ivec3(id.xy, i)).rg;
        vec2 h0conj = imageLoad(_InitialSpectrumTextures, ivec3((_N - id.x ) % _N, (_N - id.y) % _N, i)).rg;

        imageStore(_InitialSpectrumTextures, ivec3(id.xy, i), vec4(h0, h0conj.x, -h0conj.y));
    }
}