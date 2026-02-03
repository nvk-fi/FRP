using UnityEditor;
using UnityEngine;

/// <summary>
/// Custom editor for the Unity's Camera component.
/// </summary>
[CustomEditor(typeof(Camera))]
[CanEditMultipleObjects]
public class FRPCameraInspector : Editor
{
	public override void OnInspectorGUI()
	{
		// Draw serialised camera fields without custom foldouts, as they query command buffers and thus throw warnings.
		DrawDefaultInspector();
	}
}