using UnityEngine;
using Pipeline;

public class ShadowFrustumVisualizer : MonoBehaviour
{
	[SerializeField] private FRPSettings frpSettings;
	
    void OnDrawGizmos()
	{
		var sun = RenderSettings.sun;
		var cam = Camera.current;
		if (sun == null || cam == null) return;
		
		sun.transform.position = cam.transform.position - sun.transform.forward * frpSettings.sunShadowMapPositionDistance;
				
		var lookMatrix = Matrix4x4.LookAt(sun.transform.position, sun.transform.position + sun.transform.forward, sun.transform.up);
		var scaleMatrix = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, new Vector3(1, 1, -1));
		var viewMatrix = scaleMatrix * lookMatrix.inverse;
				
		var halfWidth = frpSettings.sunShadowMapFrustumWidth * 0.5f;
		var farPlane = frpSettings.sunShadowMapFrustumFar;
		var projectionMatrix = Matrix4x4.Ortho(-halfWidth, halfWidth, -halfWidth, halfWidth, 0, farPlane);

		var vpMatrix = projectionMatrix * viewMatrix;
		
		Gizmos.color = Color.red;
		Gizmos.matrix = vpMatrix.inverse;
		
		Gizmos.DrawWireCube(Vector3.zero, Vector3.one * 2);
	}
}