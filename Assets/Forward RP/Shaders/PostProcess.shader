Shader "FRP/PostProcess"
{
	SubShader
	{
		Tags { "RenderType" = "Opaque" }

		Pass
		{
			Name "PostProcessPrepPass"

			Cull Off
			ZWrite Off
			ZTest Always
			Blend One Zero

			HLSLPROGRAM
			#pragma target 4.5
			#pragma vertex PostProcessVertex
			#pragma fragment PostProcessPrepFragment

			#include "PostProcessPass.hlsl"
			ENDHLSL
		}

		Pass
		{
			Name "PostProcessEffectPass"

			Cull Off
			ZWrite Off
			ZTest Always
			Blend One Zero

			HLSLPROGRAM
			#pragma target 4.5
			#pragma vertex PostProcessVertex
			#pragma fragment PostProcessEffectFragment

			#include "PostProcessPass.hlsl"
			ENDHLSL
		}

		Pass
		{
			Name "PostProcessCombiningPass"

			Cull Off
			ZWrite Off
			ZTest Always
			Blend One Zero

			HLSLPROGRAM
			#pragma target 4.5
			#pragma vertex PostProcessVertex
			#pragma fragment PostProcessCombiningFragment

			#include "PostProcessPass.hlsl"
			ENDHLSL
		}
	}
}
