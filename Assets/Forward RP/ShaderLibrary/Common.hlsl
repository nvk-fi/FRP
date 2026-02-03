#ifndef FRP_COMMON_INCLUDED
#define FRP_COMMON_INCLUDED

// Includes the language API header.
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

// Includes the randomness-related functions.
//#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Random.hlsl"

SAMPLER(sampler_PointClamp);
SAMPLER(sampler_PointRepeat);
SAMPLER(sampler_PointMirror);
SAMPLER(sampler_LinearClamp);
SAMPLER(sampler_LinearRepeat);

static const float epsilonFloat = 1e-6f;
static const half epsilonHalf = 1e-6h;
static const float onePlusEpsilonFloat = 1.0f + epsilonFloat;
static const half onePlusEpsilonHalf = 1.0h + epsilonHalf;
static const float sqrt2Float = 1.4142135623730950488016887242097f;
static const float inverseSqrt2Float = 1.0f / sqrt2Float; // 0.70710678118654752440084436210485f
static const float piFloat = 3.1415926535897932384626433832795f;
static const float inversePiFloat = 1.0f / piFloat; // 0.31830988618379067153776752674503f

// Normalises a vector using the fast inverse square root approximation.
inline half3 FastSafeNormalize(half3 input)
{
	half lengthSquared = max(epsilonHalf, dot(input, input));
	return input * rsqrt(lengthSquared);
}

// Normalises a vector using the fast inverse square root approximation.
inline float3 FastSafeNormalize(float3 input)
{
	float lengthSquared = max(epsilonFloat, dot(input, input));
	return input * rsqrt(lengthSquared);
}

// The linear luminosity of a colour
inline half FastLinearLuminosity(half3 color)
{
	// Not accurate, but the compiler will hopefully optimise this with bit shifting.
	return (color.r + color.g + color.g + color.b) / 4.0h;
}

// The sRGB colour space luminosity of a colour
inline half FastSRGBLuminosity(half3 color)
{
	color *= color;
	return FastLinearLuminosity(color);
}

// Calculates the mip level for a given texture coordinate and bias.
inline half MipLevel(half2 texelUV, half mipBias)
{
	half2 fw = fwidth(texelUV); // The fwidth is abs(ddx(x)) + abs(ddy(x)).
	half d = max(dot(fw, fw), epsilonHalf); // Squared length, so we don't have to calculate sqrt.
	half mipLevel = 0.5h * log2(d) + mipBias; // log2(x^2) = 2*log2(x)
	mipLevel = max(0.0h, mipLevel);

	return mipLevel;
}

// The half-Lambert diffuse term
inline half DiffuseTerm(half NdotL)
{
	half halfLambert = NdotL * 0.5h + 0.5h;
	halfLambert *= halfLambert;

	return halfLambert;
}

// The specular term by mixing Blinn-Phong and roughness
inline half SpecularTerm(half NdotH, half roughness, half shine)
{
	half roughnessAdjustment = (1.0h - roughness) * 2.0h;
	roughnessAdjustment *= roughnessAdjustment;
	half specular = pow(saturate(NdotH), shine) * roughnessAdjustment;
	
	return specular;
}

// Inverse-square attenuation
inline float DistanceAttenuation_InverseSquared(float distanceSquared)
{
	float distanceAttenuation = 1.0f / max(distanceSquared, epsilonFloat);
	return distanceAttenuation;
}

// Inverse-square attenuation with a smoothened range limit
inline float DistanceAttenuation_InverseSquareSmoothened(float distanceSquared, float rangeSquared)
{
	float distanceAttenuation = DistanceAttenuation_InverseSquared(distanceSquared);

	// This also takes into consideration the range property,
	// the theory being it allows mimicking a faint GI on distant walls as room size usually sets the range.
	distanceAttenuation *= 1.0f - smoothstep(rangeSquared * 0.5f, rangeSquared, distanceSquared);

	distanceAttenuation = saturate(distanceAttenuation);

	return distanceAttenuation;
}

// Smoothstep distance attenuation
inline float DistanceAttenuation_Smoothstep(float minDistanceSquared, float maxDistanceSquared, float sampleDistanceSquared)
{
	float distanceAttenuation = smoothstep(maxDistanceSquared, minDistanceSquared, sampleDistanceSquared);

	return distanceAttenuation;
}

// Angle attenuation for cones
inline float ConeAngleAttenuation(float3 coneForwardDirection, float3 coneToSampleDirection, float coneMaxAngle)
{
	float cosine = dot(coneForwardDirection, coneToSampleDirection);
	float halfAngle = cos(radians(coneMaxAngle * 0.5f));

	float angleAttenuation = (cosine - halfAngle) / max(1.0f - halfAngle, epsilonFloat);
	angleAttenuation = saturate(angleAttenuation);
	angleAttenuation *= angleAttenuation;

	return angleAttenuation;
}

// Angle attenuation for cones
inline float ConeAngleAttenuation(float3 coneForwardDirection, float3 conePosition, float3 samplePosition, float coneMaxAngle)
{
	float3 coneToSampleDirection = FastSafeNormalize(samplePosition - conePosition);
	float angleAttenuation = ConeAngleAttenuation(coneForwardDirection, coneToSampleDirection, coneMaxAngle);

	return angleAttenuation;
}

// Squared direction similarity between [0.0f, 1.0f]
inline float DirectionAttenuation(float3 forwardDirection, float3 sampleDirection)
{
	float directionAttenuation = dot(forwardDirection, sampleDirection) * 0.5f + 0.5f;
	directionAttenuation *= directionAttenuation;

	return directionAttenuation;
}

// Tonemapping with a threshold
inline half3 Tonemap(half3 color, half threshold)
{
	half3 ldr = min(color, threshold);
	half3 hdr = max(color - threshold, 0.0h);
	hdr = hdr / (hdr + 1.0h);
	half3 tonemapped = ldr + hdr;
	
	return tonemapped;
}

// Tonemapping with a default threshold
inline half3 Tonemap(half3 color)
{
	return Tonemap(color, 0.125h);
}

// Inexpensive 2D hash, which turns a coordinate into repeatable [0.0f, 1.0f] noise for kernel rotation.
inline float2 Hash22(float2 p)
{
	float3 p3 = frac(float3(p.xyx) * 0.1031f);
	p3 += dot(p3, p3.yzx + 33.33f);
	return frac((p3.xx + p3.yz) * p3.zy);
}

#endif // FRP_COMMON_INCLUDED
