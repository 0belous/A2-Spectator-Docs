--!strict
-- @name Ring Orbit Camera
-- @description Orbits the camera around the Station.
-- @author Another Axiom

metadata = {
	name = "Ring Orbit Camera",
	description = "Orbits the camera around the Halcyon Station.",
	author = "Another Axiom",
	defaultKeybind = "J",
}

local defaultValues = {
	rotate = true,
	radius = 200,
	rotationSpeed = 1,
	rotationAngle = 0.0,
	longitudinalOffset = 170,
	fieldOfView = 90,
	yaw = 90,
	pitch = 0,
}

local function initializeValues()
	for k, v in defaultValues do
		if config[k] == nil then
			config[k] = v
		end
	end
end

local function resetValues()
	for k, v in defaultValues do
		config[k] = v
	end
	camera.position = Vec3.zeroVector
	camera.rotation = Quat.identity
	camera.fieldOfView = config.fieldOfView
end

function main()
	initializeValues()
end

function drawReset(feild: string)
	-- the ##feild ensures that the labels are unique
	if Gui.button(Icon.Undo .. "##" .. feild) then
		config[feild] = defaultValues[feild]
	end
	Gui.sameLine()
end

function onGui()
	config.rotate = Gui.checkbox("Rotate", config.rotate)
	if config.rotate then
		Gui.indent()

		drawReset("rotationSpeed")
		config.rotationSpeed = Gui.sliderFloat("Rotation Speed (deg/s)", config.rotationSpeed, -90.0, 90.0)

		drawReset("radius")
		config.radius = Gui.sliderFloat("Radius (m)", config.radius, 0, 400)
		Gui.setItemTooltip("How far away from the center of rotation the camera is.")

		drawReset("longitudinalOffset")
		config.longitudinalOffset = Gui.sliderFloat("Longitudinal Offset (m)", config.longitudinalOffset, -1000, 1000)
		Gui.setItemTooltip("Slide the camera along the axis of rotation.")

		drawReset("fieldOfView")
		config.fieldOfView = Gui.sliderFloat("Field of View (deg)", config.fieldOfView, 1, 179)

		drawReset("yaw")
		config.yaw = Gui.sliderFloat("Yaw (deg)", config.yaw, -180, 180)
		Gui.setItemTooltip("Point the camera left or right. Press Tab to set exact values.")

		drawReset("pitch")
		config.pitch = Gui.sliderFloat("Pitch (deg)", config.pitch, -90, 90)
		Gui.setItemTooltip("Point the camera up or down. Press Tab to set exact values.")

		Gui.unindent()
	end

	if Gui.button("Reset All") then
		resetValues()
	end

	Gui.sameLine()
	if Gui.button(Icon.Save) then
		saveConfig()
	end
	Gui.setItemTooltip("Save")
end

function tick(dt)
	if Input.getKey(Input.Key.Up) then
		config.radius -= 100 * dt
	end
	if Input.getKey(Input.Key.Down) then
		config.radius += 100 * dt
	end
	if Input.getKey(Input.Key.Left) then
		config.longitudinalOffset += 100 * dt
	end
	if Input.getKey(Input.Key.Right) then
		config.longitudinalOffset -= 100 * dt
	end
	if Input.getKeyDown(Input.Key.PageUp) then
		config.rotationSpeed *= 2
	end
	if Input.getKeyDown(Input.Key.PageDown) then
		config.rotationSpeed /= 2
	end

	if config.rotate then
		local posX = math.sin(config.rotationAngle * (2 * math.pi) / 360) * config.radius * 100
		local posZ = math.cos(config.rotationAngle * (2 * math.pi) / 360) * config.radius * 100
		local upPos = Vec3.new(0, camera.position.y, 0)
		local upDirection = upPos - camera.position
		camera.rotation = Quat.findBetweenVectors(Vec3.upVector, upDirection) * Quat.fromEuler(0, config.pitch, config.yaw)
		local posY = -config.longitudinalOffset * 100
		camera.position = Vec3.new(posX, posY, posZ)
		config.rotationAngle += dt * config.rotationSpeed
		camera.fieldOfView = config.fieldOfView
	end
end
