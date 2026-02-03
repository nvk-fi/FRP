#ifndef FRP_TRANSFORM_INCLUDED
#define FRP_TRANSFORM_INCLUDED

#include "Input.hlsl"

float4x4 GetObjectToWorldMatrix()
{
	return unity_ObjectToWorld;
}

float4x4 GetWorldToObjectMatrix()
{
	return unity_WorldToObject;
}

float4x4 GetWorldToViewMatrix()
{
	return unity_MatrixV;
}

float4x4 GetViewToWorldMatrix()
{
	return unity_MatrixInvV;
}

float4x4 GetWorldToHClipMatrix()
{
	return unity_MatrixVP;
}

float4x4 GetViewToHClipMatrix()
{
	return glstate_matrix_projection;
}


float3 TransformObjectToWorld(float3 positionOS)
{
	return mul(GetObjectToWorldMatrix(), float4(positionOS, 1.0)).xyz;
}

float3 TransformWorldToObject(float3 positionWS)
{
	return mul(GetWorldToObjectMatrix(), float4(positionWS, 1.0)).xyz;
}

float4 TransformWorldToHClip(float3 positionWS)
{
	return mul(GetWorldToHClipMatrix(), float4(positionWS, 1.0));
}

float4 TransformObjectToHClip(float3 positionOS)
{
	float3 worldPos = TransformObjectToWorld(positionOS);
	return TransformWorldToHClip(worldPos);
}

float3 TransformObjectToWorldNormal(float3 normalOS)
{
	return FastSafeNormalize(mul(normalOS, (float3x3)GetWorldToObjectMatrix()));
}

float3 TransformObjectToWorldDirection(float3 directionOS)
{
	return FastSafeNormalize(mul((float3x3)GetObjectToWorldMatrix(), directionOS));
}

// Transforms a position from clip space to screen space.
inline half4 ComputePositionSS(half4 positionCS)
{
	half4 output = positionCS * 0.5h;

	// Indicates the shader should account for the display orientation before any transform to screen space.
	#ifdef UNITY_PRETRANSFORM_TO_DISPLAY_ORIENTATION
	switch (UNITY_DISPLAY_ORIENTATION_PRETRANSFORM)
	{
	default: 
		break;
	case UNITY_DISPLAY_ORIENTATION_PRETRANSFORM_90: 
		output.xy = half2(-output.y, output.x);
		break;
	case UNITY_DISPLAY_ORIENTATION_PRETRANSFORM_180: 
		output.xy = -output.xy;
		break;
	case UNITY_DISPLAY_ORIENTATION_PRETRANSFORM_270: 
		output.xy = half2(output.y, -output.x);
		break;
	}
	#endif

	output.xy = float2(output.x, output.y * _ProjectionParams.x) + output.w;
	output.zw = positionCS.zw;

	return output;
}

#endif // FRP_TRANSFORM_INCLUDED
