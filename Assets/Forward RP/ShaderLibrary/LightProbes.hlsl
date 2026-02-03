#ifndef FRP_LIGHTPROBES_INCLUDED
#define FRP_LIGHTPROBES_INCLUDED

#include "Input.hlsl"
#include "NNARMap.hlsl"

// Sample the light probes with NNAR's normal mapping and ambient occlusion applied.
half3 SampleSphericalHarmonics(NNAR nnar)
{
	half3 normalWS = nnar.bumpedNormalWSNonLinear;
	
	// Sample SHs with lowered L0 and then multiply the output with a higher value to get a nice contrast.
	half l0Value = _LightProbeParams.x;
	half desaturate = _LightProbeParams.y;
	half multiplier = _LightProbeParams.z;
	
	half4 L0L1Basis = half4(normalWS, l0Value);
	half4 L2Basis = half4(
		normalWS.x * normalWS.y,
		normalWS.y * normalWS.z,
		normalWS.z * normalWS.x,
		normalWS.x * normalWS.x - normalWS.y * normalWS.y
	);

	half3 output = half3(
		dot(unity_SHAr, L0L1Basis),
		dot(unity_SHAg, L0L1Basis),
		dot(unity_SHAb, L0L1Basis)
	);
	output += half3(
		dot(unity_SHBr, L2Basis),
		dot(unity_SHBg, L2Basis),
		dot(unity_SHBb, L2Basis)
	);
	output += unity_SHC.rgb * (3.0h * normalWS.z * normalWS.z - 1.0h);
	
	output = lerp(output, FastLinearLuminosity(output), desaturate);
	output = max(0.0h, output) * multiplier;
	output *= nnar.ambientOcclusion;
	
	return output;
}

#endif // FRP_LIGHTPROBES_INCLUDED