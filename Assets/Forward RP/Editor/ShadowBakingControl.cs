using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Forward_RP.Editor
{
	/// <summary>
	/// Controls the shadow baking configurations.
	/// </summary>
	[InitializeOnLoad]
	public static class ShadowBakingControl
	{
		private static bool _active;
		private static readonly Dictionary<Renderer, ShadowCastingMode> OriginalStates = new();
		private static readonly int ZWrite = Shader.PropertyToID("_ZWrite");

		static ShadowBakingControl()
		{
			Lightmapping.bakeStarted += OnBakeStarted;
			Lightmapping.bakeCompleted += OnBakeCompleted;
		}

		private static void OnBakeStarted()
		{
			if (_active) return;
			_active = true;
			OriginalStates.Clear();
			
			// Stop transparent meshes from casting shadows.
			var renderers = Object.FindObjectsByType<Renderer>(FindObjectsSortMode.None);
			foreach (var renderer in renderers)
			{
				if (!renderer || !renderer.gameObject.activeInHierarchy) continue;
				
				var giFlags = GameObjectUtility.GetStaticEditorFlags(renderer.gameObject);
				var contributesGI = (giFlags & StaticEditorFlags.ContributeGI) != 0;
				if (!contributesGI) continue;

				// TODO: Some other way to check if this should cast shadows?
				if (!RendererHasZWriteOff(renderer)) continue;
				
				OriginalStates[renderer] = renderer.shadowCastingMode;
				renderer.shadowCastingMode = ShadowCastingMode.Off;
				EditorUtility.SetDirty(renderer);
			}
		}

		private static void OnBakeCompleted()
		{
			if (!_active) return;
			
			// Return the original shadow casting modes.
			foreach (var pair in OriginalStates)
			{
				if (!pair.Key) continue;
				pair.Key.shadowCastingMode = pair.Value;
				EditorUtility.SetDirty(pair.Key);
			}

			OriginalStates.Clear();
			_active = false;
		}

		private static bool RendererHasZWriteOff(Renderer renderer)
		{
			var materials = renderer.sharedMaterials;
			foreach (var material in materials)
			{
				if (!material) continue;
				if (material.HasProperty(ZWrite) && material.GetFloat(ZWrite) < 0.5f) 
					return true;
			}

			return false;
		}
	}
}