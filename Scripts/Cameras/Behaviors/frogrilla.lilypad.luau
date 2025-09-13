metadata = {
	name = "Lilypad",
	description = "An updated version of my physics scripts which supports a host of new features",
	author = "Frogrilla",
	defaultKeybind = "B",
}

local BALL_TYPE_RATIOS = {
	1,
	1/2.6975,
	1,
	1,
	1,
	1,
	1,
	1,
	0.5
}

local FROZEN = false
local USE_EXTRA_RAYS = false

local SHOW_COLLIDERS = true
local SHOW_VELOCITY = true

local DO_GRABBING = true
local ONLY_OWNER_GRAB = true
local GRAB_OFFSET = Vec3.new(0, 0, 30)

local DO_PLAYER_COLLISION = true
local DO_DRIFTBALL_COLLISION = true
local DO_SPECTATOR_COLLISION = true
local USE_DRIFTBALL_SIZE = true

local ACCELERATION = 1000

local FACE_VELOCITY = false

local UPDATE_CUSTOM_GRAVITY_EVERY_BOUNCE = false
local usingCustomGravity = false -- Press LMB to set - RMB to reset
local customGravity = Quat.identity

-- Logging -------------------------------------------------------------------

local DO_DEBUG_LOGGING = false

function debugLog(message: string)
	if not DO_DEBUG_LOGGING then
		return
	end
	print(message)
end

-- Maths ----------------------------------------------------------------------
function lerp(a: number, b: number, t: number): number
	return (a * (1 - t)) + (b * t)
end

-- Colour management ----------------------------------------------------------
type Colour = {
	r: number,
	g: number,
	b: number,
}

local Colour = {} :: Colour
Colour.__index = Colour

function Colour.new(r: number, g: number, b: number): Colour
	local colour = {} :: Colour
	setmetatable(colour, Colour)
	colour.r = r
	colour.g = g
	colour.b = b
	return colour
end

function Colour:__tostring(): string
	return "R: " .. self.r .. " G: " .. self.g .. " B: " .. self.b
end

function Colour.lerp(a: Colour, b: Colour, t: number): Colour
	return Colour.new(lerp(a.r, b.r, t), lerp(a.g, b.g, t), lerp(a.b, b.b, t))
end

-- Colour constants
Colour.RED = Colour.new(1, 0, 0)
Colour.YELLOW = Colour.new(1, 1, 0)
Colour.GREEN = Colour.new(0, 1, 0)
Colour.CYAN = Colour.new(0, 1, 1)
Colour.BLUE = Colour.new(0, 0, 1)
Colour.MAGENTA = Colour.new(1, 0, 1)
Colour.WHITE = Colour.new(1, 1, 1)
Colour.BLACK = Colour.new(0, 0, 0)
Colour.GREY = Colour.new(0.5, 0.5, 0.5)

-- Debug / drawing  -----------------------------------------------------------
function drawCircle(
	position: Vec3,
	radius: number,
	direction: Vec3 | nil,
	colour: Colour,
	lineWidth: number,
	lifetime: number
)
	if not direction then
		direction = camera:getSmoothedRotation():getForwardVector()
	end
	assert(direction, "Direction should not be nil")
	local arbritaryVector = if direction ~= Vec3.upVector then Vec3.upVector else Vec3.rightVector
	local upDirection = direction:cross(arbritaryVector):normalize()
	local rightDirection = direction:cross(upDirection):normalize()
	local previousPoint = nil
	for theta = 0, math.pi * 2, math.pi / 64 do
		local pointPos = upDirection * math.sin(theta) + rightDirection * math.cos(theta)
		if previousPoint then
			WorldDraw.drawLine(
				position + (previousPoint * radius),
				position + (pointPos * radius),
				colour.r,
				colour.g,
				colour.b,
				lineWidth,
				lifetime
			)
		end
		previousPoint = pointPos
	end
end

-- Player Management ----------------------------------------------------------
type Player = {
	name: string,
	id: number,
	replay: ReplayPlayer,
	blocked: boolean,
}

local Player = {} :: Player
Player.__index = Player

function Player.new(replayPlayer: ReplayPlayer): Player
	local player = {} :: Player
	setmetatable(player, Player)
	player.name = replayPlayer.playerName
	player.id = replayPlayer.playerId
	player.replay = replayPlayer
	player.blocked = false
	return player
end

function Player:handWorldPos(rightHand: boolean): Vec3 | nil
	if not self.replay then
		return nil
	end
	return self.replay.root.position
		+ self.replay.root.rotation:rotateVector(
			if rightHand then self.replay.rightHand.position else self.replay.leftHand.position
		)
end

function Player:handWorldRot(rightHand: boolean): Vec3 | nil
	if not self.replay then
		return nil
	end
	return self.replay.root.rotation
		* if rightHand then self.replay.rightHand.rotation else self.replay.leftHand.rotation
end

-- Player list
local players = {}

-- Which replay frame's players is used
local frameIndex = 1

-- Player targetted for collision and grabbing
local targetPlayerIndex = 0

-- Player able to summon the camera
local ownerPlayerIndex = 0

-- Player selected on the GUI
local guiPlayerIndex = 0

function updatePlayers(gameData: { ReplayFrame })
	updateframeIndex(gameData, frameIndex)

	local frame = gameData[frameIndex]
	for i = 1, #players do
		local player = players[i]
		if player then
			local replay = frame:getPlayerById(player.id)
			if replay then
				player.replay = replay
				if player.name ~= replay.playerName then
					player.name = replay.playerName
					debugLog("Player at index " .. i .. " name updated to " .. player.name)
				end
				continue
			end
		end

		removePlayerAtIndex(i)
		i -= 1
	end

	for i = #players + 1, #frame.players do
		if not frame.players[i] then
			continue
		end
		table.insert(players, Player.new(frame.players[i]))
		debugLog("Added player " .. frame.players[i].playerName .. " at index " .. i)
	end
end

-- Returns true if the frame index changed
function updateframeIndex(gameData: { ReplayFrame }, index: number): boolean
	index = math.min(index, #gameData)
	if frameIndex == index then
		return false
	end
	frameIndex = index
	table.clear(players)
	debugLog("Player frame index set to " .. index)
	return true
end

function removePlayerAtIndex(index: number)
	if index <= #players and index > 0 then
		debugLog("Removed player " .. players[index].name .. " at index " .. index)
		table.remove(players, index)
		if index == targetPlayerIndex then
			targetPlayerIndex = 0
		elseif index < targetPlayerIndex then
			targetPlayerIndex -= 1
		end

		if index == ownerPlayerIndex then
			targetPlayerIndex = 0
		elseif index < ownerPlayerIndex then
			ownerPlayerIndex -= 1
		end

		if index == guiPlayerIndex then
			guiPlayerIndex = 0
		elseif index < guiPlayerIndex then
			guiPlayerIndex -= 1
		end
	end
end

function getPlayerAtIndex(index: number): Player | nil
	if index <= #players and index > 0 then
		return players[index]
	end
	return nil
end

function getNearestPlayer(position: Vec3): number
	local nearestPlayerIndex = 0
	local distance = 1000
	for i = 1, #players do
		local player = players[i]
		if player.replay and not player.blocked then
			local playerDist = math.min(
				position:distance(player.replay.root.position),
				position:distance(player:handWorldPos(true)),
				position:distance(player:handWorldPos(false))
			)
			if playerDist < distance then
				nearestPlayerIndex = i
				distance = playerDist
			end
		end
	end
	return nearestPlayerIndex
end

-- Other replay objects -------------------------------------------------------
function getNearestDriftball(position: Vec3, frame: ReplayFrame): ReplayBall | nil
	local nearestBall = nil
	local distance = 1000

	for i = 1, #frame.balls do
		local ball = frame.balls[i]
		local ballDist = position:distance(ball.transform.position)
		if ballDist < distance then
			nearestBall = ball
			distance = ballDist
		end
	end

	return nearestBall
end

function getNearestSpectator(position: Vec3, frame: ReplayFrame): ReplaySpectator | nil
	local nearestCam = nil
	local distance = 1000

	for i = 1, #frame.spectators do
		local cam = frame.spectators[i]
		if cam.isLocalPlayer then
			continue
		end
		local camDist = position:distance(cam.transform.position)
		if camDist < distance then
			nearestCam = cam
			distance = camDist
			nearI = i
		end
	end

	return nearestCam
end

-- Sphere Colliders -----------------------------------------------------------
type SphereCollider = {
	position: Vec3,
	lastPosition: Vec3,
	velocity: Vec3,
	radius: number,
	bounceFactor: number,
	colour: Colour,
}

local SphereCollider = {}
SphereCollider.__index = SphereCollider

function SphereCollider.new(position: Vec3, radius: number, bounceFactor: number, colour: Colour): SphereCollider
	local sphereCollider = {} :: SphereCollider
	sphereCollider.position = position
	sphereCollider.lastPosition = position
	SphereCollider.velocity = Vec3.zeroVector
	sphereCollider.radius = radius
	SphereCollider.bounceFactor = bounceFactor
	sphereCollider.colour = colour
	setmetatable(sphereCollider, SphereCollider)
	return sphereCollider
end

function SphereCollider:setPosition(position: Vec3, dt: number, updateVelocity: boolean)
	self = self :: SphereCollider
	self.lastPosition = self.position
	self.position = position
	if updateVelocity then
		self.velocity = (self.position - self.lastPosition) / dt
	end
end

function SphereCollider:draw(lifetime: number)
	drawCircle(self.position, self.radius, camera.rotation:getForwardVector(), self.colour, 1, lifetime)
end

function SphereCollider:drawVelocity(lifetime: number)
	WorldDraw.drawLine(
		self.position,
		self.position + self.velocity,
		self.colour.r,
		self.colour.g,
		self.colour.b,
		1,
		lifetime
	)
end

local leftHandCollider = SphereCollider.new(Vec3.new(0, 100, 0), 8, 0, Colour.RED)
local rightHandCollider = SphereCollider.new(Vec3.new(0, 200, 0), 8, 0, Colour.GREEN)
local headCollider = SphereCollider.new(Vec3.new(0, 300, 0), 15, 0.1, Colour.BLUE)
local lowerBodyCollider = SphereCollider.new(Vec3.new(0, 400, 0), 12, 0.8, Colour.new(0, 0.5, 0.5))
local upperBodyCollider = SphereCollider.new(Vec3.new(0, 500, 0), 19, 0.8, Colour.new(0, 0.2, 0.8))

local DriftBallCollider = SphereCollider.new(Vec3.new(0, 600, 0), 17, 1, Colour.BLACK)

local SpectatorCollider = SphereCollider.new(Vec3.new(0, 700, 0), 20, 1, Colour.WHITE)

-- Ball Object ----------------------------------------------------------------
type Ball = {
	position: Vec3,
	rotation: Quat,
	velocity: Vec3,
	radius: number,
	bounciness: number,
	floatiness: number,
}

local Ball = {}
Ball.__index = Ball


function Ball.new(position: Vec3, rotation: Quat, radius: number): Ball
	local ball = {} :: Ball
	ball.position = position
	ball.velocity = Vec3.zeroVector
	ball.rotation = rotation
	ball.radius = radius
	ball.bounciness = 0.7
	ball.floatiness = 0
	setmetatable(ball, Ball)
	return ball
end

function Ball:collisionRay(direction: Vec3, bounce: boolean)
	local radiusVector = direction:normalize() * self.radius
	local collisionRay = camera:castRay(self.position - radiusVector, self.position + radiusVector)
	--World.drawLine(self.position - radiusVector, self.position + radiusVector, 1, 0, 0, 1, 0.01)

	if collisionRay.successful then
		self.position = collisionRay.position + (collisionRay.normal * self.radius)
		if bounce then
			local reflectionDistance = collisionRay.normal:dot(direction * -1)
			local reflectionPoint = collisionRay.position + (collisionRay.normal * reflectionDistance)
			local point = collisionRay.position - direction
			local reflectedPoint = point + ((reflectionPoint - point) * 2)
			self.velocity = (reflectedPoint - self.position) * self.bounciness

			if UPDATE_CUSTOM_GRAVITY_EVERY_BOUNCE and collisionRay.normal ~= customGravity:getUpVector()  then
				usingCustomGravity = true
				local dq = Quat.findBetweenVectors(customGravity:getUpVector(), collisionRay.normal)
				customGravity *= dq
				self.rotation *= dq
			end
		else
			-- align ray orientation to the collision for smoother collisions
			-- lets us get away with using less rays
			self.rotation = Quat.fromDirection(collisionRay.normal)
			self.velocity -= radiusVector
			self.velocity *= 0.98
		end
	end
end

function Ball:physicsStep(dt: number)
	self = self :: Ball

	local g = if usingCustomGravity then customGravity:getUpVector() * -gravity.strength else gravity.gravity

	self.velocity += g * dt * (1 - self.floatiness)

	self:collisionRay(self.velocity, true)
	self:collisionRay(self.rotation:getForwardVector() * self.radius, false)
	self:collisionRay(self.rotation:getForwardVector() * -self.radius, false)
	self:collisionRay(self.rotation:getRightVector() * self.radius, false)
	self:collisionRay(self.rotation:getRightVector() * -self.radius, false)
	self:collisionRay(self.rotation:getUpVector() * self.radius, false)
	self:collisionRay(self.rotation:getUpVector() * -self.radius, false)

	if USE_EXTRA_RAYS then
		self:collisionRay(
			(self.rotation:getUpVector() + self.rotation:getRightVector()):normalize() * self.radius,
			false
		)
		self:collisionRay(
			(self.rotation:getUpVector() - self.rotation:getRightVector()):normalize() * self.radius,
			false
		)
		self:collisionRay(
			(self.rotation:getUpVector() + self.rotation:getForwardVector()):normalize() * self.radius,
			false
		)
		self:collisionRay(
			(self.rotation:getUpVector() - self.rotation:getForwardVector()):normalize() * self.radius,
			false
		)
		self:collisionRay(
			(self.rotation:getUpVector() + self.rotation:getRightVector()):normalize() * -self.radius,
			false
		)
		self:collisionRay(
			(self.rotation:getUpVector() - self.rotation:getRightVector()):normalize() * -self.radius,
			false
		)
		self:collisionRay(
			(self.rotation:getUpVector() + self.rotation:getForwardVector()):normalize() * -self.radius,
			false
		)
		self:collisionRay(
			(self.rotation:getUpVector() - self.rotation:getForwardVector()):normalize() * -self.radius,
			false
		)
	end

	self.position += self.velocity * dt
end

function Ball:doSphereCollision(sphereCollider: SphereCollider)
	self = self :: Ball
	local difference = sphereCollider.position - self.position
	local magnitude = difference:length()
	local distance = magnitude - (self.radius + sphereCollider.radius)

	if distance < 0 then
		self.position += (difference:normalize() * distance)
		self.velocity = difference:normalize() * self.velocity:length() * -self.bounciness * sphereCollider.bounceFactor
		self.velocity += sphereCollider.velocity
	end
end

local ball = Ball.new(Vec3.zeroVector, Quat.fromXZ(Vec3.forwardVector, Vec3.upVector), 20)

-- Main -----------------------------------------------------------------------
local grabbed = false
local rightHand = false
local grabTimer = 0
local motionTimer = 0
local gravityChaser = gravity.upRotation
local rotEuler = Vec3.zeroVector

function onTransitionBegin(transitionInfo: Transition)
	camera.positionSmoothing = 0
	camera.rotationSmoothing = 0
	camera.fieldOfViewSmoothing = 0
	camera.fieldOfView = transitionInfo.startFieldOfView
	camera.position = transitionInfo.startPosition
	ball.position = transitionInfo.startPosition
	ball.velocity = Vec3.zeroVector

	if gravity.strength > 0 and gravity.upDirection ~= Vec3.zeroVector then
		ball.rotation = gravity.upRotation
		gravityChaser = gravity.upRotation
	else
		local virtualPos = camera.position * -1
		virtualPos.y = 0
		virtualPos = virtualPos:normalize()
		local forward = Vec3.rightVector:cross(virtualPos)
		gravityChaser = Quat.fromXZ(forward, virtualPos)
		ball.rotation = Quat.fromXZ(Vec3.rightVector, virtualPos)
	end

	rotEuler = camera.rotation:euler()
	rotEuler.x = 0
	DriftBallCollider.radius = 17

	customGravity = Quat.identity
	usingCustomGravity = false
end

function onTransitionEnd(transitionInfo: Transition)
	camera.rotationSmoothing = 0.02
end

function onGui()
	if Gui.collapsingHeader("World Interaction") then
		Gui.indent()

		if Gui.collapsingHeader("Players") then
			Gui.indent()

			if Gui.beginListBox("") then
				for i = 1, #players do
					local player = players[i]
					local isSelected = i == guiPlayerIndex
					local status = ""

					if player.blocked then
						status ..= " " .. Icon.EyeSlash
					end
					if targetPlayerIndex == i then
						status ..= " " .. Icon.Eye
					end
					if i == ownerPlayerIndex then
						status ..= " " .. Icon.Crown
					end

					if Gui.selectable(player.name .. status, isSelected) then
						guiPlayerIndex = i
					end
				end
				Gui.endListBox()
			end

			if guiPlayerIndex > 0 then
				local player = players[guiPlayerIndex]
				Gui.separatorText(player.name)

				Gui.beginHorizontal("player_options")

				if Gui.button(Icon.Backspace) then
					guiPlayerIndex = 0
				end

				if ownerPlayerIndex == guiPlayerIndex then
					if Gui.button("Remove Owner") then
						ownerPlayerIndex = 0
					end
				else
					if Gui.button("Set Owner") then
						ownerPlayerIndex = guiPlayerIndex
					end
					Gui.setItemTooltip("Allow this player to summon the camera")
				end

				player.blocked = Gui.checkbox("Blocked", player.blocked)
				Gui.setItemTooltip("Blocks this player from being able to hit the camera")

				Gui.endHorizontal()

				Gui.separatorText("")
			end

			Gui.beginHorizontal("player_list_options")
			if Gui.button("Block All") then
				for i = 1, #players do
					players[i].blocked = true
				end
			end

			if Gui.button("Unblock All") then
				for i = 1, #players do
					players[i].blocked = false
				end
			end

			if ownerPlayerIndex > 0 then
				if Gui.button("Remove Owner") then
					ownerPlayerIndex = 0
				end
			end
			Gui.endHorizontal()

			Gui.unindent()
		end

		local frames = getAllGameData()
		if #frames > 1 then
			updateframeIndex(frames, Gui.dragInt("Frame Index", frameIndex, 1, 1, #frames))
		end

		Gui.separatorText("Collision")
		DO_PLAYER_COLLISION = Gui.checkbox("Player Collision", DO_PLAYER_COLLISION)
		DO_DRIFTBALL_COLLISION = Gui.checkbox("Driftball Collision", DO_DRIFTBALL_COLLISION)
		USE_DRIFTBALL_SIZE = Gui.checkbox("Estimate Driftball Radius", USE_DRIFTBALL_SIZE)
		DO_SPECTATOR_COLLISION = Gui.checkbox("Spectator Collision", DO_SPECTATOR_COLLISION)
		Gui.separatorText("Grabbing")
		DO_GRABBING = Gui.checkbox("Allow Grabbing", DO_GRABBING)
		ONLY_OWNER_GRAB = Gui.checkbox("Only Owner Can Grab", ONLY_OWNER_GRAB)
		GRAB_OFFSET = Gui.dragFloat3("Grab Offset (local)", GRAB_OFFSET, 1, 0, 300)

		Gui.unindent()
	end

	if Gui.collapsingHeader("Physics") then
		Gui.indent()

		FROZEN = Gui.checkbox("Frozen", FROZEN)
		UPDATE_CUSTOM_GRAVITY_EVERY_BOUNCE = Gui.checkbox("Set Gravity On Bounce", UPDATE_CUSTOM_GRAVITY_EVERY_BOUNCE)
		FACE_VELOCITY = Gui.checkbox("Face Velocity", FACE_VELOCITY)
		ball.bounciness = Gui.sliderFloat("Bounciness", ball.bounciness, 0, 1)
		ball.floatiness = Gui.sliderFloat("Floatiness", ball.floatiness, 0, 1)
		ball.radius = Gui.dragInt("Radius", ball.radius, 1, 1, 200)

		Gui.unindent()
	end

	if Gui.collapsingHeader("Debugging") then
		Gui.indent()

		DO_DEBUG_LOGGING = Gui.checkbox("Debug Logs", DO_DEBUG_LOGGING)

		Gui.separatorText("Drawing")
		SHOW_COLLIDERS = Gui.checkbox("Show Colliders", SHOW_COLLIDERS)
		SHOW_VELOCITY = Gui.checkbox("Show Collider Velocity", SHOW_VELOCITY)

		local targetPlayer = getPlayerAtIndex(targetPlayerIndex)
		local targetName = if targetPlayer then targetPlayer.name else "nobody"
		local status = if grabbed then "Grabbed by " else "targetting "
		Gui.text(status .. targetName)

		local ownerPlayer = getPlayerAtIndex(ownerPlayerIndex)
		local ownerName = if ownerPlayer then ownerPlayer.name else "nobody"
		Gui.text("Owned by " .. ownerName)

		Gui.unindent()
	end
end

function tick(dt)
	-- Do nothing, I'm frozen
	if FROZEN then
		return
	end

	if usingCustomGravity then
		gravityChaser = Quat.slerp(gravityChaser, customGravity, 0.05)
	elseif gravityChaser ~= gravity.upRotation and gravity.strength ~= 0 then
		gravityChaser = Quat.slerp(gravityChaser, gravity.upRotation, 0.05)
	end

	-- Facing / looking
	if FACE_VELOCITY then
		if not grabbed then
			if ball.velocity:length() > 50 or (grabbed and ball.velocity:length() > 5) then
				camera.rotation =
					Quat.slerp(camera.rotation, Quat.fromXZ(ball.velocity, gravityChaser:getUpVector()), 0.06)
			end
		end
		--camera:lookAt(headCollider.position, gravity.upDirection)
	else
		local lookInputTargetDelta = Vec3.zeroVector

		-- Mouse
		local mouse = Input.getMouseDelta()
		if mouse and mouse.x then
			-- Yaw
			lookInputTargetDelta.z += mouse.x * 2
			-- Pitch
			lookInputTargetDelta.y += mouse.y * 2
		end

		rotEuler += lookInputTargetDelta
		camera.rotation = gravityChaser * Quat.fromEuler(rotEuler.x, rotEuler.y, rotEuler.z)
	end

	local frames = getAllGameData()
	updatePlayers(frames)

	-- Logic for being held
	if grabbed then
		local targetPlayer = getPlayerAtIndex(targetPlayerIndex)

		if
			targetPlayer
			and targetPlayer.replay
			and not targetPlayer.blocked
			and (not ONLY_OWNER_GRAB or ownerPlayerIndex == targetPlayerIndex)
		then
			local poseBits = if rightHand
				then targetPlayer.replay.rightHandPosebits
				else targetPlayer.replay.leftHandPosebits
			if bit32.extract(poseBits, 3, 1) == 1 then
				local handPos = targetPlayer:handWorldPos(rightHand)
				local handRot = targetPlayer:handWorldRot(rightHand)
				local lastPos = ball.position
				ball.position = handPos + handRot:rotateVector(GRAB_OFFSET)
				camera.position = ball.position
				if FACE_VELOCITY then
					ball.rotation = handRot
					camera.rotation = ball.rotation
				end
				ball.velocity = (ball.position - lastPos) / dt
				return
			end
		end

		grabbed = false
		grabTimer = 0.5
	end

	if grabTimer > 0 then
		grabTimer -= dt
	elseif grabTimer < 0 then
		grabTimer = 0
	end

	local ownerPlayer = getPlayerAtIndex(ownerPlayerIndex)

	if ownerPlayer and ownerPlayer.replay then
		if
			bit32.extract(ownerPlayer.replay.rightHandPosebits, 3, 1) == 1
			and bit32.extract(ownerPlayer.replay.leftHandPosebits, 3, 1) == 1
		then
			local rightPos = ownerPlayer:handWorldPos(true)
			local leftPos = ownerPlayer:handWorldPos(false)

			if rightPos:distance(leftPos) < 10 then
				motionTimer = 0.2
			end

			if motionTimer > 0 then
				motionTimer -= dt
				if rightPos:distance(leftPos) > 25 then
					local targetPos = ownerPlayer.replay.root.position
						+ (ownerPlayer.replay.root.rotation:getUpVector() * 20)
					ball.position = targetPos
					ball.velocity = ownerPlayer.replay.velocity
					camera.position = ball.position
					motionTimer = 0
				end
			end
		else
			motionTimer = 0
		end
	else
		motionTimer = 0
	end

	-- User controls
	if Input.getKey(Input.Key.LeftControl) then
		if gravity.strength > 0 then
			ball.velocity = ball.velocity:lerp(gravity.upDirection * -(ball.velocity:length() + 100), 0.01)
		else
			ball.velocity = ball.velocity:lerp(Vec3.zeroVector, 0.02)
		end
	end

	if Input.getKeyDown(Input.Key.SpaceBar) and gravity.strength > 0 then
		local groundCheck = camera:castRay(ball.position, ball.position - (gravity.upDirection * ball.radius * 1.2))
		if groundCheck.successful then
			ball.velocity += groundCheck.normal * 500
		else
			ball.velocity -= gravityChaser:getUpVector() * math.max(ball.velocity:length() * 0.7, 1000)
		end
	end

	if Input.getKey(Input.Key.W) then
		ball.velocity += camera.rotation:getForwardVector() * ACCELERATION * dt
	end

	if Input.getKey(Input.Key.S) then
		ball.velocity -= camera.rotation:getForwardVector() * ACCELERATION * dt
	end

	if Input.getKey(Input.Key.D) then
		ball.velocity += camera.rotation:getRightVector() * ACCELERATION * dt
	end

	if Input.getKey(Input.Key.A) then
		ball.velocity -= camera.rotation:getRightVector() * ACCELERATION * dt
	end

	if Input.getKeyUp(Input.Key.RightMouseButton) then
		usingCustomGravity = false
		if gravity.strength > 0 and gravity.upDirection ~= Vec3.zeroVector then
			ball.rotation = gravity.upRotation
		else
			local virtualPos = camera.position * -1
			virtualPos.y = 0
			virtualPos = virtualPos:normalize()
			local forward = Vec3.rightVector:cross(virtualPos)
			gravityChaser = Quat.fromXZ(forward, virtualPos)
			ball.rotation = Quat.fromXZ(Vec3.rightVector, virtualPos)
		end
	end

	if Input.getKeyUp(Input.Key.LeftMouseButton) then
		local ray = camera:castRay(camera.position, camera.position + camera.rotation:getForwardVector() * 5000)
		if ray.successful then
			usingCustomGravity = true
			customGravity = Quat.fromXZ(camera.rotation:getRightVector():cross(ray.normal), ray.normal)
		end
	end

	-- Normal logic for ball physics

	targetPlayerIndex = getNearestPlayer(ball.position)
	local targetPlayer = getPlayerAtIndex(targetPlayerIndex)

	if DO_GRABBING and (not ONLY_OWNER_GRAB or ownerPlayerIndex == targetPlayerIndex) then
		if targetPlayer and targetPlayer.replay then
			if bit32.extract(targetPlayer.replay.rightHandPosebits, 3, 1) == 1 then
				local right = targetPlayer:handWorldPos(true)
				if ball.position:distance(right) < ball.radius * 1.5 then
					grabbed = true
					rightHand = true
					ball.velocity = Vec3.zeroVector
					return
				end
			end
			if bit32.extract(targetPlayer.replay.leftHandPosebits, 3, 1) == 1 then
				local left = targetPlayer:handWorldPos(false)
				if ball.position:distance(left) < ball.radius * 1.5 then
					grabbed = true
					rightHand = false
					ball.velocity = Vec3.zeroVector
					return
				end
			end
		end
	end

	if grabTimer == 0 then
		if DO_PLAYER_COLLISION then
			if targetPlayer and targetPlayer.replay then
				-- Update colliders

				local velocity: Vec3 = targetPlayer.replay.velocity:normalize()
					* math.min(targetPlayer.replay.velocity:length(), 1000)
				velocity = (
					targetPlayer.replay.root.rotation:getForwardVector()
					* targetPlayer.replay.root.rotation:getForwardVector():dot(velocity)
				)
					+ (
						targetPlayer.replay.root.rotation:getRightVector()
						* targetPlayer.replay.root.rotation:getRightVector():dot(velocity)
					)

				rightHandCollider:setPosition(targetPlayer:handWorldPos(true), dt, true)
				leftHandCollider:setPosition(targetPlayer:handWorldPos(false), dt, true)
				headCollider:setPosition(targetPlayer.replay.head.position, false)
				lowerBodyCollider:setPosition(
					targetPlayer.replay.root.position
						+ (targetPlayer.replay.root.rotation:getUpVector() * -60)
						- (velocity * 0.05),
					dt,
					false
				)
				upperBodyCollider:setPosition(
					targetPlayer.replay.root.position
						+ (targetPlayer.replay.root.rotation:getUpVector() * -35)
						- (velocity * 0.01),
					dt,
					false
				)

				headCollider.velocity = targetPlayer.replay.velocity
				lowerBodyCollider.velocity = targetPlayer.replay.velocity
				upperBodyCollider.velocity = targetPlayer.replay.velocity

				if SHOW_COLLIDERS then
					rightHandCollider:draw(0.001)
					leftHandCollider:draw(0.001)
					headCollider:draw(0.001)
					lowerBodyCollider:draw(0.001)
					upperBodyCollider:draw(0.001)
				end

				if SHOW_VELOCITY then
					rightHandCollider:drawVelocity(0.001)
					leftHandCollider:drawVelocity(0.001)
					headCollider:drawVelocity(0.001)
					lowerBodyCollider:drawVelocity(0.001)
					upperBodyCollider:drawVelocity(0.001)
				end

				ball:doSphereCollision(rightHandCollider, dt)
				ball:doSphereCollision(leftHandCollider, dt)
				ball:doSphereCollision(headCollider, dt)
				ball:doSphereCollision(lowerBodyCollider, dt)
				ball:doSphereCollision(upperBodyCollider, dt)
			end
		end

		if DO_DRIFTBALL_COLLISION then
			local targetDriftball = getNearestDriftball(ball.position, frames[frameIndex])

			if targetDriftball then
				
				if USE_DRIFTBALL_SIZE then
					local ballData = targetDriftball:toJson()
					print(ballData)
					local typeString = string.find(ballData, "type")
					local ratio = 1
					if(typeString) then
						local numEnd = string.find(ballData, ",", typeString)
						local numString = ballData:sub(typeString+7, numEnd-1)
						local ballType = tonumber(numString)
						if(ballType) then
							--print("Type: ".. ballType)
							if ballType <= #BALL_TYPE_RATIOS then
								ratio = BALL_TYPE_RATIOS[ballType]
							end
						end
					end
					local sizeString = string.find(ballData, "size")
					if(sizeString) then
						local numEnd = string.find(ballData, ",", sizeString)
						local numString = ballData:sub(sizeString+7, numEnd-1)
						local size = tonumber(numString)
						if(size) then
							--print("SIZE: ".. size .. " (" .. size*17*ratio .. ")")
							size *= 17 * ratio
							DriftBallCollider.radius = size
						end
					end
				end

				DriftBallCollider:setPosition(targetDriftball.transform.position, dt, false)
				DriftBallCollider.velocity = targetDriftball.velocity

				if SHOW_COLLIDERS then
					DriftBallCollider:draw(0.001)
				end

				if SHOW_VELOCITY then
					DriftBallCollider:drawVelocity(0.001)
				end

				ball:doSphereCollision(DriftBallCollider, dt)
			end
		end

		if DO_SPECTATOR_COLLISION then
			local targetSpectator = getNearestSpectator(ball.position, frames[frameIndex])

			if targetSpectator then
				SpectatorCollider:setPosition(targetSpectator.transform.position, dt, true)

				if SHOW_COLLIDERS then
					SpectatorCollider:draw(0.001)
				end

				if SHOW_VELOCITY then
					DriftBallCollider:drawVelocity(0.001)
				end

				ball:doSphereCollision(SpectatorCollider, dt)
			end
		end
	end

	ball:physicsStep(dt)
	camera.position = ball.position
end
