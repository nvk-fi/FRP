#ifndef FRP_INPUT_INCLUDED
#define FRP_INPUT_INCLUDED

CBUFFER_START(UnityPerDraw)
	float4x4 unity_ObjectToWorld;
	float4x4 unity_WorldToObject;
CBUFFER_END

CBUFFER_START(UnityPerCamera)
	float3 _CameraWS;					// Camera world position
	float4x4 unity_MatrixV;				// View matrix
	float4x4 unity_MatrixVP;			// View-Projection matrix
	float4x4 unity_MatrixInvV;			// Inverse view matrix
	float4x4 _MatrixInvP;				// Inverse projection matrix
	float4x4 glstate_matrix_projection;	// View to HClip
	float _TanHalfFov;					// Tangent of half the field of view
	float4 _ProjectionParams;			// X = 1 or -1 projection flip, Y = Near plane, Z = Far plane, W = 1/Far plane
	float4 _ScreenParams;				// X = Width, Y = Height, Z = 1+1/Width, W = 1+1/Height
	float4 _PostProcessParams;			// X = LensDistortionStrength, Y = BloomIntensity, Z = BloomThreshold, W = BloomSize
CBUFFER_END

CBUFFER_START(UnityPerFrame)
	float4 _Time;						// X = Time/20, Y = Time, Z = Time*2, W = Time*3
	half2 _MipParams;					// X = MipBias, Y = ReflectionDistanceScale
	half3 _AtmosphereLightColor;		// RGB = Colour
	half4 _AtmosphereFogColor;			// RGB = Colour, A = VolumetricThickness
	half4 _AtmosphereParams;			// X = FogNear, Y = FogFar, Z = FogHeight, W = SunAtmosphereBloomExponent
	half3 _LightProbeParams;			// X = L0Intensity, Y = Desaturation, Z = Multiplier

	half4 _SunParams;					// X = ShadowBias, Y = GrazingBias, Z = VolumetricSteps, W = MaxDistance
	float4x4 _SunVP;					// Shadow's view projection using OpenGL depth.
	half3 _SunDirection;				// XYZ = Normalised sun backwards direction
	half4 _SunColor;					// RGB = Colour, A = Intensity
	half4 _SunRatio;					// X = Static, Y = 1-Static, Z = Dynamic, W = 1-Dynamic
CBUFFER_END

//CBUFFER_START(UnityPerScene)
//CBUFFER_END

CBUFFER_START(UnityLightmaps)
	half4 unity_LightmapST;
	half4 unity_DynamicLightmapST;
CBUFFER_END

static const int MAX_REALTIME_LIGHTS = 32;
CBUFFER_START(UnityLighting)
	int _RealtimeLightCount;
	float4 _RealtimeLightPositions[MAX_REALTIME_LIGHTS];	// XYZ = Positions, W = RangeSquared
	half4 _RealtimeLightDirections[MAX_REALTIME_LIGHTS];	// XYZ = Directions, W = SpotAngle * VolumetricGlow (-1 = Disabled, 1 = Enabled)
	half4 _RealtimeLightColors[MAX_REALTIME_LIGHTS];		// RGB = Colours * Intensity, A = LightType (-1 = Spot, 0 = Directional, 1 = Point) * (1 + VolumetricDensity [0..1))

	half4 unity_SHAr;
	half4 unity_SHAg;
	half4 unity_SHAb;
	half4 unity_SHBr;
	half4 unity_SHBg;
	half4 unity_SHBb;
	half4 unity_SHC;
CBUFFER_END

CBUFFER_START(UnityReflectionProbes)
	float4 unity_SpecCube0_BoxMax;
	float4 unity_SpecCube0_BoxMin;
	float4 unity_SpecCube0_ProbePosition;
	half4  unity_SpecCube0_HDR;
CBUFFER_END

#endif // FRP_INPUT_INCLUDED
