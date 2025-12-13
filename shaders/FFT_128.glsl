#[compute]
#version 460

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(rgba32f, binding = 1) restrict uniform image2DArray _FourierTarget;
layout(std430, binding = 0) restrict buffer param_uniforms {
    bool _Direction; // true: horizontal fft, false: vertical fft
};

#define SIZE 128
#define LOG_SIZE 7
#define TWO_PI 6.28318530718

shared vec4 fftGroupBuffer[2][SIZE];


vec2 ComplexMult(vec2 a, vec2 b) {
    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

void ButterflyValues(uint step_, uint index, out uvec2 indices, out vec2 twiddle) {
    uint b = SIZE >> (step_ + 1);
    uint w = b * (index / b);
    uint i = (w + index) % SIZE;

    float angle = -TWO_PI / float(SIZE) * float(w);
    twiddle.y = sin(angle);
    twiddle.x = cos(angle);

    //This is what makes it the inverse FFT
    twiddle.y = -twiddle.y;
    indices = uvec2(i, i + b);
}

vec4 FFT(uint threadIndex, vec4 input_data) {
    fftGroupBuffer[0][threadIndex] = input_data;
    memoryBarrierShared();
    barrier();
    bool flag = false;

    for (uint step_ = 0; step_ < LOG_SIZE; ++step_) {
        uvec2 inputsIndices;
        vec2 twiddle;
        ButterflyValues(step_, threadIndex, inputsIndices, twiddle);

        vec4 v = fftGroupBuffer[flag ? 1 : 0][inputsIndices.y];
        fftGroupBuffer[!flag ? 1 : 0][threadIndex] = fftGroupBuffer[flag ? 1 : 0][inputsIndices.x] + vec4(ComplexMult(twiddle, v.xy), ComplexMult(twiddle, v.zw));

        flag = !flag;
        memoryBarrierShared();
        barrier();
    }

    return fftGroupBuffer[flag ? 1 : 0][threadIndex];
}


void main() {
    uvec3 id = gl_GlobalInvocationID;
    uvec2 image_coords = _Direction ? id.xy : id.yx;

    for (int i = 0; i < 8; ++i) {
        vec4 input_data = imageLoad(_FourierTarget, ivec3(image_coords, i));
        imageStore(_FourierTarget, ivec3(image_coords, i), FFT(id.x, input_data));
    }
}