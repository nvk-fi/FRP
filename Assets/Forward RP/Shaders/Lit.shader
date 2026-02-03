Shader "FRP/Lit"
{
	Properties
	{
		[Header(Albedo)]
		[Space(10)]
		[HDR][MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
		[MainTexture] _BaseMap("Base Texture", 2D) = "white" {}
		[Space(10)]
		
		[Space(10)]
		[Header(NNAR)]
		[Space(10)]
		_NormalMapIntensity("Normal Map Intensity", Range(0, 2)) = 0
		_AmbientOcclusionMapIntensity("Ambient Occlusion Map Intensity", Range(0, 2)) = 0
		_RoughnessMapIntensity("Roughness Map Intensity", Range(0, 2)) = 0
		[NoScaleOffset] _NNARMap("NNAR Texture", 2D) = "bump" {} // "bump" = (0.5, 0.5, 1, 1)
		
		[Header(Displacement)]
		[Space(10)]
		_DisplacementScale("Displacement Scale", Range(0, 1)) = 0
		_DisplacementOffset("Displacement Offset", Range(0, 1)) = 0
		_DisplacementGrazingAngleStrength("Displacement Grazing Angle Strength", Range(0, 1)) = 0
		[NoScaleOffset] _DisplacementMap("Displacement Texture", 2D) = "transparent" {}
		
		[Header(Reflections)]
		[Space(10)]
		_ReflectionStrength("Reflection Strength", Range(0, 1)) = 0
		_ReflectionMetalness("Reflection Metalness", Range(0, 1)) = 0
		_ReflectionBlur("Reflection Blur", Range(0, 1)) = 0
		
		[Space(40)]
		[Header(Rendering)]
		[Space(10)]
		[Enum(UnityEngine.Rendering.BlendMode)] _SourceBlend("Source Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DestinationBlend("Destination Blend", Float) = 0
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
		[Enum(Off, 0, On, 1)] _ZWrite("Z Write", Float) = 1
	}
	SubShader
	{
		Pass
		{
			Name "Lit"
			Tags { "LightMode" = "FRPLit" }

			Blend 0 [_SourceBlend] [_DestinationBlend]
			Blend 1 One Zero // No blending on the fragment RT.
			ZWrite [_ZWrite]
			ZTest LEqual
			Cull [_Cull]

			HLSLPROGRAM
			#pragma target 4.5
			#pragma multi_compile _ LIGHTMAP_ON

			#pragma vertex LitVertex
			#pragma fragment LitFragment

			#include "LitPass.hlsl"
			ENDHLSL
		}

		Pass
		{
		    Name "Depth"
		    Tags { "LightMode" = "FRPDepth" }
		
		    ZWrite On
		    ZTest LEqual
		    Cull Back
		    ColorMask R
		
		    HLSLPROGRAM
		    #pragma target 2.0

		    #pragma vertex DepthVertex
		    #pragma fragment DepthFragment
		
		    #include "DepthPass.hlsl"
		    ENDHLSL
		}

		Pass
		{
			Name "Meta"
			Tags { "LightMode" = "Meta" }
			
			ZWrite [_ZWrite]
			Cull Off

			HLSLPROGRAM
			#pragma target 2.0
			#pragma shader_feature EDITOR_VISUALIZATION

			#pragma vertex MetaVertex
			#pragma fragment MetaFragment

			#include "MetaPass.hlsl"
			ENDHLSL
		}
	}
}