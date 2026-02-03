using System;
using System.Reflection;
using UnityEditor;
using UnityEngine;

namespace Pipeline.EditorUtilities
{
	/// <summary>
	/// A static helper class providing getter methods for Unity's serialized properties.
	/// </summary>
	public static class InspectorNameHelper
	{
		/// <summary>
		/// Retrieves a label for a given serialized property.
		/// </summary>
		public static GUIContent GetLabel(SerializedProperty property)
		{
			var field = GetFieldInfo(property.serializedObject.targetObject.GetType(), property.name);
			var attribute = field?.GetCustomAttribute<InspectorNameAttribute>();
			return attribute != null ? new GUIContent(attribute.displayName) : null;
		}

		private static FieldInfo GetFieldInfo(Type type, string fieldName)
		{
			while (type != null)
			{
				var field = type.GetField(fieldName, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
				if (field != null)
					return field;
				type = type.BaseType;
			}

			return null;
		}
	}
}