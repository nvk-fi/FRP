#ifndef FRP_POST_PROCESS_PASS_INCLUDED
#define FRP_POST_PROCESS_PASS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Input.hlsl"
#include "../ShaderLibrary/FragmentData.hlsl"
#include "../ShaderLibrary/RealtimeLight.hlsl"
#include "../ShaderLibrary/SunLight.hlsl"

TEXTURE2D(_MainColorRT);
TEXTURE2D(_MainFragmentRT);
TEXTURE2D(_PostPrepCurrentRT);
TEXTURE2D(_PostPrepHistoryRT);
TEXTURE2D(_PostEffectRT);
float4 _MainColorRT_TexelSize;
float4 _PostEffectRT_TexelSize;

// Tries to bandage the pinhole camera warp at higher FOVs or widescreen monitors.
inline float2 LensDistortUV(float2 uv)
{
	float distortStrength = _PostProcessParams.x;
	if (distortStrength <= epsilonFloat)
		return uv;
	
	float screenAspect = _ScreenParams.x / max(_ScreenParams.y, 1.0f);
	float scaledTanHalfFov = distortStrength * _TanHalfFov;
	float aspectDiagonalSquared = screenAspect * screenAspect + 1.0f;
	float scaledDiagonalSquared = scaledTanHalfFov * scaledTanHalfFov * aspectDiagonalSquared;
	float2 centeredUV = uv * 2.0f + float2(-1.0f, -1.0f);

	// Compute the lens projection depth from the scaled diagonal.
	float projectedZ = 0.5f * sqrt(scaledDiagonalSquared + 1.0f) + 0.5f;
	float aspectDenominator = screenAspect * screenAspect + 1.0f;
	float normalizedY = aspectDenominator > epsilonFloat ? (projectedZ - 1.0f) / aspectDenominator : 0.0f;
	float distortScale = sqrt(max(normalizedY, 0.0f));
	float2 scaledUV = distortScale * float2(screenAspect, 1.0f) * centeredUV;
	float3 baseUV = float3(0.5f, 0.5f, 1.0f) * projectedZ + float3(-0.5f, -0.5f, 0.0f);
	baseUV.xy += uv;

	float scaledUVLengthSquared = dot(scaledUV, scaledUV);
	float3 projectedUV = scaledUVLengthSquared * float3(-0.5f, -0.5f, -1.0f) + baseUV;
	float safeZ = max(projectedUV.z, epsilonFloat);
	float2 distortedUV = projectedUV.xy / safeZ; 

	return distortedUV;
}

// Calculates a smoother bloom value based on luminosity.
// Might be overkill.
inline half BloomValue(half3 color, half threshold)
{
	half luma = FastLinearLuminosity(color);
	half knee = threshold * 0.5h;
	half soft = luma - threshold + knee;
	soft = saturate(soft / max(knee * 2.0h, epsilonHalf));
	half bloomValue = max(luma - threshold, 0.0h) + soft * soft * knee;
	
	return bloomValue;
}

struct Varyings
{
	float4 positionCS : SV_POSITION;
	float2 uv : TEXCOORD0;
};

Varyings PostProcessVertex(uint vertexID : SV_VertexID)
{
	Varyings output = (Varyings)0;

	float2 uv = float2((vertexID << 1) & 2, vertexID & 2);
	output.positionCS = float4(uv * 2.0f - 1.0f, 0.0f, 1.0f);
	output.uv = uv;
	
	#if UNITY_UV_STARTS_AT_TOP
	if (_ProjectionParams.x < 0.0f)
		output.uv.y = 1.0f - uv.y;
	#endif

	return output;
}

half2 PostProcessPrepFragment(Varyings input) : SV_Target
{
	half2 output = 0;
		
	// Sunlight volumetrics
	float4 fragmentSample = SAMPLE_TEXTURE2D(_MainFragmentRT, sampler_PointClamp, input.uv);
	float distanceEstimate = fragmentSample.w;
	float3 V = fragmentSample.xyz;
	PostFragmentData fragmentData = CreatePostFragmentData(_CameraWS, V, distanceEstimate, input.uv);
	half volumetricSunAmount = AccumulateVolumetricSunLight(fragmentData) * 0.7h;
	volumetricSunAmount += SAMPLE_TEXTURE2D(_PostPrepHistoryRT, sampler_PointClamp, input.uv).r * 0.3h;
	
	output.r = volumetricSunAmount;
	
	// Bloom
	half bloom = 0.0h;
	half intensity = _PostProcessParams.y;
	half threshold = _PostProcessParams.z;
	half size = _PostProcessParams.w;
	if (intensity * size <= epsilonHalf)
		return output;
	
	float2 offset = _PostEffectRT_TexelSize.xy * (_ScreenParams.y / 1080.0f) * size * 3.0f;
	bloom += SAMPLE_TEXTURE2D(_PostPrepHistoryRT, sampler_LinearClamp, input.uv + float2(-offset.x, -offset.y)).g * 0.125h;
	bloom += SAMPLE_TEXTURE2D(_PostPrepHistoryRT, sampler_LinearClamp, input.uv + float2(-offset.x, +offset.y)).g * 0.125h;
	bloom += SAMPLE_TEXTURE2D(_PostPrepHistoryRT, sampler_LinearClamp, input.uv + float2(+offset.x, -offset.y)).g * 0.125h;
	bloom += SAMPLE_TEXTURE2D(_PostPrepHistoryRT, sampler_LinearClamp, input.uv + float2(+offset.x, +offset.y)).g * 0.125h;
	
	offset = _MainColorRT_TexelSize.xy * (_ScreenParams.y / 1080.0f) * size * 2.0f;
	bloom += BloomValue(SAMPLE_TEXTURE2D(_MainColorRT, sampler_PointClamp, input.uv).rgb, threshold) * 0.1h;
	bloom += BloomValue(SAMPLE_TEXTURE2D(_MainColorRT, sampler_PointClamp, input.uv + float2(+offset.x, 0.0f)).rgb, threshold) * 0.1h;
	bloom += BloomValue(SAMPLE_TEXTURE2D(_MainColorRT, sampler_PointClamp, input.uv + float2(-offset.x, 0.0f)).rgb, threshold) * 0.1h;
	bloom += BloomValue(SAMPLE_TEXTURE2D(_MainColorRT, sampler_PointClamp, input.uv + float2(0.0h, +offset.y)).rgb, threshold) * 0.1h;
	bloom += BloomValue(SAMPLE_TEXTURE2D(_MainColorRT, sampler_PointClamp, input.uv + float2(0.0h, -offset.y)).rgb, threshold) * 0.1h;
	
	output.g = bloom;
	
	return output;
}

half4 PostProcessEffectFragment(Varyings input) : SV_Target
{
	half4 output = 0;

	// Volumetric lights
	float4 fragmentSample = SAMPLE_TEXTURE2D(_MainFragmentRT, sampler_PointClamp, input.uv);
	float distanceEstimate = fragmentSample.w;
	float3 V = fragmentSample.xyz;
	PostFragmentData fragmentData = CreatePostFragmentData(_CameraWS, V, distanceEstimate, input.uv);

	half3 volumetricRealtimeLight = AccumulateVolumetricRealtimeLight(fragmentData);
	half volumetricSunAmount = SAMPLE_TEXTURE2D(_PostPrepCurrentRT, sampler_PointClamp, input.uv).r;
	half3 volumetricSunLight = _SunColor.rgb * _SunColor.a * volumetricSunAmount * _AtmosphereFogColor.a;
	
	output.rgb = volumetricRealtimeLight + volumetricSunLight;
	
	// Bloom
	half bloom = 0.0h;
	half intensity = _PostProcessParams.y;
	half size = _PostProcessParams.w;
	if (intensity * size <= epsilonHalf)
		return output;
	
	float2 offset = _PostEffectRT_TexelSize.xy * (_ScreenParams.y / 1080.0f) * size;
	bloom += SAMPLE_TEXTURE2D(_PostPrepCurrentRT, sampler_LinearClamp, input.uv + float2(-offset.x, -offset.y)).g;
	bloom += SAMPLE_TEXTURE2D(_PostPrepCurrentRT, sampler_LinearClamp, input.uv + float2(-offset.x, +offset.y)).g;
	bloom += SAMPLE_TEXTURE2D(_PostPrepCurrentRT, sampler_LinearClamp, input.uv + float2(+offset.x, -offset.y)).g;
	bloom += SAMPLE_TEXTURE2D(_PostPrepCurrentRT, sampler_LinearClamp, input.uv + float2(+offset.x, +offset.y)).g;
	bloom *= 0.25h;
	
	output.a = bloom;
	
	return output;
}

half4 PostProcessCombiningFragment(Varyings input) : SV_Target
{
	half4 output = 0;

	float2 sampleUV = LensDistortUV(input.uv);
	half3 mainColor = SAMPLE_TEXTURE2D(_MainColorRT, sampler_PointClamp, sampleUV).rgb;
	half4 postEffect = SAMPLE_TEXTURE2D(_PostEffectRT, sampler_LinearClamp, sampleUV);

	output.rgb = mainColor + postEffect.rgb + postEffect.a * _PostProcessParams.y;
	output.a = 1.0h;

	return output;
}

#endif // FRP_POST_PROCESS_PASS_INCLUDED
