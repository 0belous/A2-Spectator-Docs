-- @name Drone Camera
-- @description Simulates an FPV drone in with acro mode
-- @author Another Axiom

metadata = {
	name = "Drone Camera",
	description = "Simulates an FPV drone in with acro mode",
	author = "Another Axiom",
	defaultKeybind = "Y",
}

local rotSpeed = 130

local droneRotation = Quat.fromEuler(0, 0, 0)
local velocity = Vec3.zeroVector
local pitchOffset = 30
local thrust = 3500

local collisionEnabled = true
local collisionRadius = 100

local halfPrecisionThrust = false

function onGui()
	if Gui.collapsingHeader("Controls") then
		Gui.indent()
		Gui.text("Throttle and yaw: Left stick")
		Gui.text("Pitch and roll: Right stick")
		Gui.unindent()
	end
	Gui.newLine()

	pitchOffset = Gui.sliderFloat("Pitch Offset", pitchOffset, 0, 60)
	thrust = Gui.sliderFloat("Thrust", thrust, 0, 6000)
	rotSpeed = Gui.sliderFloat("Rotation Speed", rotSpeed, 0, 300)
	camera.fieldOfView = Gui.sliderFloat("Field of View", camera.fieldOfView, 40, 170)
	collisionEnabled = Gui.checkbox("Collision Enabled", collisionEnabled)
	halfPrecisionThrust = Gui.checkbox("Half Precision Thrust", halfPrecisionThrust)
	Gui.setItemTooltip("Start thrust at zero from the middle of the left analog stick Y axis")
end

function main()
	camera.fieldOfView = 100
end

function tick(dt)
	if not camera.isActive and not camera.isFollowed then
		return
	end

	local up = droneRotation:getUpVector()
	local rot_euler = droneRotation:euler()

	camera:lookAt(Vec3.zeroVector, gravity.upDirection)

	-- Rotation
	local rotEuler = Vec3.zeroVector
	local spinMultiplier = 1.8
	rotEuler.x = Input.getAnalog(Input.Gamepad.RightX) * rotSpeed * spinMultiplier * dt
	-- The line below was changed
	rotEuler.y = Input.getAnalog(Input.Gamepad.RightY) * rotSpeed * spinMultiplier * dt
	rotEuler.z = Input.getAnalog(Input.Gamepad.LeftX) * rotSpeed * spinMultiplier * dt

	rot_euler = (droneRotation * Quat.fromEuler(rotEuler.x, rotEuler.y, rotEuler.z)):euler()

	-- Drone velocity calculations
	local thrustAxis = 0
	if halfPrecisionThrust then
		thrustAxis = math.clamp(Input.getAnalog(Input.Gamepad.LeftY), 0, 1)
	else
		thrustAxis = math.clamp((Input.getAnalog(Input.Gamepad.LeftY) + 1) / 2, 0, 1)
	end
	velocity += up * thrustAxis * thrust * dt -- Thrust
	velocity = velocity * 0.998 -- Drag
	velocity -= gravity.upDirection * 980 * dt -- Earth gravity

	-- Collison detection
	local hit = camera:castRay(camera.position, camera.position + velocity:getSafeNormal() * collisionRadius)
	if hit.successful and collisionEnabled then
		velocity = -projectVectorOntoVector(velocity, hit.normal)
	end

	camera.position += velocity * dt
	droneRotation = Quat.fromEuler(rot_euler.x, rot_euler.y, rot_euler.z)

	camera.rotation = droneRotation * Quat.fromEuler(0, pitchOffset, 0)
end

function onTransitionBegin(transitionInfo)
	camera.position = transitionInfo.startPosition
	camera.rotation = transitionInfo.startRotation
end

function projectVectorOntoVector(vec1: Vec3, vec2: Vec3)
	local dot1 = vec1:dot(vec2)
	local dot2 = vec1:dot(vec1)
	local frac = dot1 / dot2
	local answer = vec2 * frac
	return answer
end