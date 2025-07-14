--!strict
-- @name Player Camera
-- @description Switch between spectating different players
-- @author Another Axiom

metadata = {
	name = "Player Camera",
	description = "Switch between spectating different players",
	author = "Another Axiom",
	defaultKeybind = "P",
}

local playerNameSearch = ""
type BasicPlayer = {
	playerId: number,
	frameIndex: number, -- 1 = live game. 2, 3, 4 ... = replay index
}
local targetPlayer: BasicPlayer? = nil

local nextPlayerKb = Input.Key.Right
local nextPlayerGp = Input.Gamepad.DPad_Right
local previousPlayerKb = Input.Key.Left
local previousPlayerGp = Input.Gamepad.DPad_Left
local nearClippingPlane = 1

local modeStrings = { "POV", "Auto Orbit", "Manual Orbit" }
local threshold = 600 -- Above this threshhold Auto Orbit will look in the direction the player is moving. Below it will look where the player looks.
local manualOrbitSmoothingMultiplier = 0.2
local kbMoveSensitivity = 10
local gpMoveSensitivity = 10
local mouseWheelSensitivity = 50
local orbitRadius = 500
local orbitHeight = 0
local lookAheadDistance = 100 -- offset distance to the target from the head
local cameraDirection = Vec3.new(1, 0, 0)
local cameraDirectionEuler = Vec3.new(0, 0, 0) -- Used for manual orbit

-- Extra Orbit Controls
local pitchDownKey = Input.Key.W
local yawLeftKey = Input.Key.A
local pitchUpKey = Input.Key.S
local yawRightKey = Input.Key.D
local rotSpeed = 180
local fovRotSpeedMultiplier = 2
local mouseSensitivity = 3.6

local smoothing = 0.15
local enableDynamicDof = false
local clipEverythingBeforePlayer = false
local nearClipOffset = -200

local playerClickSensitivityDegrees = 5

-- This is a helper function to initialize the config with default values
local function initializeConfig(
	defaultConfig: {
		showNameTags: boolean,
		fieldOfView: number,
		followMode: number, -- 1: POV 2: Auto Orbit 3: Manual Orbit
		initialTargetPlayerName: string?,
	}
)
	for i, v in pairs(defaultConfig) do
		if config[i] == nil then
			config[i] = v
		end
	end
end

function getAllPlayers()
	local playerList = {}
	local frames = getAllGameData()
	for i = 1, #frames do
		local players = frames[i].players
		for j = 1, #players do
			table.insert(playerList, { playerId = players[j].playerId, frameIndex = i })
		end
	end
	return playerList
end

function getPlayer(basicPlayer: BasicPlayer?): ReplayPlayer?
	if basicPlayer == nil then
		return nil
	end
	local frames = getAllGameData()
	if basicPlayer.frameIndex <= #frames then
		local frame = frames[basicPlayer.frameIndex]
		return frame:getPlayerById(basicPlayer.playerId)
	end
	return nil
end

function getPlayerIndex(basicPlayer: BasicPlayer?): number
	if basicPlayer == nil then
		return 1
	end
	local frames = getAllGameData()
	if basicPlayer.frameIndex <= #frames then
		local frame = frames[basicPlayer.frameIndex]
		for i = 1, #frame.players do
			if frame.players[i].playerId == basicPlayer.playerId then
				return i
			end
		end
	end
	return 1 -- Default to first player if no other is found
end

function onGui()
	local players = getAllPlayers()
	Gui.text("Player Camera")
	if Gui.beginCombo("Current Mode", modeStrings[config.followMode]) then
		for i = 1, #modeStrings do
			if Gui.selectable(modeStrings[i], i == config.followMode) then
				config.followMode = i
			end
		end
		Gui.endCombo()
	end
	Gui.newLine()
	if Gui.collapsingHeader("Controls") then
		Gui.indent()
		Gui.text("Switch Between Players: Left and Right Arrow Keys or D-pad Left and Right\n\tOR left-click on a player to switch to them")
		Gui.text("Orbit:")
		Gui.indent()
		Gui.text("Right Click and drag or WASD or Gamepad Right Thumbstick")
		Gui.text("Change Orbit Radius: Scroll Wheel or Arrow Keys Up and Down or Gamepad Left Stick Forward and Back")
		Gui.text("Change FOV: Shift + Scroll Wheel")
		Gui.text("Toggle between Manual and Auto orbit modes: Spacebar")
		Gui.unindent()
		Gui.unindent()
		Gui.newLine()
	end

	if Gui.collapsingHeader("Choose a player") then
		Gui.indent()
		if #players == 0 then
			Gui.text("No players present! Try selecting a different place to read game data from at the top of this window")
		else
			if Gui.button(Icon.CaretLeft) then
				previousPlayer(players)
			end
			Gui.sameLine()
			Gui.text(getPlayerIndex(targetPlayer) .. "/" .. #players)
			Gui.sameLine()
			if Gui.button(Icon.CaretRight) then
				nextPlayer(players)
			end
			Gui.sameLine()

			local targetPlayerObj = getPlayer(targetPlayer)
			local playerName = targetPlayerObj and targetPlayerObj.playerName or ""
			Gui.text("Currently spectating: " .. playerName)

			playerNameSearch = Gui.inputText(Icon.Search .. " Filter by name", playerNameSearch)

			if Gui.beginListBox("Player List") then
				for i = 1, #players do
					Gui.pushId(tostring(i))
					local player = players[i]
					local currentPlayer = getPlayer(player)
					if currentPlayer and string.find(string.lower(currentPlayer.playerName), string.lower(playerNameSearch)) then
						local isSelected = false
						if targetPlayer ~= nil and player.playerId == targetPlayer.playerId and player.frameIndex == targetPlayer.frameIndex then
							isSelected = true
						end
						if Gui.selectable(currentPlayer.playerName, isSelected) then
							playerNameSearch = ""
							targetPlayer = player
						end
					end
					Gui.popId()
				end
				Gui.endListBox()
			end
		end
		Gui.unindent()
		Gui.newLine()
	end

	if Gui.collapsingHeader("Settings") then
		Gui.indent()
		config.fieldOfView = Gui.sliderFloat("Field of View", config.fieldOfView, 10, 170)
		config.showNameTags = Gui.checkbox("Show name tags", config.showNameTags)
		local newShowQuests = Gui.checkbox("Show quests", config.showQuests)
		if newShowQuests ~= config.showQuests then
			config.showQuests = newShowQuests
			if targetPlayer then
				camera:showQuestsForPlayerById(targetPlayer.playerId, config.showQuests)
			end
		end

		clipEverythingBeforePlayer = Gui.checkbox("Clip Everything Before Player", clipEverythingBeforePlayer)
		Gui.setItemTooltip("Useful for far away zoom shots!")
		if clipEverythingBeforePlayer then
			nearClipOffset = Gui.sliderFloat("Near Clip Offset", nearClipOffset, -200, 200)
		else
			local newNearClippingPlane = Gui.sliderFloat("Near Clipping Plane", nearClippingPlane, 1, 100)
			if newNearClippingPlane ~= nearClippingPlane then
				nearClippingPlane = newNearClippingPlane
			end
		end
		if Gui.treeNode("Orbit Settings") then
			orbitRadius = Gui.sliderFloat("Orbit Radius", orbitRadius, 0, 1000)
			cameraDirection = Gui.sliderFloat3("Camera Direction", cameraDirection, -1, 1)
			cameraDirection = cameraDirection:getSafeNormal()
			orbitHeight = Gui.sliderFloat("Orbit Height", orbitHeight, 0, 1000)
			lookAheadDistance = Gui.sliderFloat("Look Ahead Distance", lookAheadDistance, 0, 300)
			smoothing = Gui.sliderFloat("Smoothing", smoothing, 0, 1)
			Gui.treePop()
		end
		if Gui.treeNode("Post Processing Settings") then
			enableDynamicDof = Gui.checkbox("Enable Dynamic Depth Of Field", enableDynamicDof)
			if not enableDynamicDof then
				Gui.beginDisabled()
			end
			postProcessSettings.depthOfFieldFstop = Gui.sliderFloat("Depth of Field Fstop", postProcessSettings.depthOfFieldFstop, 0, 6)
			postProcessSettings.depthOfFieldSensorWidth =
				Gui.sliderFloat("Depth of Field Sensor Width", postProcessSettings.depthOfFieldSensorWidth, 0, 100)
			if not enableDynamicDof then
				Gui.endDisabled()
			end
			postProcessSettings.motionBlurAmount = Gui.sliderFloat("Motion Blur Amount", postProcessSettings.motionBlurAmount, 0, 1)
			postProcessSettings.vignetteIntensity = Gui.sliderFloat("Vignette Intensity", postProcessSettings.vignetteIntensity, 0, 1)
			Gui.treePop()
		end
		if Gui.treeNode("Other Settings") then
			kbMoveSensitivity = Gui.sliderFloat("Keyboard Move Sensitivity", kbMoveSensitivity, 5, 20)
			gpMoveSensitivity = Gui.sliderFloat("Gamepad Move Sensitivity", gpMoveSensitivity, 5, 20)
			mouseWheelSensitivity = Gui.sliderFloat("Mouse Wheel Sensitivity", mouseWheelSensitivity, 10, 100)
			fovRotSpeedMultiplier = Gui.sliderFloat("FOV Rotation Speed Multiplier", fovRotSpeedMultiplier, 1, 3)
			mouseSensitivity = Gui.sliderFloat("Mouse Sensitivity", mouseSensitivity, 0.5, 6)
			manualOrbitSmoothingMultiplier = Gui.sliderFloat("Manual Orbit Smoothing Multiplier", manualOrbitSmoothingMultiplier, 0, 1)
			Gui.treePop()
		end
		Gui.unindent()
		Gui.newLine()
	end

	if Gui.button("Save Config") then
		saveConfig()
	end
end

function main()
	camera.positionSmoothing = 0

	-- Add default values to any keys that don't exist in the config file
	initializeConfig({
		followMode = 1,
		showNameTags = true,
		fieldOfView = 90,
		showQuests = true,
	})
end

local function setTargetPlayer(player: BasicPlayer?)
	if targetPlayer and player and targetPlayer.playerId == player.playerId then
		return -- No need to change if it's the same player
	end
	if config.showQuests then
		if targetPlayer then
			camera:showQuestsForPlayerById(targetPlayer.playerId, false)
		end
		if player then
			camera:showQuestsForPlayerById(player.playerId, true)
		end
	end

	targetPlayer = player
end

function onTransitionBegin()
	camera.nearClippingPlane = nearClippingPlane
	setTargetPlayer(findClosestPlayer(camera.position, getAllPlayers()))
end

function previousPlayer(players: { BasicPlayer })
	local targetPlayerIndex = getPlayerIndex(targetPlayer) - 1
	if targetPlayerIndex < 1 then
		targetPlayerIndex = #players
	end
	setTargetPlayer(players[targetPlayerIndex])
end

function nextPlayer(players)
	local targetPlayerIndex = getPlayerIndex(targetPlayer) + 1
	if targetPlayerIndex > #players then
		targetPlayerIndex = 1
	end
	setTargetPlayer(players[targetPlayerIndex])
end

function projectVectorOntoPlane(vec: Vec3, normal: Vec3)
	local normalizedNormal = normal:getSafeNormal()
	local dot1 = vec:dot(normalizedNormal)
	local proj = normalizedNormal * dot1
	local answer = vec - proj
	return answer
end

function findPlayerInDirection(start: Vec3, direction: Vec3, players: { BasicPlayer }): BasicPlayer?
	local closestPlayer = players[1]
	local largestDotProduct = -1
	local normalizedDirection = direction:getSafeNormal()
	for i = 1, #players do
		local player = players[i]
		local playerObj = getPlayer(player)
		local rayToPlayer = playerObj and (playerObj.head.position - start):getSafeNormal() or Vec3.new(0, 0, 0)
		local dotProduct = rayToPlayer:dot(normalizedDirection)
		if dotProduct > largestDotProduct then
			closestPlayer = player
			largestDotProduct = dotProduct
		end
	end
	if largestDotProduct > math.cos(3.14 * playerClickSensitivityDegrees / 180) then
		return closestPlayer
	else
		return nil
	end
end

function findClosestPlayer(pos: Vec3, players: { BasicPlayer }): BasicPlayer?
	if #players < 1 then
		return nil
	end
	local closestPlayer = players[1]
	local closestPlayerObj = getPlayer(players[1])
	if closestPlayerObj == nil then
		return nil
	end
	local closestDistance = Vec3.distance(pos, closestPlayerObj.head.position)
	for i = 1, #players do
		local player = players[i]
		local playerObj = getPlayer(player)
		if playerObj == nil then
			continue
		end
		local distance = Vec3.distance(pos, playerObj.head.position)
		print(playerObj.playerName .. " distance: " .. distance)
		if distance < closestDistance then
			closestPlayer = player
			closestDistance = distance
		end
	end

	return closestPlayer
end

function findPlayerByName(name: string, players: { BasicPlayer }): BasicPlayer?
	for i = 1, #players do
		local player = players[i]
		local playerObj = getPlayer(player)
		if playerObj and playerObj.playerName == name then
			return player
		end
	end
	return nil
end

function tick(dt)
	local players = getAllPlayers()
	if #players == 0 then
		return
	end
	if targetPlayer == nil or getPlayer(targetPlayer) == nil then
		setTargetPlayer(players[1])
	end
	if Input.getKeyDown(previousPlayerKb) or Input.getKeyDown(previousPlayerGp) then
		previousPlayer(players)
	elseif Input.getKeyDown(nextPlayerKb) or Input.getKeyDown(nextPlayerGp) then
		nextPlayer(players)
	end

	-- Click on players to switch to spectating them
	if Input.getKeyDown(Input.Key.LeftMouseButton) then
		local hit = camera:castRayFromMouse()
		if hit.successful then
			local rayDirection = hit.position - camera.position
			local closestPlayer = findPlayerInDirection(camera.position, rayDirection, players)
			if closestPlayer then
				setTargetPlayer(closestPlayer)
			end
		end
	end

	local target = getPlayer(targetPlayer)
	local distanceChangeInput = 0

	if Input.getKey(Input.Key.Down) then
		distanceChangeInput += kbMoveSensitivity
	end
	if Input.getKey(Input.Key.Up) then
		distanceChangeInput -= kbMoveSensitivity
	end
	distanceChangeInput -= Input.getAnalog(Input.Gamepad.LeftY) * gpMoveSensitivity
	if Input.getKey(Input.Key.LeftShift) or Input.getKey(Input.Key.RightShift) then
		config.fieldOfView += Input.getAnalog(Input.Key.MouseWheelAxis) * -mouseWheelSensitivity * 0.1
		config.fieldOfView = math.min(math.max(config.fieldOfView, 5), 170)
	else
		distanceChangeInput += Input.getAnalog(Input.Key.MouseWheelAxis) * -mouseWheelSensitivity
	end

	orbitRadius += distanceChangeInput
	local mouse = Input.getMouseDelta()
	local rightAnalog = Vec2.new(Input.getAnalog(Input.Gamepad.RightX), Input.getAnalog(Input.Gamepad.RightY))

	if orbitRadius <= 0 then
		config.followMode = 1
		orbitRadius = 0
	end

	if not target then
		return
	end

	if config.followMode == 1 then
		-- POV
		camera.hideNearestHead = true
		camera.positionSmoothing = 0
		camera.rotationSmoothing = 0

		if distanceChangeInput > 0 then
			config.followMode = 2
			orbitRadius = 10
		end

		camera.position = target.head.position
		camera.rotation = target.head.rotation
	else
		-- Orbiting
		camera.hideNearestHead = false
		camera.positionSmoothing = smoothing
		camera.rotationSmoothing = smoothing

		-- Toggle between Auto and Manual Orbit
		if Input.getKeyDown(Input.Key.SpaceBar) then
			if config.followMode == 2 then
				config.followMode = 3
			elseif config.followMode == 3 then
				config.followMode = 2
			end
		end

		if config.followMode == 2 then
			-- Automatic 3rd person view of player
			local lookTarget = target.head.position + target.head.rotation:getForwardVector() * lookAheadDistance

			if target.velocity:length() <= threshold then
				cameraDirection = -target.head.rotation:getForwardVector()
			else
				cameraDirection = -target.velocity:getSafeNormal()
			end
			cameraDirection = projectVectorOntoPlane(cameraDirection, gravity.upDirection)
			cameraDirectionEuler = (gravity.upRotation:inverse() * Quat.fromXZ(-cameraDirection, gravity.upDirection)):euler()

			-- Collison detection
			local rayEnd = target.head.position + cameraDirection * orbitRadius + gravity.upDirection * orbitHeight
			local hit = camera:castRay(target.head.position, rayEnd)
			if hit.successful then
				rayEnd = (hit.position + target.head.position) / 2
			else
				camera.positionSmoothing = smoothing
			end

			if Input.getKey(Input.Key.RightMouseButton) or rightAnalog:length() > 0.1 then
				config.followMode = 3
			end

			camera.position = rayEnd
			camera:lookAt(lookTarget, gravity.upDirection)
		else
			-- Manually orbit player
			camera.positionSmoothing = manualOrbitSmoothingMultiplier * smoothing
			camera.rotationSmoothing = manualOrbitSmoothingMultiplier * smoothing

			local adjustedMouseSensitivity = fovRotSpeedMultiplier * (camera.fieldOfView - 90) / 90 + mouseSensitivity
			local adjustedRotSpeed = fovRotSpeedMultiplier * (camera.fieldOfView - 90) / 90 + rotSpeed

			-- Mouse Rotation
			local lookInputTargetDelta = Vec3.zeroVector
			if Input.getKey(Input.Key.RightMouseButton) then
				lookInputTargetDelta.z += mouse.x * adjustedMouseSensitivity
				lookInputTargetDelta.y += mouse.y * adjustedMouseSensitivity
			end
			-- Keyboard
			if Input.getKey(yawRightKey) then
				lookInputTargetDelta.z += adjustedRotSpeed * dt
			end
			if Input.getKey(yawLeftKey) then
				lookInputTargetDelta.z -= adjustedRotSpeed * dt
			end
			if Input.getKey(pitchUpKey) then
				lookInputTargetDelta.y += adjustedRotSpeed * dt
			end
			if Input.getKey(pitchDownKey) then
				lookInputTargetDelta.y -= adjustedRotSpeed * dt
			end
			-- Gamepad
			lookInputTargetDelta.z += rightAnalog.x * adjustedRotSpeed * dt
			lookInputTargetDelta.y -= rightAnalog.y * adjustedRotSpeed * dt

			cameraDirectionEuler += lookInputTargetDelta
			-- Clamp rotation
			if cameraDirectionEuler.y > 89.9 then
				cameraDirectionEuler.y = 89.9
			end
			if cameraDirectionEuler.y < -89.9 then
				cameraDirectionEuler.y = -89.9
			end

			cameraDirection = gravity.upRotation:rotateVector(
				Quat.fromEuler(cameraDirectionEuler.x, cameraDirectionEuler.y, cameraDirectionEuler.z):getForwardVector()
			) * -1
			camera.position = target.head.position + cameraDirection * orbitRadius
			camera:lookAt(target.head.position, gravity.upDirection)
		end
	end

	local distToTargetPlayer = Vec3.distance(camera:getSmoothedPosition(), target.head.position)
	if clipEverythingBeforePlayer then
		nearClippingPlane = distToTargetPlayer + nearClipOffset
	end
	camera.nearClippingPlane = nearClippingPlane
	if enableDynamicDof and config.followMode > 1 then -- Dynamic DOF is only for orbit mode since it focuses on the player
		postProcessSettings.depthOfFieldFocalDistance = distToTargetPlayer - 12 -- 12cm is approx the radius of the head
	else
		postProcessSettings.depthOfFieldFocalDistance = 0
	end

	camera.fieldOfView = config.fieldOfView
	camera.showNameTags = config.showNameTags
end

function onMessageReceived(followMode: number, player: BasicPlayer)
	config.followMode = followMode
	setTargetPlayer(player)
end
