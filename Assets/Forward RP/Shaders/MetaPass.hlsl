#ifndef FRP_META_PASS_INCLUDED
#define FRP_META_PASS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Transform.hlsl"
#include "../ShaderLibrary/BaseMap.hlsl"

#ifndef EDITOR_VISUALIZATION
#include "../ShaderLibrary/Input.hlsl"

CBUFFER_START(UnityPerMaterial)
	float4 _BaseColor;
	float4 _BaseMap_ST;
CBUFFER_END

CBUFFER_START(UnityMetaPass)
	bool2 unity_MetaVertexControl;		// X = Use lightmap, Y = Use dynamic lightmap
	bool2 unity_MetaFragmentControl;	// X = Return Albedo, Y = Return Normal
	float unity_OneOverOutputBoost;		// Albedo boost
	float unity_MaxOutputValue;			// Clamp for albedo boost
CBUFFER_END

struct Attributes
{
	float3 positionOS : POSITION;
	float3 normalOS : NORMAL;
	float2 baseUV : TEXCOORD0;
	float2 lightmapUV : TEXCOORD1;
};

struct Varyings
{
	float4 positionCS : SV_POSITION;
	float2 baseUV : TEXCOORD0;
};

Varyings MetaVertex(Attributes input)
{
	Varyings output;
	
	output.baseUV = input.baseUV * _BaseMap_ST.xy + _BaseMap_ST.zw;
	
	float3 vertex = input.positionOS;
	if (unity_MetaVertexControl.x)
	{
		vertex.xy = input.lightmapUV * unity_LightmapST.xy + unity_LightmapST.zw;
		vertex.z = vertex.z > 0 ? REAL_MIN : 0.0f; // Prevents OpenGL driver optimisation breaking rasterisation.
	}
	output.positionCS = TransformWorldToHClip(vertex);
	
	return output;
}

float4 MetaFragment(Varyings input) : SV_Target
{
	// Albedo
	if (unity_MetaFragmentControl.x)
	{
		float4 albedo = float4(SampleAlbedo(input.baseUV, _BaseColor).rgb, 1);

		// Apply Unity's albedo boost.
		albedo.rgb = clamp(pow(abs(albedo.rgb), saturate(unity_OneOverOutputBoost)), 0, unity_MaxOutputValue);

		return albedo;
	}
	return 0;
}


#else // EDITOR_VISUALIZATION

// Using Unity's shader libraries instead.
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/MetaPass.hlsl"

CBUFFER_START(UnityPerMaterial)
	half4 _BaseColor;
	half4 _BaseMap_ST;
CBUFFER_END

struct Attributes
{
	float3 positionOS : POSITION;
	float3 normalOS : NORMAL;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float2 uv2 : TEXCOORD2;
};

struct Varyings
{
	float4 positionCS : SV_POSITION;
	float2 baseUV : TEXCOORD0;
	float2 VizUV : TEXCOORD1;
	float4 LightCoord : TEXCOORD2;
};

Varyings MetaVertex(Attributes input)
{
	Varyings output;
	output.baseUV = input.uv0 * _BaseMap_ST.xy + _BaseMap_ST.zw;
	
	float2 vizUV = 0;
	float4 lightCoord = 0;
	UnityEditorVizData(input.positionOS, input.uv0, input.uv1, input.uv2, vizUV, lightCoord);
	output.VizUV = vizUV;
	output.LightCoord = lightCoord;
	
	output.positionCS = UnityMetaVertexPosition(input.positionOS, input.uv1, input.uv2);
	
	return output;
}

half4 MetaFragment(Varyings input) : SV_Target
{
	UnityMetaInput metaInput = (UnityMetaInput)0;
	metaInput.Albedo = SampleAlbedo(input.baseUV, _BaseColor);
	metaInput.Emission = 0;
	metaInput.VizUV = input.VizUV;
	metaInput.LightCoord = input.LightCoord;

	return UnityMetaFragment(metaInput);
}

#endif // EDITOR_VISUALIZATION

#endif // FRP_META_PASS_INCLUDED
