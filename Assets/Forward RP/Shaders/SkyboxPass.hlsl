#ifndef FRP_SKYBOX_PASS_INCLUDED
#define FRP_SKYBOX_PASS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Input.hlsl"
#include "../ShaderLibrary/Transform.hlsl"
#include "../ShaderLibrary/Fog.hlsl"

CBUFFER_START(UnityPerMaterial)
	half4 _BaseMap_TexelSize;
	half _BaseMap_Rotation;
CBUFFER_END

TEXTURE2D(_BaseMap);

float2 ComputeSkyboxUV(float3 directionWS)
{
	float longitude = atan2(directionWS.z, directionWS.x);
	float latitude = asin(saturate(directionWS.y));
	float u = longitude * (0.5f * inversePiFloat) + 0.5f + _BaseMap_Rotation * (1.0f / 360.0f);
	float v = latitude * inversePiFloat + 0.5f;
	float2 uv = float2(frac(u), saturate(v));
	
	return uv;
}

struct Attributes
{
	float4 positionOS : POSITION;

	float3 normalOS : NORMAL;
	half4 tangentOS : TANGENT;
};

struct Varyings
{
	float4 positionCS : SV_POSITION;
	float3 positionWS : TEXCOORD0;

	half3 tangentWS : TEXCOORD1;
	half3 bitangentWS: TEXCOORD2;
	float3 normalWS : TEXCOORD3;
};

struct Output
{
	half4 color : SV_TARGET0;
	float4 fragment : SV_TARGET1; // XYZ = V, W = Distance
};

Varyings SkyboxVertex(Attributes input)
{
	Varyings output = (Varyings)0;

	// Position
	output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
	output.positionWS = TransformObjectToWorld(input.positionOS.xyz);

	// TBN
	output.normalWS = TransformObjectToWorldNormal(input.normalOS);
	output.tangentWS = TransformObjectToWorldDirection(input.tangentOS.xyz);
	output.bitangentWS = FastSafeNormalize(cross(output.normalWS, output.tangentWS) * input.tangentOS.w);

	return output;
}

Output SkyboxFragment(Varyings input) : SV_TARGET
{
	Output output = (Output)0;
	
	float3 skyDirection = FastSafeNormalize(input.positionWS - _CameraWS.xyz);
	float2 uv = ComputeSkyboxUV(skyDirection);
	half3 sample = Tonemap(SAMPLE_TEXTURE2D(_BaseMap, sampler_PointClamp, uv).rgb);
	output.color = half4(sample, 1.0h);
			
	// Height fog		
	float fogHeightFactor = FogHeightFactor(skyDirection, _AtmosphereParams.z);
	output.color.rgb = lerp(output.color.rgb, _AtmosphereFogColor.rgb, fogHeightFactor);
	
	float travelDistance = _SunParams.w;
	output.fragment = float4(-skyDirection, travelDistance);
	
	return output;
}

#endif // FRP_SKYBOX_PASS_INCLUDED
