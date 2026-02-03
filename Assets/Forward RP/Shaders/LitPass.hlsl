#ifndef FRP_LIT_PASS_INCLUDED
#define FRP_LIT_PASS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Input.hlsl"
#include "../ShaderLibrary/Transform.hlsl"
#include "../ShaderLibrary/FragmentData.hlsl"
#include "../ShaderLibrary/TBN.hlsl"
#include "../ShaderLibrary/DisplacementMap.hlsl"
#include "../ShaderLibrary/BaseMap.hlsl"
#include "../ShaderLibrary/NNARMap.hlsl"
#include "../ShaderLibrary/RealtimeLight.hlsl"
#include "../ShaderLibrary/LightProbes.hlsl"
#include "../ShaderLibrary/LightMap.hlsl"
#include "../ShaderLibrary/SunLight.hlsl"
#include "../ShaderLibrary/ReflectionProbes.hlsl"
#include "../ShaderLibrary/Fog.hlsl"

CBUFFER_START(UnityPerMaterial)
	half4 _BaseColor;
	half4 _BaseMap_ST;
	half4 _BaseMap_TexelSize;

	half _NormalMapIntensity;
	half _AmbientOcclusionMapIntensity;
	half _RoughnessMapIntensity;

	half _DisplacementScale;
	half _DisplacementOffset;
	half _DisplacementGrazingAngleStrength;

	half _ReflectionStrength;
	half _ReflectionMetalness;
	half _ReflectionBlur;

	half _ZWrite;
CBUFFER_END

struct Attributes
{
	float4 positionOS : POSITION;

	float3 normalOS : NORMAL;
	half4 tangentOS : TANGENT;

	half2 baseUV : TEXCOORD0;
	half2 lightmapUV : TEXCOORD1;
};

struct Varyings
{
	float4 positionCS : SV_POSITION;
	float3 positionWS : TEXCOORD0;

	half3 tangentWS : TEXCOORD1;
	half3 bitangentWS: TEXCOORD2;
	float3 normalWS : TEXCOORD3;

	half2 baseUV : TEXCOORD4;
	half2 lightmapUV : TEXCOORD5;
};

struct Output
{
	half4 color : SV_TARGET0;
	float4 fragment : SV_TARGET1; // XYZ = V, W = Distance
};

Varyings LitVertex(Attributes input)
{
	Varyings output = (Varyings)0;

	// Position
	output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
	output.positionWS = TransformObjectToWorld(input.positionOS.xyz);

	// TBN
	output.normalWS = TransformObjectToWorldNormal(input.normalOS);
	output.tangentWS = TransformObjectToWorldDirection(input.tangentOS.xyz);
	output.bitangentWS = FastSafeNormalize(cross(output.normalWS, output.tangentWS) * input.tangentOS.w);

	// UVs
	output.baseUV = input.baseUV * _BaseMap_ST.xy + _BaseMap_ST.zw;
	#ifdef LIGHTMAP_ON
	output.lightmapUV = input.lightmapUV * unity_LightmapST.xy + unity_LightmapST.zw;
	#endif

	return output;
}

Output LitFragment(Varyings input) : SV_TARGET
{
	Output output = (Output)0;
	TBN tbn = CreateTBN(input.tangentWS, input.bitangentWS, input.normalWS);
	LitFragmentData fragment;
	if (_DisplacementScale > epsilonHalf)
	{
		half displacedHeight = SampleDisplacementMap(input.baseUV, _DisplacementScale, _DisplacementOffset);
		fragment = CreateLitFragmentData(input.positionWS, _CameraWS, tbn, displacedHeight);
		input.baseUV = ApplyParallaxUV(input.baseUV, fragment, _DisplacementGrazingAngleStrength);	
	}
	else
	{
		fragment = CreateLitFragmentData(input.positionWS, _CameraWS, tbn, 0.0h);
	}
	half mipLevel = MipLevel(input.baseUV * _BaseMap_TexelSize.zw, _MipParams.x);

	// Albedo
	half4 albedo = SampleAlbedo(input.baseUV, _BaseColor, mipLevel);
	output.color = albedo;

	// Normal-AmbientOcclusion-Roughness
	half3 nnarIntensities = half3(_NormalMapIntensity, _AmbientOcclusionMapIntensity, _RoughnessMapIntensity);
	NNAR nnar = SampleNNARMap(input.baseUV, tbn, nnarIntensities, mipLevel);

	// Reflections
	if (_ReflectionStrength > epsilonHalf)
	{
		half3 reflectionColor = SampleReflectionProbes(fragment, nnar, _ReflectionBlur, mipLevel, _MipParams.y);
		reflectionColor = ApplyReflectionMetalness(reflectionColor, albedo.rgb, _ReflectionMetalness);
		output.color = ApplyReflections(output.color, reflectionColor, _ReflectionStrength);
	}

	// Lighting	
	half3 lighting = 0;

	half3 ambientLight = _AtmosphereLightColor.rgb;
	lighting += ambientLight;
	
	half3 realtimeLight = AccumulateSurfaceRealtimeLight(fragment, nnar);
	lighting += realtimeLight;
	
	SunData sunData = CreateSunData(fragment, nnar, _SunDirection);
	ShadowMapParams sunShadowMapParams = CreateShadowMapParams(sunData.NdotL, _SunParams.x, _SunParams.y, _ZWrite);
	half sunShadowMap = SampleSunShadowMap(fragment, sunShadowMapParams);
	half sunBlendRatio = ShadowMapDistanceBlendRatio(fragment.distanceSquared, _SunParams.w);

	#ifdef LIGHTMAP_ON
	half3 lightmap = SampleLightmap(input.lightmapUV, nnar) * _SunRatio.y;
	lighting += lightmap;
	
	half shadowMask = SampleShadowMask(input.lightmapUV);
	half sunDiffuseNear = shadowMask * sunShadowMap;
	half sunDiffuseFar = shadowMask;
	half sunSpecular = SpecularTerm(sunData.N2dotH, nnar.roughness, nnar.shine);
	half3 sunLight = SunLight(_SunColor.rgba, sunDiffuseNear, sunDiffuseFar, sunSpecular, sunBlendRatio) * _SunRatio.x;
	lighting += sunLight;
	
	#else
	half3 lightProbes = SampleSphericalHarmonics(nnar) * _SunRatio.w;
	lighting += lightProbes;

	half lightProbeLuminosity = FastLinearLuminosity(lightProbes);
	half sunDiffuseNear = sunShadowMap;
	half sunDiffuseFar = lightProbeLuminosity * sunShadowMapParams.grazingValue;
	half sunSpecular = SpecularTerm(sunData.N2dotH, nnar.roughness, nnar.shine);
	half3 sunLight = SunLight(_SunColor.rgba, sunDiffuseNear, sunDiffuseFar, sunSpecular, sunBlendRatio) * _SunRatio.z;
	lighting += sunLight;
	
	#endif
	output.color.rgb *= lighting;
	
	// Distance Fog	with sun's bloom at the distance.
	half fogDistanceFactor = FogDistanceFactor(fragment.distanceEstimate, _AtmosphereParams.x, _AtmosphereParams.y);
	half fogSunBloomFactor = FogSunBloomFactor(-fragment.V, _SunDirection, _AtmosphereParams.w);
	half3 fogColor = lerp(_AtmosphereFogColor.rgb, _SunColor.rgb, fogSunBloomFactor * fogDistanceFactor);
	output.color.rgb = lerp(output.color.rgb, fogColor.rgb, fogDistanceFactor);
	
	output.fragment = float4(fragment.V.rgb, fragment.distanceEstimate);
	
	return output;
}

#endif // FRP_LIT_PASS_INCLUDED
