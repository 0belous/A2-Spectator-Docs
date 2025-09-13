--!strict

local Inputs = require("inputs")
local Util = require("util")

local moveSpeed = config.moveSpeed or 1600
local mouseSensitivity = config.mouseSensitivity or 3.6
local gravityChaser = gravity.upRotation

camera.fieldOfView = 70

function onTransitionBegin(transitionInfo: Transition)
	if Inputs.firstTransition then
		-- Sets a nice overview location for the Halcyon ring
		transitionInfo.length = 10
		camera.position = Vec3.new(0, -3000, -27000)
		Inputs.rotEuler = Vec3.new(0, 0, 90)
		camera.rotation = Quat.fromEuler(Inputs.rotEuler.x, Inputs.rotEuler.y, Inputs.rotEuler.z)
	else
		camera.position = transitionInfo.startPosition
		camera.rotation = transitionInfo.startRotation
		Inputs.rotEuler = transitionInfo.startRotation:euler()
		Inputs.rotEuler.x = 0
	end
	Inputs.firstTransition = false
	Util.setSmoothing(Inputs.smoothing, Inputs)
end

function onGui()
	if Gui.collapsingHeader("Debug") then
		Gui.indent()
		camera.hideNearestHead = Gui.checkbox("Hide nearest head", camera.hideNearestHead)

		local newGoalExplosions = Gui.checkbox("Goal explosions", Inputs.playGoalExplosions)
		if newGoalExplosions ~= Inputs.playGoalExplosions then
			Inputs.playGoalExplosions = newGoalExplosions
			spectatorDebug.goalExplosions = Inputs.playGoalExplosions
		end

		local newScraprunSpinners = Gui.checkbox("Scraprun spinners", Inputs.playScraprunSpinners)
		if newScraprunSpinners ~= Inputs.playScraprunSpinners then
			Inputs.playScraprunSpinners = newScraprunSpinners
			spectatorDebug.scrapRunSpinners = Inputs.playScraprunSpinners
		end

		local newPlaceBallEnabled = Gui.checkbox("'Place Ball' visuals", Inputs.placeBallEnabled)
		if newPlaceBallEnabled ~= Inputs.placeBallEnabled then
			Inputs.placeBallEnabled = newPlaceBallEnabled
			spectatorDebug.placeBallHereVisuals = Inputs.placeBallEnabled
		end

		local newBallScaleMultiplier = Gui.sliderFloat("Ball scale multiplier", Inputs.ballScaleMultiplier, 0, 10)
		if newBallScaleMultiplier ~= Inputs.ballScaleMultiplier then
			Inputs.ballScaleMultiplier = newBallScaleMultiplier
			spectatorDebug.replayBallScaleMultiplier = Inputs.ballScaleMultiplier
		end
		Gui.unindent()
	end

	if Gui.collapsingHeader("Controls") then
		Gui.indent()
		Gui.text("Movement")
		Gui.indent()
		Gui.text("Planar Movement: WASD or Left Gamepad Stick")
		Gui.text("Move Up and Down: Q and E or Gamepad Triggers")
		Gui.text("Speed Up: Left Shift or Right Shoulder")
		Gui.text("Slow Down: Left Control or Left Shoulder")
		Gui.unindent()
		Gui.text("Rotation")
		Gui.indent()
		Gui.text("Pan: Mouse or Right Gamepad Stick")
		Gui.text("Roll: Right Click and Drag or D-Pad Left and Right")
		Gui.text("Align to Current Gravity: Spacebar")
		Gui.unindent()
		Gui.text("Other")
		Gui.indent()
		Gui.text("Toggle Smoothing: Caps Lock")
		Gui.text("Zoom: Scroll Wheel or D-Pad Up and Down")
		Gui.text("Focus: Middle mouse click")
		Gui.unindent()
		Gui.unindent()
	end
	Gui.newLine()

	moveSpeed = Gui.sliderFloat("Move Speed", moveSpeed, Inputs.minMoveSpeed, Inputs.maxMoveSpeed)
	mouseSensitivity = Gui.sliderFloat("Mouse Sensitivity", mouseSensitivity, 0, 10)

	Inputs.speedAdjustmentRate = Gui.sliderFloat("Speed Adjustment Rate", Inputs.speedAdjustmentRate, 0, 5)
	Gui.setItemTooltip("How fast the speed adjustment buttons affect the camera speed")
	Inputs.alignToGravity = Gui.checkbox("Automatically Align to Gravity", Inputs.alignToGravity)
	Inputs.localMovementAxesDefault = Gui.checkbox("Use Local Movement Axes (Hold alt to use other set of axes)", Inputs.localMovementAxesDefault)

	Gui.separatorText("Manual Controls")
	camera.position = Gui.dragFloat3("Position", camera.position, 10, -100000, 100000)
	local newRot = Gui.dragFloat3("Rotation (roll, pitch, yaw)", Inputs.rotEuler, 1, -180, 180)
	if Gui.isItemActive() then
		gravityChaser = gravity.upRotation
		Inputs.rotEuler = newRot
		camera.rotation = Quat.fromEuler(Inputs.rotEuler.x, Inputs.rotEuler.y, Inputs.rotEuler.z)
	end
	camera.fieldOfView = Gui.sliderFloat("Field of View", camera.fieldOfView, Inputs.minFov, Inputs.maxFov)

	camera.showNameTags = Gui.checkbox("Show name tags", camera.showNameTags)
	Gui.newLine()

	if Gui.collapsingHeader("Smoothing##smoothingSettingsHeader") then
		Gui.indent()
		local newSmoothing = Gui.checkbox("Smoothing##smoothingCheckbox", Inputs.smoothing)
		if newSmoothing ~= Inputs.smoothing then
			Inputs.smoothing = newSmoothing
			Util.setSmoothing(Inputs.smoothing, Inputs)
		end
		Inputs.lookSmoothness = Gui.sliderFloat("Look Smoothness", Inputs.lookSmoothness, 0, 1)
		camera.positionSmoothing = Gui.sliderFloat("Position Smoothing", camera.positionSmoothing, 0, 1)
		camera.rotationSmoothing = Gui.sliderFloat("Rotation Smoothing", camera.rotationSmoothing, 0, 1)
		camera.fieldOfViewSmoothing = Gui.sliderFloat("Field of View Smoothing", camera.fieldOfViewSmoothing, 0, 1)
		Gui.unindent()
	end

	-- Post Processing Effects:
	if Gui.collapsingHeader("Post Processing Settings") then
		Gui.indent()
		camera.nearClippingPlane = Gui.sliderFloat("Near Clipping Plane", camera.nearClippingPlane, 1, 100)

		if Gui.button("Auto Focus") then
			Util.autoFocusCenter()
		end
		Gui.sameLine()
		Inputs.continuousAutoFocus = Gui.checkbox("Continuous Auto Focus", Inputs.continuousAutoFocus)
		Gui.unindent()
	end
end

function tick(dt)
	if Input.getKey(Inputs.autoFocusKeyKB) or Input.getKey(Inputs.autoFocusKeyGP) or Inputs.continuousAutoFocus then
		Util.autoFocusCenter()
	end

	local forward = camera.rotation:getForwardVector()
	local currentGravityDirection = gravityChaser:getUpVector()
	local gravityForward = Util.projectVectorOntoPlane(forward, currentGravityDirection):getSafeNormal()
	local right = camera.rotation:getRightVector()
	local up = camera.rotation:getUpVector()
	local useLocalMovementAxes = Util.xor(Inputs.localMovementAxesDefault, Input.getKey(Inputs.gravityAlignedMovementModifier))

	-- Speed
	if Input.getKey(Inputs.fastKey) or Input.getKey(Input.Gamepad.RightShoulder) then
		moveSpeed *= (1 + Inputs.speedAdjustmentRate * dt)
		if moveSpeed < Inputs.minMoveSpeed then
			moveSpeed = Inputs.minMoveSpeed
		end
		if moveSpeed > Inputs.maxMoveSpeed then
			moveSpeed = Inputs.maxMoveSpeed
		end
	elseif Input.getKey(Inputs.slowKey) or Input.getKey(Input.Gamepad.LeftShoulder) then
		moveSpeed *= (1 - Inputs.speedAdjustmentRate * dt)
		if moveSpeed > Inputs.maxMoveSpeed then
			moveSpeed = Inputs.maxMoveSpeed
		end
	end

	if Input.getKeyDown(Inputs.toggleSmoothingKey) then
		Inputs.smoothing = not Inputs.smoothing
		Util.setSmoothing(Inputs.smoothing, Inputs)
	end

	-- Zoom
	-- Keyboard
	camera.fieldOfView -= Input.getAnalog(Input.Key.MouseWheelAxis) * Inputs.zoomSpeedKb
	-- Gamepad
	if Input.getKey(Inputs.zoomInGp) then
		camera.fieldOfView -= Inputs.zoomSpeedGp
	elseif Input.getKey(Inputs.zoomOutGp) then
		camera.fieldOfView += Inputs.zoomSpeedGp
	end

	camera.fieldOfView = math.clamp(camera.fieldOfView, Inputs.minFov, Inputs.maxFov)

	-- Movement
	--- Holds the input vector combined from keyboard and gamepad
	local input = Vec3.zeroVector
	-- Keyboard
	if Input.getKey(Inputs.forwardKey) then
		if useLocalMovementAxes then
			input += forward
		else
			input += gravityForward
		end
	end
	if Input.getKey(Inputs.backwardKey) then
		if useLocalMovementAxes then
			input -= forward
		else
			input -= gravityForward
		end
	end
	if Input.getKey(Inputs.rightKey) then
		input += right
	end
	if Input.getKey(Inputs.leftKey) then
		input -= right
	end
	if Input.getKey(Inputs.upKey) then
		if useLocalMovementAxes then
			input += up
		else
			input += currentGravityDirection
		end
	end
	if Input.getKey(Inputs.downKey) then
		if useLocalMovementAxes then
			input -= up
		else
			input -= currentGravityDirection
		end
	end

	-- Gamepad
	input += right * Input.getAnalog(Input.Gamepad.LeftX)
	input += forward * Input.getAnalog(Input.Gamepad.LeftY)
	input += up * Input.getAnalog(Input.Gamepad.RightTriggerAxis)
	input -= up * Input.getAnalog(Input.Gamepad.LeftTriggerAxis)

	-- Rotation
	-- slow down rotation if zoomed in
	local adjustedRotSpeed = Inputs.fovRotSpeedMultiplier * (camera.fieldOfView - 90) / 90 + Inputs.rotSpeed
	local adjustedMouseSensitivity = Inputs.fovRotSpeedMultiplier * (camera.fieldOfView - 90) / 90 + mouseSensitivity
	local adjustedLookSmoothness = 1 - (1 - Inputs.lookSmoothness) ^ 3
	local lookInputTargetDelta = Vec3.zeroVector

	-- Mouse
	local mouse = Input.getMouseDelta()
	local rollAngle = -Inputs.rotEuler.x * math.pi / 180.0
	if mouse and mouse.x then
		if Input.getKey(Inputs.rollMouseEnable) then
			-- Roll
			lookInputTargetDelta.x += mouse.x * mouseSensitivity / 2.0
		else
			-- Yaw
			lookInputTargetDelta.z += mouse.x * adjustedMouseSensitivity
			-- Pitch
			lookInputTargetDelta.y += mouse.y * adjustedMouseSensitivity
		end
	end

	-- Keyboard
	if Input.getKey(Inputs.yawRightKey) then
		lookInputTargetDelta.z += adjustedRotSpeed * dt
	end
	if Input.getKey(Inputs.yawLeftKey) then
		lookInputTargetDelta.z -= adjustedRotSpeed * dt
	end
	if Input.getKey(Inputs.pitchUpKey) then
		lookInputTargetDelta.y += adjustedRotSpeed * dt
	end
	if Input.getKey(Inputs.pitchDownKey) then
		lookInputTargetDelta.y -= adjustedRotSpeed * dt
	end

	-- Gamepad
	-- Roll
	if Input.getKey(Inputs.rollRightGp) then
		lookInputTargetDelta.x += Inputs.rotSpeed * dt / 2
	elseif Input.getKey(Inputs.rollLeftGp) then
		lookInputTargetDelta.x -= Inputs.rotSpeed * dt / 2
	end
	-- Yaw
	lookInputTargetDelta.z += Input.getAnalog(Input.Gamepad.RightX) * adjustedRotSpeed * dt
	-- Pitch
	lookInputTargetDelta.y += Input.getAnalog(Input.Gamepad.RightY) * adjustedRotSpeed * dt

	-- Smoothing
	local rollAdjustedInput = Vec3.new(
		lookInputTargetDelta.x,
		lookInputTargetDelta.y * math.cos(rollAngle) + lookInputTargetDelta.z * math.sin(rollAngle),
		lookInputTargetDelta.z * math.cos(rollAngle) - lookInputTargetDelta.y * math.sin(rollAngle)
	)
	Inputs.lookInputTarget += rollAdjustedInput
	local nextLookDiff = Inputs.lookInputTarget * math.min((1 - adjustedLookSmoothness) * dt * 60, 1)

	-- Gravity Roll Adjustment
	if Inputs.alignToGravity then
		if gravityChaser ~= gravity.upRotation and gravity.strength ~= 0 then
			local inputTotal = nextLookDiff:length()
			local nextGravityChaser =
				Quat.slerp(gravityChaser, gravity.upRotation, (inputTotal * Inputs.gravityChaseSpeed + Inputs.gravitySlowChaseSpeed) * dt)

			local nextRotation = nextGravityChaser:inverse() * Quat.fromXZ(forward, nextGravityChaser:rotateVector(Vec3.new(0, 0, 1)))
			Inputs.rotEuler = nextRotation:euler() + Vec3.new(Inputs.rotEuler.x, 0, 0) -- preserve existing roll
			gravityChaser = nextGravityChaser
		end
	end
	if Input.getKeyDown(Inputs.snapToGravityKey) then
		gravityChaser = gravity.upRotation
		Inputs.rotEuler.x = 0
	end

	Inputs.rotEuler += nextLookDiff
	Inputs.lookInputTarget -= nextLookDiff

	-- Clamp rotation
	if Inputs.rotEuler.y > 89.9 then
		Inputs.rotEuler.y = 89.9
	end
	if Inputs.rotEuler.y < -89.9 then
		Inputs.rotEuler.y = -89.9
	end

	-- Reset roll if close to 0
	if Input.getKeyUp(Inputs.rollMouseEnable) or Input.getKeyUp(Inputs.rollRightGp) or Input.getKeyUp(Inputs.rollLeftGp) then
		local clampedRoll = math.abs(Inputs.rotEuler.x) % 360
		if clampedRoll <= Inputs.rollResetTolerance then
			Inputs.rotEuler.x = 0
			Inputs.lookInputTarget.x = 0
		end
	end

	camera.position += input * moveSpeed * dt
	camera.rotation = gravityChaser * Quat.fromEuler(Inputs.rotEuler.x, Inputs.rotEuler.y, Inputs.rotEuler.z)
end

function onMessageReceived(message)
	if message.messageType == "setTransform" then
		Inputs.rotEuler = message.rotation:euler()
		Inputs.rotEuler.x = 0
		camera.position = message.position
		camera.rotation = message.rotation
		camera.fieldOfView = message.fieldOfView
	elseif message.messageType == "lookAt" then
		camera:lookAt(message.target, message.upVector)
		Inputs.rotEuler = camera.rotation:euler()
	end
end
