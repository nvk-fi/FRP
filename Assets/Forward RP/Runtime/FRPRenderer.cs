#if UNITY_EDITOR || DEVELOPMENT_BUILD
using UnityEditor;
#endif

using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RendererUtils;

namespace Pipeline
{
	public class FRPRenderer
	{
		private readonly FRPSettings _settings;
		private readonly CommandBuffer _commandBuffer;
		private static ScriptableRenderContext _context;
		private static CullingResults _cullingResults;
		private static Camera _camera;
		private static Camera _mainCamera;
		
		private static RenderTexture _mainColorRT;
		private static RenderTexture _mainFragmentRT;
		private static RenderTexture _postPrepCurrentRT;
		private static RenderTexture _postPrepHistoryRT;
		private static RenderTexture _postEffectRT;
		private static RenderTexture _sunShadowMapRT;
		
		private static readonly RenderTargetIdentifier[] MainMRT = new RenderTargetIdentifier[2];
		private static readonly int MainColorRTID = Shader.PropertyToID("_MainColorRT");
		private static readonly int MainFragmentRTID = Shader.PropertyToID("_MainFragmentRT");
		private static readonly int PostPrepCurrentRTID = Shader.PropertyToID("_PostPrepCurrentRT");
		private static readonly int PostPrepHistoryRTID = Shader.PropertyToID("_PostPrepHistoryRT");
		private static readonly int PostEffectRTID = Shader.PropertyToID("_PostEffectRT");
		private static readonly int SunShadowMapRTID = Shader.PropertyToID("_SunShadowMapRT");

		private static readonly ShaderTagId DepthShaderTagId = new("FRPDepth");
		private static readonly ShaderTagId LitShaderTagId = new("FRPLit");
		private static readonly ShaderTagId[] OpaqueShaderTagIds = { LitShaderTagId };
		private static readonly ShaderTagId[] TransparentShaderTagIds = { LitShaderTagId };

		private static readonly int CameraWSID = Shader.PropertyToID("_CameraWS");
		private static readonly int MipParamsID = Shader.PropertyToID("_MipParams");
		private static readonly int AtmosphereLightColorID = Shader.PropertyToID("_AtmosphereLightColor");
		private static readonly int AtmosphereFogColorID = Shader.PropertyToID("_AtmosphereFogColor");
		private static readonly int AtmosphereParamsID = Shader.PropertyToID("_AtmosphereParams");
		private static readonly int LightProbeParamsID = Shader.PropertyToID("_LightProbeParams");
		private static readonly int PostProcessParamsID = Shader.PropertyToID("_PostProcessParams");

		private const int MaxRealtimeLights = 32; // NOTE: Match the value in the shaders.
		private readonly Vector4[] _realtimeLightPositions = new Vector4[MaxRealtimeLights];
		private readonly Vector4[] _realtimeLightDirections = new Vector4[MaxRealtimeLights];
		private readonly Vector4[] _realtimeLightColors = new Vector4[MaxRealtimeLights];
		private static readonly int RealtimeLightCountBufferID = Shader.PropertyToID("_RealtimeLightCount");
		private static readonly int RealtimeLightPositionBufferID = Shader.PropertyToID("_RealtimeLightPositions");
		private static readonly int RealtimeLightDirectionBufferID = Shader.PropertyToID("_RealtimeLightDirections");
		private static readonly int RealtimeLightColorBufferID = Shader.PropertyToID("_RealtimeLightColors");

		private static readonly int SunParamsID = Shader.PropertyToID("_SunParams");
		private static readonly int SunViewProjectionMatrixID = Shader.PropertyToID("_SunVP");
		private static readonly int SunDirectionID = Shader.PropertyToID("_SunDirection");
		private static readonly int SunColorID = Shader.PropertyToID("_SunColor");
		private static readonly int SunRatioID = Shader.PropertyToID("_SunRatio");
		private static Vector3Int _sunPosition;
		private static Matrix4x4 _sunViewMatrix;
		private static Matrix4x4 _sunProjectionMatrix;
		private static Matrix4x4 _sunViewProjectionMatrix;

		private static readonly int MatrixInvPID = Shader.PropertyToID("_MatrixInvP");
		private static readonly int TanHalfFovID = Shader.PropertyToID("_TanHalfFov");

		private const float MaxAtmosphereThickness = 0.1f;

		public FRPRenderer(FRPSettings settings)
		{
			_commandBuffer = new CommandBuffer();
			_commandBuffer.name = "FRP";
			_settings = settings;

			ApplySettings();
		}

		/// <summary>
		/// Configures rendering settings and initialises the associated command buffer with runtime parameters.
		/// </summary>
		public void ApplySettings()
		{
			GraphicsSettings.useScriptableRenderPipelineBatching = _settings.srpBatchingEnabled;
			
			_commandBuffer.SetGlobalVector(MipParamsID, new Vector4
			(
				_settings.mipBias,
				_settings.mipReflectionDistanceScale,
				0f,
				0f
			));
			_commandBuffer.SetGlobalVector(LightProbeParamsID, new Vector4
			(
				_settings.shL0Intensity,
				_settings.shDesaturation,
				_settings.shMultiplier,
				0f
			));
			var sun = RenderSettings.sun;
			_commandBuffer.SetGlobalVector(SunDirectionID, sun ? -sun.transform.forward : Vector3.up);
			_commandBuffer.SetGlobalVector(SunColorID, !sun ? Color.clear : new Vector4(
				sun.color.r,
				sun.color.g,
				sun.color.b,
				sun.intensity
			));
			var sunShadowMapMaxDistance = _settings.sunShadowMapFrustumWidth * .5f - _settings.sunShadowMapPositionSnapDistance;
			_commandBuffer.SetGlobalVector(SunParamsID, new Vector4
			(
				_settings.sunShadowBias,
				_settings.sunGrazingBias,
				_settings.sunShadowMapVolumetricSteps,
				sunShadowMapMaxDistance
			));
			_commandBuffer.SetGlobalVector(SunRatioID, new Vector4
			(
				_settings.sunShadowMapRatioForStaticObjects,
				1f - _settings.sunShadowMapRatioForStaticObjects,
				_settings.sunShadowMapRatioForDynamicObjects,
				1f - _settings.sunShadowMapRatioForDynamicObjects
			));
			_commandBuffer.SetGlobalVector(AtmosphereLightColorID, new Vector4
			(
				_settings.ambientLightColor.r,
				_settings.ambientLightColor.g,
				_settings.ambientLightColor.b,
				0
			));
			_commandBuffer.SetGlobalVector(AtmosphereFogColorID, new Vector4(
				_settings.fogColor.r,
				_settings.fogColor.g,
				_settings.fogColor.b,
				_settings.atmosphereThickness * _settings.atmosphereThickness * MaxAtmosphereThickness
			));
			_commandBuffer.SetGlobalVector(AtmosphereParamsID, new Vector4
			(
				_settings.fogRange.x,
				_settings.fogRange.y,
				_settings.fogHeight,
				_settings.fogSunBloomExponent
			));
			_commandBuffer.SetGlobalVector(PostProcessParamsID, new Vector4
			(
				_settings.ppfxLensDistortionStrength,
				_settings.ppfxBloomIntensity,
				_settings.ppfxBloomThreshold,
				_settings.ppfxBloomSize
			));
		}

		/// <summary>
		/// Called from the FRP as the very first thing before any rendering.
		/// </summary>
		public static void Awake()
		{
			InitializeMainCamera();
			return;
			
			void InitializeMainCamera()
			{
				_mainCamera = Camera.main;

#if UNITY_EDITOR || DEVELOPMENT_BUILD
				if (Application.isPlaying) return;
				foreach (SceneView sceneView in SceneView.sceneViews)
				{
					if (!sceneView.hasFocus || sceneView.camera.cameraType != CameraType.SceneView) continue;
				
					_mainCamera = sceneView.camera;
					break;
				}
#endif
			}
		}

		/// <summary>
		/// Renders the sun's shadow map from the main camera's location.
		/// </summary>
		public void RenderSunShadowMap(ScriptableRenderContext context)
		{
			_context = context;
			_camera = _mainCamera;
			if (_camera == null) return;
			if (RenderSettings.sun == null) return;

			BeginSample("Sun Shadow Map");
			SetupRenderTarget();
			UpdateSunMatrices();
			DrawSunShadowMap();
			EndSample("Sun Shadow Map");
			Execute();

			_context.Submit();
			return;

			void SetupRenderTarget()
			{
				if (_sunShadowMapRT == null || _sunShadowMapRT.width != _settings.sunShadowMapResolution)
				{
					if (_sunShadowMapRT != null)
						RenderTexture.ReleaseTemporary(_sunShadowMapRT);

					var width = _settings.sunShadowMapResolution;
					var descriptor = new RenderTextureDescriptor(width, width, RenderTextureFormat.RHalf, 16)
					{
						useMipMap = false,
						autoGenerateMips = false,
						sRGB = false
					};
					_sunShadowMapRT = RenderTexture.GetTemporary(descriptor);
				}

				_commandBuffer.SetGlobalTexture(SunShadowMapRTID, _sunShadowMapRT);
				_commandBuffer.SetRenderTarget(_sunShadowMapRT);
				_commandBuffer.ClearRenderTarget(true, true, Color.white);
			}

			void UpdateSunMatrices()
			{
				var sun = RenderSettings.sun;
				var sunPosition = Vector3Int.FloorToInt(_camera.transform.position -
														sun.transform.forward * _settings.sunShadowMapPositionDistance);
				var distanceToLastPositionSquared = (sunPosition - _sunPosition).sqrMagnitude;
				if (distanceToLastPositionSquared < Mathf.Pow(_settings.sunShadowMapPositionSnapDistance, 2)) return;
				_sunPosition = sunPosition;

				// https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Rendering.CommandBuffer.SetViewProjectionMatrices.html
				var lookMatrix = Matrix4x4.LookAt(sunPosition, sunPosition + sun.transform.forward, sun.transform.up);
				var scaleMatrix = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, new Vector3(1, 1, -1));
				_sunViewMatrix = scaleMatrix * lookMatrix.inverse;

				var halfW = _settings.sunShadowMapFrustumWidth * 0.5f;
				var far = _settings.sunShadowMapFrustumFar;
				// Match the width and height instead to prevent limiting vertical shadow distance. 
				//var h = w * Mathf.Abs(Mathf.Sin(sun.transform.eulerAngles.x * Mathf.Deg2Rad));
				_sunProjectionMatrix = Matrix4x4.Ortho(-halfW, halfW, -halfW, halfW, 0, far);
				_sunViewProjectionMatrix = _sunProjectionMatrix * _sunViewMatrix;
				_commandBuffer.SetGlobalMatrix(SunViewProjectionMatrixID, _sunViewProjectionMatrix);
			}

			void DrawSunShadowMap()
			{
				if (!_camera.TryGetCullingParameters(out var cullingParams)) return;

				var cullingPlanes = GeometryUtility.CalculateFrustumPlanes(_sunViewProjectionMatrix);
				for (var i = 0; i < cullingPlanes.Length; i++)
					cullingParams.SetCullingPlane(i, cullingPlanes[i]);
				cullingParams.isOrthographic = true;
				cullingParams.origin = _sunPosition;
				cullingParams.shadowDistance = _settings.sunShadowMapFrustumFar;
				cullingParams.cullingMatrix = _sunViewProjectionMatrix;
				var cullingResults = _context.Cull(ref cullingParams);

				_commandBuffer.SetViewProjectionMatrices(_sunViewMatrix, _sunProjectionMatrix);

				var depthRendererSettings = new RendererListDesc(DepthShaderTagId, cullingResults, _camera)
				{
					renderQueueRange = RenderQueueRange.opaque,
					sortingCriteria = SortingCriteria.None,
					rendererConfiguration = PerObjectData.None
				};
				var depthRendererList = _context.CreateRendererList(depthRendererSettings);
				_commandBuffer.DrawRendererList(depthRendererList);

				_commandBuffer.SetViewProjectionMatrices(_camera.worldToCameraMatrix, _camera.projectionMatrix);
			}
		}

		/// <summary>
		/// Renders the provided camera within the given context, applying culling, lighting setup, and post-processing as needed.
		/// Handles primary and secondary camera rendering, as well as editor-specific passes.
		/// </summary>
		public void RenderCamera(ScriptableRenderContext context, Camera camera)
		{
			_context = context;
			_camera = camera;
			if (!TryCull()) return;
			SetupRealtimeLights();

			if (_camera == _mainCamera || _camera.cameraType == CameraType.SceneView)
			{
				RenderMainCamera();
				RenderPostProcess();
				RenderEditor();

				Execute();
			}
			else
			{
				RenderSecondaryCamera();
			}

			_context.Submit();
		}

		/// <summary>
		/// Executes the rendering pipeline for the main camera.
		/// </summary>
		private void RenderMainCamera()
		{
			BeginSample("Main Camera");
			SetupCameraProperties();
			SetupOpaqueRenderTarget();

			BeginSample("Opaque Geometry");
			DrawOpaqueGeometry();
			EndSample("Opaque Geometry");

			BeginSample("Skybox");
			DrawSkybox();
			EndSample("Skybox");
			
			SetupTransparentRenderTarget();
			
			BeginSample("Transparent Geometry");
			DrawTransparentGeometry();
			EndSample("Transparent Geometry");

			EndSample("Main Camera");
			Execute();
			return;

			void SetupOpaqueRenderTarget()
			{
				var width = _camera.pixelWidth;
				var height = _camera.pixelHeight;

				if (_mainColorRT == null || _mainColorRT.width != width || _mainColorRT.height != height)
				{
					if (_mainColorRT != null)
						RenderTexture.ReleaseTemporary(_mainColorRT);

					var descriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.DefaultHDR, 24)
					{
						useMipMap = false,
						autoGenerateMips = false,
						sRGB = false
					};
					_mainColorRT = RenderTexture.GetTemporary(descriptor);
				}

				if (_mainFragmentRT == null || _mainFragmentRT.width != width || _mainFragmentRT.height != height)
				{
					if (_mainFragmentRT != null)
						RenderTexture.ReleaseTemporary(_mainFragmentRT);
					
					var descriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.ARGBFloat, 0)
					{
						useMipMap = false,
						autoGenerateMips = false,
						sRGB = false
					};
					_mainFragmentRT = RenderTexture.GetTemporary(descriptor);
				}

				MainMRT[0] = _mainColorRT;
				MainMRT[1] = _mainFragmentRT;
				
				_commandBuffer.SetRenderTarget(MainMRT, _mainColorRT.depthBuffer);
				_commandBuffer.ClearRenderTarget(true, true, new Color(0, 0, 0, -1));
			}
			
			void SetupTransparentRenderTarget()
			{
				// Skips the MRT, as we do not want to update the fragment RT for transparent geometry.
				_commandBuffer.SetRenderTarget(_mainColorRT, _mainColorRT.depthBuffer);
			}
		}

		/// <summary>
		/// Executes the post-processing pipeline.
		/// </summary>
		private void RenderPostProcess()
		{
			BeginSample("Post Process");
			
			BeginSample("Prep Pass");
			SetupPrepRenderTarget();
			DrawFullscreenTriangle(0);
			EndSample("Prep Pass");
			
			BeginSample("Effect Pass");
			SetupEffectRenderTarget();
			DrawFullscreenTriangle(1);
			EndSample("Effect Pass");
			
			BeginSample("Combining Pass");
			SetupCombiningRenderTarget();
			DrawFullscreenTriangle(2);
			EndSample("Combining Pass");

			EndSample("Post Process");
			Execute();
			return;
			
			void SetupPrepRenderTarget()
			{
				var width = Mathf.Max(_camera.pixelWidth / 2, 1);
				var height = Mathf.Max(_camera.pixelHeight / 2, 1);
				
				if (_postPrepCurrentRT == null || _postPrepCurrentRT.width != width || _postPrepCurrentRT.height != height
					|| _postPrepHistoryRT == null || _postPrepHistoryRT.width != width || _postPrepHistoryRT.height != height)
				{
					if (_postPrepCurrentRT != null)
						RenderTexture.ReleaseTemporary(_postPrepCurrentRT);
					if (_postPrepHistoryRT != null)
						RenderTexture.ReleaseTemporary(_postPrepHistoryRT);

					var descriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.RGHalf, 0)
					{
						useMipMap = false,
						autoGenerateMips = false,
						sRGB = false
					};
					_postPrepCurrentRT = RenderTexture.GetTemporary(descriptor);
					_postPrepHistoryRT = RenderTexture.GetTemporary(descriptor);

					// Clear the history, so there's no garbage during the first frame.
					_commandBuffer.SetRenderTarget(_postPrepHistoryRT, BuiltinRenderTextureType.None);
					_commandBuffer.ClearRenderTarget(false, true, Color.clear);
				}

				_commandBuffer.SetGlobalTexture(MainColorRTID, _mainColorRT);
				_commandBuffer.SetGlobalTexture(PostPrepHistoryRTID, _postPrepHistoryRT);
				_commandBuffer.SetRenderTarget(_postPrepCurrentRT, BuiltinRenderTextureType.None);
				_commandBuffer.ClearRenderTarget(false, true, Color.clear);
			}
			
			void SetupEffectRenderTarget()
			{
				var width = Mathf.Max(_camera.pixelWidth / 2, 1);
				var height = Mathf.Max(_camera.pixelHeight / 2, 1);

				if (_postEffectRT == null || _postEffectRT.width != width || _postEffectRT.height != height)
				{
					if (_postEffectRT != null)
						RenderTexture.ReleaseTemporary(_postEffectRT);
					
					var descriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.ARGBHalf, 0)
					{
						useMipMap = false,
						autoGenerateMips = false,
						sRGB = false
					};
					_postEffectRT = RenderTexture.GetTemporary(descriptor);
				}

				_commandBuffer.SetGlobalTexture(MainColorRTID, _mainColorRT);
				_commandBuffer.SetGlobalTexture(MainFragmentRTID, _mainFragmentRT);
				_commandBuffer.SetGlobalTexture(PostPrepCurrentRTID, _postPrepCurrentRT);
				_commandBuffer.SetRenderTarget(_postEffectRT, BuiltinRenderTextureType.None);
				_commandBuffer.ClearRenderTarget(false, true, Color.clear);
			}

			void SetupCombiningRenderTarget()
			{
				_commandBuffer.SetGlobalTexture(MainColorRTID, _mainColorRT);
				_commandBuffer.SetGlobalTexture(PostPrepCurrentRTID, _postPrepCurrentRT);
				_commandBuffer.SetGlobalTexture(PostEffectRTID, _postEffectRT);

				(_postPrepHistoryRT, _postPrepCurrentRT) = (_postPrepCurrentRT, _postPrepHistoryRT);

				_commandBuffer.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
				_commandBuffer.ClearRenderTarget(false, true, Color.clear);
			}

			void DrawFullscreenTriangle(int shaderPass)
			{
				var material = _settings.ppfxMaterial;
				if (material == null) return;

				_commandBuffer.DrawProcedural(Matrix4x4.identity, material, shaderPass, MeshTopology.Triangles, 3);
			}
		}
		
		/// <summary>
		/// Executes editor-specific passes, such as gizmos and scene view geometry.
		/// </summary>
		private void RenderEditor()
		{
#if UNITY_EDITOR || DEVELOPMENT_BUILD
			SetupEditor();
			DrawGizmos();
			return;

			void SetupEditor()
			{
				if (_camera.cameraType == CameraType.SceneView)
					ScriptableRenderContext.EmitWorldGeometryForSceneView(_camera);
			}

			void DrawGizmos()
			{
				if (!Handles.ShouldRenderGizmos()) return;
				_context.DrawGizmos(_camera, GizmoSubset.PreImageEffects);
				_context.DrawGizmos(_camera, GizmoSubset.PostImageEffects);
			}
#endif
		}

		/// <summary>
		/// Executes the rendering pipeline for any secondary camera.
		/// </summary>
		private void RenderSecondaryCamera()
		{
			BeginSample("Secondary Camera");
			SetupRenderTarget();
			SetupCameraProperties();
			
			BeginSample("Opaque Geometry");
			DrawOpaqueGeometry();
			EndSample("Opaque Geometry");
			
			BeginSample("Skybox");
			DrawSkybox();
			EndSample("Skybox");
			
			BeginSample("Transparent Geometry");
			DrawTransparentGeometry();
			EndSample("Transparent Geometry");
			
			EndSample("Secondary Camera");
			Execute();
			return;

			void SetupRenderTarget()
			{
				_commandBuffer.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
				_commandBuffer.ClearRenderTarget(true, true, Color.clear);
			}
		}

		/// <summary>
		/// Renders all opaque geometry in the scene.
		/// </summary>
		private void DrawOpaqueGeometry()
		{
			var settings = new RendererListDesc(OpaqueShaderTagIds, _cullingResults, _camera)
			{
				renderQueueRange = RenderQueueRange.opaque,
				sortingCriteria = SortingCriteria.CommonOpaque,
				rendererConfiguration =
					PerObjectData.Lightmaps |
					PerObjectData.ShadowMask |
					PerObjectData.LightProbe |
					PerObjectData.ReflectionProbes
			};
			var rendererList = _context.CreateRendererList(settings);
			_commandBuffer.DrawRendererList(rendererList);
		}

		/// <summary>
		/// Renders the skybox for the current camera if its clear flags are set to Skybox.
		/// </summary>
		private void DrawSkybox()
		{
			if (_camera.clearFlags != CameraClearFlags.Skybox) return;

			var rendererList = _context.CreateSkyboxRendererList(_camera);
			_commandBuffer.DrawRendererList(rendererList);
		}

		/// <summary>
		/// Renders all transparent geometry in the scene.
		/// </summary>
		private void DrawTransparentGeometry()
		{
			var settings = new RendererListDesc(TransparentShaderTagIds, _cullingResults, _camera)
			{
				renderQueueRange = RenderQueueRange.transparent,
				sortingCriteria = SortingCriteria.CommonTransparent,
				rendererConfiguration =
					PerObjectData.Lightmaps |
					PerObjectData.ShadowMask |
					PerObjectData.LightProbe |
					PerObjectData.ReflectionProbes
			};

			var rendererList = _context.CreateRendererList(settings);
			_commandBuffer.DrawRendererList(rendererList);
		}

		/// <summary>
		/// Attempts to perform the culling process based on the currently active camera.
		/// </summary>
		private static bool TryCull()
		{
			if (!_camera.TryGetCullingParameters(out var cullingParameters))
				return false;

			_cullingResults = _context.Cull(ref cullingParameters);
			return true;
		}

		/// <summary>
		/// Sets the context camera properties and updates GPU parameters relevant for rendering.
		/// </summary>
		private void SetupCameraProperties()
		{
			_context.SetupCameraProperties(_camera);
			_commandBuffer.SetGlobalVector(CameraWSID, _camera.transform.position);
			
			var gpuProjectionMatrix = GL.GetGPUProjectionMatrix(_camera.projectionMatrix, true);
			_commandBuffer.SetGlobalMatrix(MatrixInvPID, gpuProjectionMatrix.inverse);
			
			var tanHalfFov = Mathf.Tan(_camera.fieldOfView * Mathf.Deg2Rad * 0.5f);
			_commandBuffer.SetGlobalFloat(TanHalfFovID, tanHalfFov);
		}

		/// <summary>
		/// Configures and prepares the real-time lighting data for the GPU.
		/// </summary>
		private void SetupRealtimeLights()
		{
			// If realtimeLightCount is more than MaxRealtimeLights, the last lights will be ignored.
			var realtimeLightCount = Mathf.Min(_cullingResults.visibleLights.Length, MaxRealtimeLights);
			var sun = RenderSettings.sun;
			var index = 0;

			for (var i = 0; i < realtimeLightCount; i++)
			{
				var visibleLight = _cullingResults.visibleLights[i];
				if (visibleLight.light == sun) continue;

				// XYZ = Positions, W = RangeSquared
				_realtimeLightPositions[index] = visibleLight.localToWorldMatrix.GetColumn(3);
				_realtimeLightPositions[index].w = visibleLight.range * visibleLight.range;

				// XYZ = Directions, W = SpotAngle * VolumetricGlow (-1 = Disabled, 1 = Enabled)
				_realtimeLightDirections[index] = visibleLight.localToWorldMatrix.GetColumn(2);
				_realtimeLightDirections[index].w = visibleLight.spotAngle * Mathf.Sign(visibleLight.light.innerSpotAngle - 0.5f);

				// RGB = Colours * Intensity,
				// A = LightType (-1 = Spot, 0 = Directional, 1 = Point) * (1 + VolumetricDensity [0..1))
				_realtimeLightColors[index] = visibleLight.finalColor;
				_realtimeLightColors[index].w = ((float)visibleLight.lightType - 1f) * (1f + Mathf.Abs(visibleLight.light.cookieSize));
				
				index++;
			}

			_commandBuffer.SetGlobalInt(RealtimeLightCountBufferID, index);
			if (index == 0) return;
			_commandBuffer.SetGlobalVectorArray(RealtimeLightPositionBufferID, _realtimeLightPositions);
			_commandBuffer.SetGlobalVectorArray(RealtimeLightDirectionBufferID, _realtimeLightDirections);
			_commandBuffer.SetGlobalVectorArray(RealtimeLightColorBufferID, _realtimeLightColors);
		}

		/// <summary>
		/// Executes the contents of the current command buffer and clears it
		/// to prepare for the next set of rendering commands.
		/// </summary>
		private void Execute()
		{
			_context.ExecuteCommandBuffer(_commandBuffer);
			_commandBuffer.Clear();
		}

		/// <summary>
		/// Begins profiling of a specific sample using the provided sample name.
		/// This is used for performance measurement and debugging purposes.
		/// </summary>
		private void BeginSample(string sampleName)
		{
#if UNITY_EDITOR || DEVELOPMENT_BUILD
			_commandBuffer.BeginSample(sampleName);
#endif
		}

		/// <summary>
		/// Ends profiling of a specific sample using the provided sample name.
		/// </summary>
		private void EndSample(string sampleName)
		{
#if UNITY_EDITOR || DEVELOPMENT_BUILD
			_commandBuffer.EndSample(sampleName);
#endif
		}

		/// <summary>
		/// Releases resources associated with the renderer, including command buffers and any allocated render textures.
		/// </summary>
		public void Dispose()
		{
			if (_mainColorRT != null) 
				RenderTexture.ReleaseTemporary(_mainColorRT);
			_mainColorRT = null;
			
			if (_mainFragmentRT != null) 
				RenderTexture.ReleaseTemporary(_mainFragmentRT);
			_mainFragmentRT = null;
			
			if (_postPrepCurrentRT != null) 
				RenderTexture.ReleaseTemporary(_postPrepCurrentRT);
			_postPrepCurrentRT = null;
			
			if (_postPrepHistoryRT != null) 
				RenderTexture.ReleaseTemporary(_postPrepHistoryRT);
			_postPrepHistoryRT = null;
			
			if (_postEffectRT != null) 
				RenderTexture.ReleaseTemporary(_postEffectRT);
			_postEffectRT = null;
			
			if (_sunShadowMapRT != null) 
				RenderTexture.ReleaseTemporary(_sunShadowMapRT);
			_sunShadowMapRT = null;

			_commandBuffer.Release();
		}
	}
}
