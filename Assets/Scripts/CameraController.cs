using UnityEngine;

public class CameraController : MonoBehaviour
{
	[SerializeField] private float moveSpeed = 5f;
	[SerializeField] private float slowSpeedMultiplier = 0.5f;
	[SerializeField] private float lookSensitivity = 2f;
	[SerializeField] private float slowLookSmooth = 12f;
	[SerializeField] private float slowMoveSmoothTime = 0.15f;
	[SerializeField] private float maxPitch = 85f;
	[SerializeField] private bool lockCursor = true;

	private float _yaw;
	private float _pitch;
	private float _targetYaw;
	private float _targetPitch;
	private Vector3 _currentMove;
	private Vector3 _moveVelocity;

	private void OnEnable()
	{
		var euler = transform.eulerAngles;
		_yaw = euler.y;
		_pitch = NormalizePitch(euler.x);
		_targetYaw = _yaw;
		_targetPitch = _pitch;
		
		LockCursor(lockCursor);
	}

	private void Update()
	{
		UpdateLook();
		UpdateMove();
	}

	private void OnDisable()
	{
		LockCursor(false);
	}

	private void UpdateLook()
	{
		var slow = IsSlowHeld();
		var mouseX = Input.GetAxis("Mouse X");
		var mouseY = Input.GetAxis("Mouse Y");

		_targetYaw += mouseX * lookSensitivity;
		_targetPitch -= mouseY * lookSensitivity;
		_targetPitch = Mathf.Clamp(_targetPitch, -maxPitch, maxPitch);

		if (slow)
		{
			var dt = Time.deltaTime;
			_yaw = Damp(_yaw, _targetYaw, slowLookSmooth, dt);
			_pitch = Damp(_pitch, _targetPitch, slowLookSmooth, dt);
		}
		else
		{
			_yaw = _targetYaw;
			_pitch = _targetPitch;
		}

		transform.rotation = Quaternion.Euler(_pitch, _yaw, 0f);
	}

	private void UpdateMove()
	{
		var input = Vector3.zero;
		if (Input.GetKey(KeyCode.W)) input += Vector3.forward;
		if (Input.GetKey(KeyCode.S)) input += Vector3.back;
		if (Input.GetKey(KeyCode.A)) input += Vector3.left;
		if (Input.GetKey(KeyCode.D)) input += Vector3.right;
		if (Input.GetKey(KeyCode.E)) input += Vector3.up;
		if (Input.GetKey(KeyCode.Q)) input += Vector3.down;

		var slow = IsSlowHeld();
		var hasInput = input.sqrMagnitude >= 0.001f;
		var direction = hasInput ? transform.TransformDirection(input.normalized) : Vector3.zero;

		if (slow)
		{
			var targetMove = direction * (moveSpeed * slowSpeedMultiplier);
			_currentMove = Vector3.SmoothDamp(_currentMove, targetMove, ref _moveVelocity, slowMoveSmoothTime);
		}
		else
		{
			if (!hasInput)
			{
				_currentMove = Vector3.zero;
				_moveVelocity = Vector3.zero;
				return;
			}

			_currentMove = direction * moveSpeed;
			_moveVelocity = Vector3.zero;
		}

		transform.position += _currentMove * Time.deltaTime;
	}

	private static void LockCursor(bool enable)
	{
		Cursor.lockState = enable ? CursorLockMode.Locked : CursorLockMode.None;
		Cursor.visible = !enable;
	}

	private static float NormalizePitch(float pitch)
	{
		if (pitch > 180f) pitch -= 360f;
		return pitch;
	}

	private static bool IsSlowHeld() => Input.GetKey(KeyCode.LeftShift) || Input.GetKey(KeyCode.RightShift);

	private static float Damp(float current, float target, float lambda, float deltaTime) => Mathf.Lerp(current, target, 1f - Mathf.Exp(-lambda * deltaTime));
}
