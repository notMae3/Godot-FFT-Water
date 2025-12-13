#[compute]
#version 460

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba32f, binding = 1) restrict uniform image2DArray _InitialSpectrumTextures;
layout(std430, binding = 0) restrict buffer param_uniforms {
    vec4 _LengthScales;
    uint _N;
    uint _Seed;
    float _Depth;
    float _Gravity;
    float _LowCutoff;
    float _HighCutoff;

    float Spec1_scale;
    float Spec1_angle;
    float Spec1_spreadBlend;
    float Spec1_swell;
    float Spec1_alpha;
    float Spec1_peakOmega;
    float Spec1_gamma;
    float Spec1_shortWavesFade;

    float Spec2_scale;
    float Spec2_angle;
    float Spec2_spreadBlend;
    float Spec2_swell;
    float Spec2_alpha;
    float Spec2_peakOmega;
    float Spec2_gamma;
    float Spec2_shortWavesFade;

    float Spec3_scale;
    float Spec3_angle;
    float Spec3_spreadBlend;
    float Spec3_swell;
    float Spec3_alpha;
    float Spec3_peakOmega;
    float Spec3_gamma;
    float Spec3_shortWavesFade;

    float Spec4_scale;
    float Spec4_angle;
    float Spec4_spreadBlend;
    float Spec4_swell;
    float Spec4_alpha;
    float Spec4_peakOmega;
    float Spec4_gamma;
    float Spec4_shortWavesFade;

    float Spec5_scale;
    float Spec5_angle;
    float Spec5_spreadBlend;
    float Spec5_swell;
    float Spec5_alpha;
    float Spec5_peakOmega;
    float Spec5_gamma;
    float Spec5_shortWavesFade;

    float Spec6_scale;
    float Spec6_angle;
    float Spec6_spreadBlend;
    float Spec6_swell;
    float Spec6_alpha;
    float Spec6_peakOmega;
    float Spec6_gamma;
    float Spec6_shortWavesFade;

    float Spec7_scale;
    float Spec7_angle;
    float Spec7_spreadBlend;
    float Spec7_swell;
    float Spec7_alpha;
    float Spec7_peakOmega;
    float Spec7_gamma;
    float Spec7_shortWavesFade;

    float Spec8_scale;
    float Spec8_angle;
    float Spec8_spreadBlend;
    float Spec8_swell;
    float Spec8_alpha;
    float Spec8_peakOmega;
    float Spec8_gamma;
    float Spec8_shortWavesFade;
};

#define PI 3.14159265358979323846

struct SpectrumParameters {
	float scale;
	float angle;
	float spreadBlend;
	float swell;
	float alpha;
	float peakOmega;
	float gamma;
	float shortWavesFade;
};

SpectrumParameters _Spectrums[8] = SpectrumParameters[] (
    SpectrumParameters(
        Spec1_scale,
        Spec1_angle,
        Spec1_spreadBlend,
        Spec1_swell,
        Spec1_alpha,
        Spec1_peakOmega,
        Spec1_gamma,
        Spec1_shortWavesFade
    ),
    SpectrumParameters(
        Spec2_scale,
        Spec2_angle,
        Spec2_spreadBlend,
        Spec2_swell,
        Spec2_alpha,
        Spec2_peakOmega,
        Spec2_gamma,
        Spec2_shortWavesFade
    ),
    SpectrumParameters(
        Spec3_scale,
        Spec3_angle,
        Spec3_spreadBlend,
        Spec3_swell,
        Spec3_alpha,
        Spec3_peakOmega,
        Spec3_gamma,
        Spec3_shortWavesFade
    ),
    SpectrumParameters(
        Spec4_scale,
        Spec4_angle,
        Spec4_spreadBlend,
        Spec4_swell,
        Spec4_alpha,
        Spec4_peakOmega,
        Spec4_gamma,
        Spec4_shortWavesFade
    ),
    SpectrumParameters(
        Spec5_scale,
        Spec5_angle,
        Spec5_spreadBlend,
        Spec5_swell,
        Spec5_alpha,
        Spec5_peakOmega,
        Spec5_gamma,
        Spec5_shortWavesFade
    ),
    SpectrumParameters(
        Spec6_scale,
        Spec6_angle,
        Spec6_spreadBlend,
        Spec6_swell,
        Spec6_alpha,
        Spec6_peakOmega,
        Spec6_gamma,
        Spec6_shortWavesFade
    ),
    SpectrumParameters(
        Spec7_scale,
        Spec7_angle,
        Spec7_spreadBlend,
        Spec7_swell,
        Spec7_alpha,
        Spec7_peakOmega,
        Spec7_gamma,
        Spec7_shortWavesFade
    ),
    SpectrumParameters(
        Spec8_scale,
        Spec8_angle,
        Spec8_spreadBlend,
        Spec8_swell,
        Spec8_alpha,
        Spec8_peakOmega,
        Spec8_gamma,
        Spec8_shortWavesFade
    )
);


float hash(uint n) {
    // integer hash copied from Hugo Elias
    n = (n << 13U) ^ n;
    n = n * (n * n * 15731U + 0x789221U) + 0x13763589U;
    return float(n & uint(0x7fffffffU)) / float(0x7fffffff);
}

vec2 UniformToGaussian(float u1, float u2) {
    float R = sqrt(-2.0f * log(u1));
    float theta = 2.0f * PI * u2;

    return vec2(R * cos(theta), R * sin(theta));
}

float Dispersion(float kMag) {
    return sqrt(_Gravity * kMag * tanh(min(kMag * _Depth, 20)));
}

float DispersionDerivative(float kMag) {
    float th = tanh(min(kMag * _Depth, 20));
    float ch = cosh(kMag * _Depth);
    return _Gravity * (_Depth * kMag / ch / ch + th) / Dispersion(kMag) / 2.0f;
}

float NormalizationFactor(float s) {
    float s2 = s * s;
    float s3 = s2 * s;
    float s4 = s3 * s;
    if (s < 5) return -0.000564f * s4 + 0.00776f * s3 - 0.044f * s2 + 0.192f * s + 0.163f;
    else return -4.80e-08f * s4 + 1.07e-05f * s3 - 9.53e-04f * s2 + 5.90e-02f * s + 3.93e-01f;
}

float Cosine2s(float theta, float s) {
	return NormalizationFactor(s) * pow(abs(cos(0.5f * theta)), 2.0f * s);
}

float lerp(float v0, float v1, float t) {
    return v0 + t * (v1 - v0);
}

float SpreadPower(float omega, float peakOmega) {
	if (omega > peakOmega)
		return 9.77f * pow(abs(omega / peakOmega), -2.5f);
	else
		return 6.97f * pow(abs(omega / peakOmega), 5.0f);
}

float DirectionSpectrum(float theta, float omega, SpectrumParameters spectrum) {
	float s = SpreadPower(omega, spectrum.peakOmega) + 16 * tanh(min(omega / spectrum.peakOmega, 20)) * spectrum.swell * spectrum.swell;
	return lerp(2.0f / 3.1415f * cos(theta) * cos(theta), Cosine2s(theta - spectrum.angle, s), spectrum.spreadBlend);
}

float TMACorrection(float omega) {
	float omegaH = omega * sqrt(_Depth / _Gravity);
	if (omegaH <= 1.0f)
		return 0.5f * omegaH * omegaH;
	if (omegaH < 2.0f)
		return 1.0f - 0.5f * (2.0f - omegaH) * (2.0f - omegaH);

	return 1.0f;
}

float JONSWAP(float omega, SpectrumParameters spectrum) {
	float sigma = (omega <= spectrum.peakOmega) ? 0.07f : 0.09f;

	float r = exp(-(omega - spectrum.peakOmega) * (omega - spectrum.peakOmega) / 2.0f / sigma / sigma / spectrum.peakOmega / spectrum.peakOmega);
	
	float oneOverOmega = 1.0f / omega;
	float peakOmegaOverOmega = spectrum.peakOmega / omega;
	return spectrum.scale * TMACorrection(omega) * spectrum.alpha * _Gravity * _Gravity
		* oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega
		* exp(-1.25f * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega)
		* pow(abs(spectrum.gamma), r);
}

float ShortWavesFade(float kLength, SpectrumParameters spectrum) {
	return exp(-spectrum.shortWavesFade * spectrum.shortWavesFade * kLength * kLength);
}


void main() {
    uvec3 id = gl_GlobalInvocationID;

    uint seed = id.x + _N * id.y + _N;
    seed += _Seed;

    float lengthScales[4] = { _LengthScales.x, _LengthScales.y, _LengthScales.z, _LengthScales.w };
    float halfN = _N / 2.0f;

    for (uint i = 0; i < 4; ++i) {
        float deltaK = 2.0f * PI / lengthScales[i];
        vec2 K = (id.xy - halfN) * deltaK;
        float kLength = length(K);

        seed = uint(i + hash(seed) * 10);
        vec4 uniformRandSamples = vec4(hash(seed), hash(seed * 2), hash(seed * 3), hash(seed * 4));
        vec2 gauss1 = UniformToGaussian(uniformRandSamples.x, uniformRandSamples.y);
        vec2 gauss2 = UniformToGaussian(uniformRandSamples.z, uniformRandSamples.w);

        if (_LowCutoff <= kLength && kLength <= _HighCutoff) {
            float kAngle = pow(atan(K.y, K.x), 2.0f);
            float omega = Dispersion(kLength);
            float dOmegadk = DispersionDerivative(kLength);

            float spectrum = JONSWAP(omega, _Spectrums[i * 2]) * DirectionSpectrum(kAngle, omega, _Spectrums[i * 2]) * ShortWavesFade(kLength, _Spectrums[i * 2]);            
            
            if (_Spectrums[i * 2 + 1].scale > 0)
                spectrum += JONSWAP(omega, _Spectrums[i * 2 + 1]) * DirectionSpectrum(kAngle, omega, _Spectrums[i * 2 + 1]) * ShortWavesFade(kLength, _Spectrums[i * 2 + 1]);

            vec4 spectrum_texture_color = vec4(vec2(gauss2.x, gauss1.y) * sqrt(2 * spectrum * abs(dOmegadk) / kLength * deltaK * deltaK), 0.0f, 0.0f);
            imageStore(_InitialSpectrumTextures, ivec3(id.xy, i), spectrum_texture_color);
        } else {
            imageStore(_InitialSpectrumTextures, ivec3(id.xy, i), vec4(0.0));
        }
    }
}
