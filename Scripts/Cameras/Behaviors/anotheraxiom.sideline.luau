--!strict
-- @name Sideline Camera
-- @description Sideline Camera for Driftball
-- @author Another Axiom

metadata = {
	name = "Sideline Camera",
	description = "Sideline Camera for Driftball",
	author = "Another Axiom",
	defaultKeybind = "",
}

local arenaBlacklist = { TKB_Quest_Full = true, TKB_Annex_Demo_Full_2 = true }
-- Rough interior measurements for use only for camera heuristics
local arenaMax = Vec3.new(2271, 3300, 1350)
local arenaMin = Vec3.new(-2271, -3300, -100)
local debugDrawArena = false

-- sideline zone
local debugDrawSideline = false
local xOffset = 2100
local minZ = 300
local maxZ = 1115
local maxY = 1300

-- special corner zone
local debugDrawCorner = false
local cornerXOffset = 400 -- move the camera in the x direction by up to this amount
local cornerStartX = 1400
local cornerEndX = 2300
local cornerStartY = 1250
local cornerEndY = 3200

-- Keep the ball higher in frame over a certain height
local minPanDownHeight = 500
local maxPanDownHeight = 1350
local panDownAmount = 20

-- fov settings
local maxFov = 85
local minFov = 60
local maxFovDepth = 1000
local minFovDepth = 4000

-- todo: make a transform?
local overviewPosition = Vec3.new(0, 0, 5500)
local overviewRotation = Quat.fromEuler(0, -90, 180)
local overviewFov = 70

local relevantPlayerRadius = 1200

type BallRef = { frameIndex: number, ballIndex: number, ballObject: ReplayBall }?
type BasicPlayer = {
	playerId: number,
	frameIndex: number, -- 1 = live game. 2, 3, 4 ... = replay index
}

local selectedGamemodeIndex = 1
local targetBall = nil
local freecam = false

local playerClickSensitivityDegrees = 5

function lerp(a: number, b: number, t: number): number
	return a * (1.0 - t) + b * t
end

function projectToCamera(pos: Vec3, dist: number): Vec3
	local cameraToPoint = pos - camera.position
	return camera.position + cameraToPoint:getSafeNormal() * dist
end

function getAllPlayers(): { BasicPlayer }
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

function getAllPlayersWithinRadius(center: Vec3, radius: number): { BasicPlayer }
	local playerList = {}
	if radius <= 0 then
		return playerList
	end
	local frames = getAllGameData()
	for i = 1, #frames do
		local players = frames[i].players
		for j = 1, #players do
			if players[j].head.position:distance(center) <= radius then
				table.insert(playerList, { playerId = players[j].playerId, frameIndex = i })
			end
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

function getClosestBall(targetPos: Vec3): BallRef
	local closestBall = nil
	local closestDistance = 0
	local frames = getAllGameData()
	for i = 1, #frames do
		local balls = frames[i].balls
		for j = 1, #balls do
			local ballDistance = balls[j].transform.position:distance(targetPos)
			if not closestBall or ballDistance < closestDistance then
				closestBall = { frameIndex = i, ballIndex = j, ballObject = balls[j] }
				closestDistance = ballDistance
			end
		end
	end
	return closestBall
end

function updateBallRef(ball: BallRef, arenaCenter: Vec3): BallRef
	local frames = getAllGameData()
	if ball and ball.frameIndex <= #frames then
		local balls = getAllGameData()[ball.frameIndex].balls
		if ball.ballIndex <= #balls then
			ball.ballObject = balls[ball.ballIndex]
			if ball.ballObject.transform.position:distance(arenaCenter) <= 4500 then
				return ball
			end
		end
	end
	ball = getClosestBall(arenaCenter)
	return ball
end

function getAllBallsInArena(arenaCenter: Vec3, arenaRot: Quat): { BallRef }
	local ballsInArena = {}
	local frames = getAllGameData()
	for i = 1, #frames do
		local balls = frames[i].balls
		for j = 1, #balls do
			if isPointInArena(arenaCenter, arenaRot, balls[j].transform.position) then
				table.insert(ballsInArena, { frameIndex = i, ballIndex = j, ballObject = balls[j] })
			end
		end
	end
	return ballsInArena
end

function getFirstBallAtArena(arenaCenter: Vec3, arenaRot: Quat): BallRef?
	local ballsInArena = getAllBallsInArena(arenaCenter, arenaRot)
	local ball = nil
	if #ballsInArena > 0 then
		ball = ballsInArena[1]
	else
		ball = getClosestBall(arenaCenter)
	end
	return ball
end

function drawQuad(p1: Vec3, p2: Vec3, p3: Vec3, p4: Vec3, rgb: Vec3)
	local color = LinearColor.new(rgb.x, rgb.y, rgb.z, 0.35)
	WorldDraw.drawTriangle(p1, p2, p3, color, 0)
	WorldDraw.drawTriangle(p1, p2, p4, color, 0)
end

function drawDenseWireframe(points: { Vec3 }, rgb: Vec3, thickness: number)
	for i, point1 in points do
		for j, point2 in points do
			if j ~= i then
				WorldDraw.drawLine(point1, point2, rgb.x, rgb.y, rgb.z, thickness, 0)
			end
		end
	end
end

function isTKBModule(slotId: string): boolean
	if arenaBlacklist[slotId] then
		return false
	end
	if slotId:sub(1, 4) ~= "TKB_" then
		return false
	end
	return true
end

function toArenaSpace(arenaCenter: Vec3, arenaRot: Quat, worldPoint: Vec3)
	return arenaRot:inverse():rotateVector(worldPoint - arenaCenter)
end

function toWorldSpace(arenaCenter: Vec3, arenaRot: Quat, arenaPoint: Vec3)
	return arenaCenter + arenaRot:rotateVector(arenaPoint)
end

function isPointInArena(arenaCenter: Vec3, arenaRot: Quat, point: Vec3)
	local arenaPoint = toArenaSpace(arenaCenter, arenaRot, point)
	if
		arenaPoint.x >= arenaMin.x
		and arenaPoint.y >= arenaMin.y
		and arenaPoint.z >= arenaMin.z
		and arenaPoint.x <= arenaMax.x
		and arenaPoint.y <= arenaMax.y
		and arenaPoint.z <= arenaMax.z
	then
		return true
	end
	return false
end

function findBallInDirection(start: Vec3, direction: Vec3, balls: { BallRef }): BallRef?
	local closestBall = balls[1]
	local largestDotProduct = -1
	local normalizedDirection = direction:getSafeNormal()
	for i = 1, #balls do
		local ball = balls[i]
		local rayToBall = ball and (ball.ballObject.transform.position - start):getSafeNormal() or Vec3.new(0, 0, 0)
		local dotProduct = rayToBall:dot(normalizedDirection)
		if dotProduct > largestDotProduct then
			closestBall = ball
			largestDotProduct = dotProduct
		end
	end
	if largestDotProduct > math.cos(3.14 * playerClickSensitivityDegrees / 180) then
		return closestBall
	else
		return nil
	end
end

function progressBetweenValues(t: number, min: number, max: number)
	return math.clamp((t - min) / (max - min), 0, 1)
end

function main() end

function onGui()
	local allGamemodes = SpectatorGamemodes.listGamemodes()

	if selectedGamemodeIndex > #allGamemodes then
		selectedGamemodeIndex = 1
	end

	local currrentGm = allGamemodes[selectedGamemodeIndex]

	Gui.text("Currently Spectating: " .. currrentGm:getSlotId())

	if Gui.beginListBox("Arena List") then
		for i, gm in allGamemodes do
			Gui.pushId(tostring(i))

			local slotId = gm:getSlotId()
			if not isTKBModule(slotId) then
				Gui.popId()
				continue
			end

			local arenaName = slotId:sub(5, #slotId + 1)
			local arenaCenter = gm.transform.position
			local arenaRot = gm.transform.rotation
			if Gui.selectable(arenaName, selectedGamemodeIndex == i) then
				targetBall = getFirstBallAtArena(arenaCenter, arenaRot)
				selectedGamemodeIndex = i
			end
			Gui.popId()
		end
		Gui.endListBox()
	end
	Gui.newLine()

	if Gui.button("Select Ball") then
		targetBall = nil
	end
	Gui.sameLine()
	if Gui.button("Next Ball") then
		local balls = getAllBallsInArena(currrentGm.transform.position, currrentGm.transform.rotation)
		for i, ball in balls do
			if not ball then
				continue
			end
			if not targetBall then
				targetBall = ball
				continue
			end
			if targetBall.ballIndex == ball.ballIndex and targetBall.frameIndex == ball.frameIndex then
				if i == #balls then
					targetBall = balls[1]
				else
					targetBall = balls[i + 1]
				end
				continue
			end
		end
		if #balls <= 0 then
			targetBall = getClosestBall(currrentGm.transform.position)
		else
			targetBall = balls[math.random(1, #balls)]
		end
	end
	if not targetBall then
		Gui.sameLine()
		Gui.text("Select a ball to enter sideline view")
	end
	Gui.newLine()

	if Gui.collapsingHeader("Tunings") then
		Gui.indent()

		Gui.text("Smoothing")
		camera.positionSmoothing = Gui.sliderFloat("Position Smoothing", camera.positionSmoothing, 0, 1)
		camera.rotationSmoothing = Gui.sliderFloat("Rotation Smoothing", camera.rotationSmoothing, 0, 1)
		camera.fieldOfViewSmoothing = Gui.sliderFloat("Field Of View Smoothing", camera.fieldOfViewSmoothing, 0, 1)
		Gui.newLine()

		Gui.text("Field of view limits")
		maxFov = Gui.sliderFloat("Max Fov", maxFov, 10, 150)
		minFov = Gui.sliderFloat("Min Fov", minFov, 10, 150)
		Gui.newLine()

		Gui.text("Rough Arena Dimensions")
		debugDrawArena = Gui.checkbox("Debug Draw Arena", debugDrawArena)
		arenaMin = Gui.sliderFloat3("Arena Min", arenaMin, -1000, 0)
		arenaMax = Gui.sliderFloat3("Arena Max", arenaMax, 0, 1000)
		Gui.newLine()

		Gui.text("Sideline Zone")
		debugDrawSideline = Gui.checkbox("Debug Draw Sideline", debugDrawSideline)
		xOffset = Gui.sliderFloat("Sideline depth", xOffset, 0, 4000)
		minZ = Gui.sliderFloat("Sideline bottom height", minZ, -1000, 2000)
		maxZ = Gui.sliderFloat("Sideline top height", maxZ, -1000, 2000)
		maxY = Gui.sliderFloat("SidelineWidth", maxY * 2, 0, 5000) / 2
		Gui.newLine()

		Gui.text("Special Corner Adjustment")
		debugDrawCorner = Gui.checkbox("Debug Draw Corner", debugDrawCorner)
		cornerXOffset = Gui.sliderFloat("Offset Amount", cornerXOffset, -1000, 3000)
		cornerStartX = Gui.sliderFloat("cornerStartX", cornerStartX, -1000, 6000)
		cornerEndX = Gui.sliderFloat("cornerEndX", cornerEndX, -1000, 6000)
		cornerStartY = Gui.sliderFloat("cornerStartY", cornerStartY, -1000, 6000)
		cornerEndY = Gui.sliderFloat("cornerEndY", cornerEndY, -1000, 6000)
		Gui.newLine()

		Gui.text("Pan down on high balls")
		minPanDownHeight = Gui.sliderFloat("Min Pan Down Height", minPanDownHeight, 0, 1500)
		maxPanDownHeight = Gui.sliderFloat("Max Pan Down Height", maxPanDownHeight, 0, 1500)
		panDownAmount = Gui.sliderFloat("Pan Down Amount in Degrees", panDownAmount, 0, 90)
		Gui.newLine()

		freecam = Gui.checkbox("Enable freecam", freecam)

		Gui.unindent()
	end
end

function tick(dt: number)
	WorldDraw.clear()
	if freecam then
		camera:followCamera(getCameraById("anotheraxiom.freecam"))
	else
		camera:followCamera(nil)
	end
	local allGamemodes = SpectatorGamemodes.listGamemodes()

	-- search for the first driftball arena
	if not isTKBModule(allGamemodes[selectedGamemodeIndex]:getSlotId()) then
		selectedGamemodeIndex += 1
		if selectedGamemodeIndex > #allGamemodes then
			selectedGamemodeIndex = 1
		end
		targetBall = getFirstBallAtArena(
			allGamemodes[selectedGamemodeIndex].transform.position,
			allGamemodes[selectedGamemodeIndex].transform.rotation
		)
	end

	local arenaCenter = allGamemodes[selectedGamemodeIndex].transform.position
	local arenaRotation = allGamemodes[selectedGamemodeIndex].transform.rotation
	local arenaUp = arenaRotation:getUpVector()

	-- if there's no ball selected, select a ball from top down
	if not targetBall then
		camera.position = toWorldSpace(arenaCenter, arenaRotation, overviewPosition)
		camera.rotation = arenaRotation * overviewRotation
		camera.fieldOfView = overviewFov
		camera.nearClippingPlane = overviewPosition.z - arenaMax.z

		local allBalls = getAllBallsInArena(arenaCenter, arenaRotation)

		local hit = camera:castRayFromMouse()
		if hit.successful then
			local rayDirection = hit.position - camera.position
			local hoveredBall = findBallInDirection(camera.position, rayDirection, allBalls)
			if hoveredBall then
				if Input.getKeyDown(Input.Key.LeftMouseButton) then
					targetBall = hoveredBall
				end
				WorldDraw.drawPoint(hoveredBall.ballObject.transform.position, 0, 1, 1, 80, 0) -- selection outline
			else
				WorldDraw.drawPoint(hit.position, 1, 1, 1, 10, 0) -- cursor
			end
		end

		for i, ball in allBalls do
			if ball then
				WorldDraw.drawPoint(ball.ballObject.transform.position, 1, 1, 1, 50, 0)
			end
		end
		if targetBall then
			WorldDraw.drawPoint(targetBall.ballObject.transform.position, 1, 0, 0, 200, 0)
		end
		return
	else
		camera.nearClippingPlane = 1

		targetBall = updateBallRef(targetBall, arenaCenter)
	end

	-- Sideline cam logic
	local ballPosWorldSpace = targetBall.ballObject.transform.position
	local ballPosArenaSpace = toArenaSpace(arenaCenter, arenaRotation, ballPosWorldSpace)
	local ballProgressY = progressBetweenValues(ballPosArenaSpace.y, arenaMin.y, arenaMax.y)
	local ballProgressZ = progressBetweenValues(ballPosArenaSpace.z, arenaMin.z, arenaMax.z)

	-- Movement
	local arenaCameraPosition = Vec3.new(xOffset, 0, 0)
	arenaCameraPosition.y = lerp(-maxY, maxY, ballProgressY)
	arenaCameraPosition.z = lerp(minZ, maxZ, ballProgressZ)

	-- Corner adjustment
	local ballCornerX = progressBetweenValues(ballPosArenaSpace.x, cornerStartX, cornerEndX)
	local ballCornerY = math.max(
		progressBetweenValues(ballPosArenaSpace.y, cornerStartY, cornerEndY),
		progressBetweenValues(ballPosArenaSpace.y, -cornerEndY, -cornerStartY)
	)
	local xCornerAdjustmentAmount = lerp(0, cornerXOffset, (ballCornerX * ballCornerY))

	arenaCameraPosition.x = xOffset - xCornerAdjustmentAmount

	camera.position = toWorldSpace(arenaCenter, arenaRotation, arenaCameraPosition)

	-- rotation
	local relevantPlayers = getAllPlayersWithinRadius(ballPosWorldSpace, relevantPlayerRadius)
	local lookTargetOffset = Vec3.zeroVector
	if #relevantPlayers > 0 then
		for i, player in relevantPlayers do
			local replayPlayer = getPlayer(player)
			if replayPlayer then
				local ballToPlayer = replayPlayer.head.position - ballPosWorldSpace
				local distancedBasedScale = 1 - progressBetweenValues(ballToPlayer:length(), 0, relevantPlayerRadius)
				local scaledBallToPlayer = ballToPlayer * distancedBasedScale / #relevantPlayers
				lookTargetOffset += scaledBallToPlayer
			end
		end
	end
	camera:lookAt(ballPosWorldSpace + (lookTargetOffset / 2), arenaUp)
	local panDownProgress = progressBetweenValues(ballPosArenaSpace.z, minPanDownHeight, maxPanDownHeight)
	local cameraRotEuler = camera.rotation:euler()
	cameraRotEuler.y -= panDownProgress * panDownAmount
	camera.rotation = Quat.fromEuler(cameraRotEuler.x, cameraRotEuler.y, cameraRotEuler.z)

	-- zoooming
	local ballDepth = math.clamp(ballPosWorldSpace:distance(camera.position) / (minFovDepth - maxFovDepth), 0, 1)
	camera.fieldOfView = lerp(maxFov, minFov, ballDepth)

	-- Debug Drawing
	if debugDrawSideline then
		local sidelineP1 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(xOffset, -maxY, minZ))
		local sidelineP2 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(xOffset, maxY, maxZ))
		local sidelineP3 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(xOffset, maxY, minZ))
		local sidelineP4 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(xOffset, -maxY, maxZ))
		drawQuad(sidelineP1, sidelineP2, sidelineP3, sidelineP4, Vec3.new(0, 0, 1))
	end
	if debugDrawCorner then
		local cornerP1 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(cornerStartX, cornerStartY, 300))
		local cornerP2 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(cornerEndX, cornerEndY, 300))
		local cornerP3 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(cornerStartX, cornerEndY, 300))
		local cornerP4 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(cornerEndX, cornerStartY, 300))
		drawQuad(cornerP1, cornerP2, cornerP3, cornerP4, Vec3.new(1, 0, 0))
		local cornerP1_2 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(cornerStartX, -cornerStartY, 300))
		local cornerP2_2 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(cornerEndX, -cornerEndY, 300))
		local cornerP3_2 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(cornerStartX, -cornerEndY, 300))
		local cornerP4_2 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(cornerEndX, -cornerStartY, 300))
		drawQuad(cornerP1_2, cornerP2_2, cornerP3_2, cornerP4_2, Vec3.new(1, 0, 0))
	end
	if debugDrawArena then
		local p1 = toWorldSpace(arenaCenter, arenaRotation, arenaMin)
		local p2 = toWorldSpace(arenaCenter, arenaRotation, arenaMax)
		local p3 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(arenaMin.x, arenaMin.y, arenaMax.z))
		local p4 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(arenaMin.x, arenaMax.y, arenaMin.z))
		local p5 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(arenaMin.x, arenaMax.y, arenaMax.z))
		local p6 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(arenaMax.x, arenaMin.y, arenaMin.z))
		local p7 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(arenaMax.x, arenaMin.y, arenaMax.z))
		local p8 = toWorldSpace(arenaCenter, arenaRotation, Vec3.new(arenaMax.x, arenaMax.y, arenaMin.z))
		drawDenseWireframe({ p1, p2, p3, p4, p5, p6, p7, p8 }, Vec3.new(0, 1, 0), 10)
	end
end
