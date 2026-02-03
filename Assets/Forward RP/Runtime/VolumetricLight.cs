using UnityEngine;

namespace Pipeline
{
	[RequireComponent(typeof(Light)), RequireComponent(typeof(Transform))]
	public class VolumetricLight : MonoBehaviour
	{
		[SerializeField, Range(0f, 1f)] private float density = 0.5f;
		public float Density => density;
		[SerializeField] private bool glow;
		public bool Glow => glow;
		
		private Transform _transform;
		public Transform Transform => _transform ??= GetComponent<Transform>();
		private Light _light;
		public Light Light => _light ??= GetComponent<Light>();

		private void OnEnable()
		{
			UpdateBoundingSphereOverrideForSpotlight(true);
			SyncVolumetricDataToLight(true);
		}

		private void OnDisable()
		{
			SyncVolumetricDataToLight(false);
		}

		private void OnValidate()
		{
			if (enabled)
			{
				UpdateBoundingSphereOverrideForSpotlight(true);
				SyncVolumetricDataToLight(true);
			}
			else
			{
				SyncVolumetricDataToLight(false);
			}
		}

		private void LateUpdate()
		{
			UpdateBoundingSphereOverrideForSpotlight(false);
		}

		/// <summary>
		/// Prevent the volumetric spotlights being culled too early.
		/// </summary>
		private void UpdateBoundingSphereOverrideForSpotlight(bool force)
		{
			if (Light.type != LightType.Spot) return;

			if (force || !Mathf.Approximately(Light.range, Light.boundingSphereOverride.w))
			{
				Light.useBoundingSphereOverride = true;
				Light.boundingSphereOverride = new Vector4
				(
					Light.boundingSphereOverride.x, 
					Light.boundingSphereOverride.y, 
					Light.boundingSphereOverride.z, 
					Light.range
				);
			}
		}

		/// <summary>
		/// A hack to store density value within the attached Light component's unused properties.
		/// </summary>
		private void SyncVolumetricDataToLight(bool enable)
		{
			if (enable)
			{
				Light.cookieSize = density * density;
				Light.innerSpotAngle = glow ? 1f : 0f;
			}
			else
			{
				Light.cookieSize = 0f;
				Light.innerSpotAngle = 0f;
			}
		}
	}
}