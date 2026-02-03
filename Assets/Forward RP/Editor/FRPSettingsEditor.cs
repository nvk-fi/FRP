using UnityEditor;
using UnityEngine;
using Pipeline;
using Pipeline.EditorUtilities;

/// <summary>
/// Custom editor for the FRPSettings asset.
/// </summary>
[CustomEditor(typeof(FRPSettings))]
public class FRPSettingsEditor : Editor
{
	public override void OnInspectorGUI()
	{
		serializedObject.Update();

		// Draw the properties with custom labels.
		var property = serializedObject.GetIterator();
		var enterChildren = true;
		while (property.NextVisible(enterChildren))
		{
			enterChildren = false;
			if (property.name == "m_Script")
			{
				using (new EditorGUI.DisabledScope(true))
					EditorGUILayout.PropertyField(property);
				continue;
			}

			EditorGUILayout.PropertyField(property, InspectorNameHelper.GetLabel(property));
		}

		serializedObject.ApplyModifiedProperties();

		EditorGUILayout.Space(20);

		// Add the Apply button.
		var settings = (FRPSettings)target;
		if (GUILayout.Button("Apply", GUILayout.Width(90), GUILayout.Height(30)))
			settings.Apply();
	}
}
