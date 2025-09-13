--!strict

return {
	forwardKey = Input.Key.W,
	backwardKey = Input.Key.S,
	leftKey = Input.Key.A,
	rightKey = Input.Key.D,
	upKey = Input.Key.E,
	downKey = Input.Key.Q,
	--- This moves the camera up and down along the gravity vector instead of  up. It also makes W and S work in the plane defined by the gravity
	gravityAlignedMovementModifier = Input.Key.LeftAlt,
	localMovementAxesDefault = true,

	snapToGravityKey = Input.Key.SpaceBar,

	pitchUpKey = Input.Key.Up,
	pitchDownKey = Input.Key.Down,
	yawLeftKey = Input.Key.Left,
	yawRightKey = Input.Key.Right,

	rollMouseEnable = Input.Key.RightMouseButton,
	rollLeftGp = Input.Gamepad.DPad_Left,
	rollRightGp = Input.Gamepad.DPad_Right,
	rollResetTolerance = 5,

	-- Tap these keys to adjust the camera movement speed
	fastKey = Input.Key.LeftShift,
	slowKey = Input.Key.LeftControl,

	zoomInGp = Input.Gamepad.DPad_Up,
	zoomOutGp = Input.Gamepad.DPad_Down,
	zoomSpeedGp = 0.5,
	zoomSpeedKb = 5,

	minFov = 10,
	maxFov = 160,

	rotSpeed = 180,
	--- How much the zoom level affects view rotation speed control. 0 to disable the effect.
	fovRotSpeedMultiplier = 2,

	maxMoveSpeed = 25000,
	minMoveSpeed = 200,
	--- How fast the speed adjustment buttons affect the camera speed
	speedAdjustmentRate = 1,
	-- Should be a number between 0 and 1, with 1 being infinitely smooth (the camera won't rotate)
	lookSmoothness = 0,
	lookInputTarget = Vec3.zeroVector,
	rotEuler = Vec3.zeroVector,
	firstTransition = true,
	smoothing = false,
	toggleSmoothingKey = Input.Key.CapsLock,

	-- Change apparent gravity direction quickly when looking around, or slowly passively to avoid disorientation
	gravityChaseSpeed = 6,
	gravitySlowChaseSpeed = 0.5,

	-- Post Processing
	autoFocusKeyKB = Input.Key.MiddleMouseButton,
	autoFocusKeyGP = Input.Gamepad.RightThumbstick,
	continuousAutoFocus = false,
	alignToGravity = true,

	playGoalExplosions = false,
	playScraprunSpinners = false,
	placeBallEnabled = true,
	ballScaleMultiplier = 1,
}
