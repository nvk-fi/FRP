Shader "Skybox/FRP"
{
	Properties
	{
		[Header(Skybox)]
		[Space(10)]
		[NoScaleOffset][MainTexture] _BaseMap("Texture", 2D) = "white" {}
		_BaseMap_Rotation("Rotation", Range(0, 360)) = 0
	}
	
	SubShader
	{
		Pass
		{
			Name "Skybox"
			Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
			
			ZWrite Off
			Cull Off
			Blend 1 One Zero

			HLSLPROGRAM
			#pragma target 4.5
			
			#pragma vertex SkyboxVertex
			#pragma fragment SkyboxFragment

			#include "SkyboxPass.hlsl"
			ENDHLSL
		}
	}
}