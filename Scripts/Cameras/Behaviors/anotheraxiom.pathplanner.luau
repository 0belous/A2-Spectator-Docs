metadata = {
	author = "Another Axiom",
	defaultKeybind = "T",
}

type CameraTransform = {
	position: Vec3,
	rotation: Quat,
	fieldOfView: number,
}

type Keyframe = {
	duration: number,
	transform: CameraTransform,
	postProcessing: {
		depthOfFieldFocalDistance: number,
		depthOfFieldFstop: number,
		depthOfFieldSensorWidth: number,
	},
	smoothing: number,
	controlPointDistance: number,
}
type ReplayKeyframe = {
	animationTime: number,
	replayTime: number,
}

type ReplayAnimation = { keyframes: { ReplayKeyframe }, fileName: string, replayDuration: number, playbackHz: number? }
type ReplayAnimations = { ReplayAnimation }
--- A curve consists of 1, 2, 3, or 4 keyframes
type Curve = { keyframes: { Keyframe }, lut: { number }, duration: number }
--- A spline consists of 1 or more curves
type Spline = { curves: { Curve }, arcLength: number, totalDuration: number }
type SplineSample = {
	--- Contains pos/rot data
	keyframe: Keyframe | nil,
	--- The index of the curve in the spline
	curveIdx: number,
	--- The t value of the current curve within the spline
	t: number,
	--- The length of the current curve
	curveLength: number,
	--- The number of keyframes in the current curve
	curveKeyframes: number,
	--- The curve that the sample was taken from
	curve: Curve,
}

local lastCamPos = Vec3.new(0, 0, 0)
local cameraVelocity = Vec3.new(0, 0, 0)
local freecam: SpectatorCamera
local keyframes: { Keyframe } = {}
local replayAnimations: ReplayAnimations = {}
local newReplayFileName: string = ""
local newReplayPlaybackHz: number = 0
local animating = false
local playbackTime01 = 0
local smoothing = 0
local mode: "Edit" | "Playback" = "Edit"
local detailedFrames = false
local loopAnimation = true
--- How far apart the extra control nodes are from the control point
local controlPointDistance01 = 0.1667
local spline: Spline
local lastSampledData: SplineSample = {
	keyframe = nil,
	curveIdx = 0,
	t = 0,
	curveLength = 0,
	curveKeyframes = 0,
	curve = nil,
}
local showPath = false
local showPathPoints = false
local numPathPointsPerSecond = 10
local pathPointsSize = 10
local showReplayPaths = false
local lineThickness = 10
local replayLineThickness = 10
local minFov = 10
local maxFov = 160
local shaking = false
local initialShakeTransform: CameraTransform

local enableGlobalSmoothing = true

camera.positionSmoothing = smoothing
camera.rotationSmoothing = smoothing
camera.fieldOfViewSmoothing = smoothing

-- TEMP
local startGoalTime = 0
local endGoalTime = 0
local currentGoal = false

local function generateRandomColor(keyframe: Keyframe): { r: number, g: number, b: number }
	math.randomseed(keyframe.transform.position.x + keyframe.transform.position.y + keyframe.transform.position.z)
	return { r = math.random(0, 1), g = math.random(0, 1), b = math.random(0, 1) }
end

local function logKeyframes(anim: { Keyframe })
	local outputString = ""
	for index, value in anim do
		outputString ..= "Position: " .. tostring(value.transform.position) .. "\nRotation: " .. tostring(value.transform.rotation) .. "\nField of View: " .. value.transform.fieldOfView --value.transform:toJson()
		if index < #anim then
			outputString ..= ", "
		end
	end
	print("[" .. outputString .. "]")
end

local function tableToCameraTransform(t): CameraTransform
	return {
		position = Vec3.new(t.position.x, t.position.y, t.position.z),
		rotation = Quat.new(t.rotation.x, t.rotation.y, t.rotation.z, t.rotation.w),
		fieldOfView = t.fieldOfView,
	}
end

local function lerp(a: number, b: number, t: number): number
	if a == nil then
		return b
	end
	if b == nil then
		return a
	end
	return a * (1.0 - t) + b * t
end

local function shakeConfirm()
	shaking = true
	shakeTimer = 0
	initialShakeTransform = {
		position = Vec3.new(camera.position.x, camera.position.y, camera.position.z),
		rotation = Quat.new(camera.rotation.x, camera.rotation.y, camera.rotation.z, camera.rotation.w),
		fieldOfView = camera.fieldOfView,
	}
end

local function setMode(newMode: "Edit" | "Playback")
	mode = newMode
	if mode == "Edit" then
		sendMessage(freecam, {
			messageType = "setTransform",
			position = camera.position,
			rotation = camera.rotation,
			fieldOfView = camera.fieldOfView,
		})
		camera:followCamera(freecam)
		animating = false
	elseif mode == "Playback" then
		camera:followCamera(nil)
	end
end

local function saveToConfig(anim: { Keyframe })
	logKeyframes(anim)
	-- We need to convert the keyframes to a format that can be saved
	local configKeyframes = {}
	for i = 1, #anim, 1 do
		table.insert(configKeyframes, {
			duration = anim[i].duration,
			transform = {
				position = {
					x = anim[i].transform.position.x,
					y = anim[i].transform.position.y,
					z = anim[i].transform.position.z,
				},
				rotation = {
					x = anim[i].transform.rotation.x,
					y = anim[i].transform.rotation.y,
					z = anim[i].transform.rotation.z,
					w = anim[i].transform.rotation.w,
				},
				fieldOfView = anim[i].transform.fieldOfView,
			},
			postProcessing = anim[i].postProcessing,
		})
	end
	config.keyframes = configKeyframes
	config.replayKeyframes = replayAnimations
	config.smoothing = smoothing
	config.controlPointDistance01 = controlPointDistance01
	print(replayAnimations)
	print(config)
	saveConfig()
	print("Saved " .. #configKeyframes .. " keyframes to config")
	shakeConfirm()
end

local function sampleCurve(curve: Curve, time01: number): Keyframe
	local t = time01
	local kfs = curve.keyframes
	if #kfs == 1 then
		return kfs[1]
	elseif #kfs == 2 then
		return {
			duration = 0,
			transform = {
				position = Vec3.lerp(kfs[1].transform.position, kfs[2].transform.position, t),
				rotation = Quat.slerp(kfs[1].transform.rotation, kfs[2].transform.rotation, t),
				fieldOfView = lerp(kfs[1].transform.fieldOfView, kfs[2].transform.fieldOfView, t),
			},
			postProcessing = {
				depthOfFieldFocalDistance = lerp(kfs[1].postProcessing.depthOfFieldFocalDistance, kfs[2].postProcessing.depthOfFieldFocalDistance, t),
				depthOfFieldFstop = lerp(kfs[1].postProcessing.depthOfFieldFstop, kfs[2].postProcessing.depthOfFieldFstop, t),
				depthOfFieldSensorWidth = lerp(kfs[1].postProcessing.depthOfFieldSensorWidth, kfs[2].postProcessing.depthOfFieldSensorWidth, t),
			},
			smoothing = lerp(kfs[1].smoothing, kfs[2].smoothing, t),
			controlPointDistance = lerp(kfs[1].controlPointDistance, kfs[2].controlPointDistance, t),
		}
	elseif #kfs == 3 then
		-- TODO this weighs all control points equally in duration
		return {
			duration = 0,
			transform = {
				position = Vec3.lerp(
					Vec3.lerp(kfs[1].transform.position, kfs[2].transform.position, t),
					Vec3.lerp(kfs[2].transform.position, kfs[3].transform.position, t),
					t
				),
				rotation = Quat.slerp(
					Quat.slerp(kfs[1].transform.rotation, kfs[2].transform.rotation, t),
					Quat.slerp(kfs[2].transform.rotation, kfs[3].transform.rotation, t),
					t
				),
				fieldOfView = lerp(
					lerp(kfs[1].transform.fieldOfView, kfs[2].transform.fieldOfView, t),
					lerp(kfs[2].transform.fieldOfView, kfs[3].transform.fieldOfView, t),
					t
				),
			},
			postProcessing = {
				depthOfFieldFocalDistance = lerp(
					lerp(kfs[1].postProcessing.depthOfFieldFocalDistance, kfs[2].postProcessing.depthOfFieldFocalDistance, t),
					lerp(kfs[2].postProcessing.depthOfFieldFocalDistance, kfs[3].postProcessing.depthOfFieldFocalDistance, t),
					t
				),
				depthOfFieldFstop = lerp(
					lerp(kfs[1].postProcessing.depthOfFieldFstop, kfs[2].postProcessing.depthOfFieldFstop, t),
					lerp(kfs[2].postProcessing.depthOfFieldFstop, kfs[3].postProcessing.depthOfFieldFstop, t),
					t
				),
				depthOfFieldSensorWidth = lerp(
					lerp(kfs[1].postProcessing.depthOfFieldSensorWidth, kfs[2].postProcessing.depthOfFieldSensorWidth, t),
					lerp(kfs[2].postProcessing.depthOfFieldSensorWidth, kfs[3].postProcessing.depthOfFieldSensorWidth, t),
					t
				),
			},
			smoothing = lerp(lerp(kfs[1].smoothing, kfs[2].smoothing, t), lerp(kfs[2].smoothing, kfs[3].smoothing, t), t),
			controlPointDistance = lerp(
				lerp(kfs[1].controlPointDistance, kfs[2].controlPointDistance, t),
				lerp(kfs[2].controlPointDistance, kfs[3].controlPointDistance, t),
				t
			),
		}
	-- elseif #curve == 4 then
	-- There should only ever be 4 keyframes in a curve
	else
		return {
			duration = 0,
			transform = {
				position = Vec3.lerp(
					Vec3.lerp(
						Vec3.lerp(kfs[1].transform.position, kfs[2].transform.position, t),
						Vec3.lerp(kfs[2].transform.position, kfs[3].transform.position, t),
						t
					),
					Vec3.lerp(
						Vec3.lerp(kfs[2].transform.position, kfs[3].transform.position, t),
						Vec3.lerp(kfs[3].transform.position, kfs[4].transform.position, t),
						t
					),
					t
				),
				rotation = Quat.slerp(
					Quat.slerp(
						Quat.slerp(kfs[1].transform.rotation, kfs[2].transform.rotation, t),
						Quat.slerp(kfs[2].transform.rotation, kfs[3].transform.rotation, t),
						t
					),
					Quat.slerp(
						Quat.slerp(kfs[2].transform.rotation, kfs[3].transform.rotation, t),
						Quat.slerp(kfs[3].transform.rotation, kfs[4].transform.rotation, t),
						t
					),
					t
				),
				fieldOfView = lerp(
					lerp(
						lerp(kfs[1].transform.fieldOfView, kfs[2].transform.fieldOfView, t),
						lerp(kfs[2].transform.fieldOfView, kfs[3].transform.fieldOfView, t),
						t
					),
					lerp(
						lerp(kfs[2].transform.fieldOfView, kfs[3].transform.fieldOfView, t),
						lerp(kfs[3].transform.fieldOfView, kfs[4].transform.fieldOfView, t),
						t
					),
					t
				),
			},
			postProcessing = {
				depthOfFieldFocalDistance = lerp(
					lerp(
						lerp(kfs[1].postProcessing.depthOfFieldFocalDistance, kfs[2].postProcessing.depthOfFieldFocalDistance, t),
						lerp(kfs[2].postProcessing.depthOfFieldFocalDistance, kfs[3].postProcessing.depthOfFieldFocalDistance, t),
						t
					),
					lerp(
						lerp(kfs[2].postProcessing.depthOfFieldFocalDistance, kfs[3].postProcessing.depthOfFieldFocalDistance, t),
						lerp(kfs[3].postProcessing.depthOfFieldFocalDistance, kfs[4].postProcessing.depthOfFieldFocalDistance, t),
						t
					),
					t
				),
				depthOfFieldFstop = lerp(
					lerp(
						lerp(kfs[1].postProcessing.depthOfFieldFstop, kfs[2].postProcessing.depthOfFieldFstop, t),
						lerp(kfs[2].postProcessing.depthOfFieldFstop, kfs[3].postProcessing.depthOfFieldFstop, t),
						t
					),
					lerp(
						lerp(kfs[2].postProcessing.depthOfFieldFstop, kfs[3].postProcessing.depthOfFieldFstop, t),
						lerp(kfs[3].postProcessing.depthOfFieldFstop, kfs[4].postProcessing.depthOfFieldFstop, t),
						t
					),
					t
				),
				depthOfFieldSensorWidth = lerp(
					lerp(
						lerp(kfs[1].postProcessing.depthOfFieldSensorWidth, kfs[2].postProcessing.depthOfFieldSensorWidth, t),
						lerp(kfs[2].postProcessing.depthOfFieldSensorWidth, kfs[3].postProcessing.depthOfFieldSensorWidth, t),
						t
					),
					lerp(
						lerp(kfs[2].postProcessing.depthOfFieldSensorWidth, kfs[3].postProcessing.depthOfFieldSensorWidth, t),
						lerp(kfs[3].postProcessing.depthOfFieldSensorWidth, kfs[4].postProcessing.depthOfFieldSensorWidth, t),
						t
					),
					t
				),
			},
			smoothing = lerp(
				lerp(lerp(kfs[1].smoothing, kfs[2].smoothing, t), lerp(kfs[2].smoothing, kfs[3].smoothing, t), t),
				lerp(lerp(kfs[2].smoothing, kfs[3].smoothing, t), lerp(kfs[3].smoothing, kfs[4].smoothing, t), t),
				t
			),
			controlPointDistance = lerp(
				lerp(
					lerp(kfs[1].controlPointDistance, kfs[2].controlPointDistance, t),
					lerp(kfs[2].controlPointDistance, kfs[3].controlPointDistance, t),
					t
				),
				lerp(
					lerp(kfs[2].controlPointDistance, kfs[3].controlPointDistance, t),
					lerp(kfs[3].controlPointDistance, kfs[4].controlPointDistance, t),
					t
				),
				t
			),
		}
	end
end

-- Generates a LUT for a curve
local function calculateCurvePosLut(curve: Curve): { number }
	local currentArcLength = 0
	local lut: { number } = {}
	if #curve.keyframes == 0 or curve.keyframes[1].duration == 0 then
		table.insert(lut, 0)
		return lut
	end
	local lastPos = sampleCurve(curve, 0).transform.position
	local lutSize = 20
	for i = 0, lutSize, 1 do
		local t = i / lutSize
		local pos = sampleCurve(curve, t).transform.position
		local arcLength = Vec3.distance(lastPos, pos)
		currentArcLength += arcLength
		table.insert(lut, currentArcLength)
		lastPos = pos
	end
	return lut
end

local function getCurveArcLength(curve: Curve): number
	if #curve.keyframes == 2 then
		local a = curve.keyframes[1].transform.position
		local b = curve.keyframes[2].transform.position
		return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
	end
	if curve.lut == nil then
		curve.lut = calculateCurvePosLut(curve)
	end
	return curve.lut[#curve.lut]
end

function remap(value: number, low1: number, high1: number, low2: number, high2: number): number
	return low2 + (value - low1) * (high2 - low2) / (high1 - low1)
end

local function normalizeTByDistance(curve: Curve, time01: number): number
	local totalArcLength = getCurveArcLength(curve)
	local targetDistance = totalArcLength * time01
	local lut = curve.lut
	if targetDistance <= 0 then
		return 0
	end
	for i = 1, #lut, 1 do
		if targetDistance <= lut[i] then
			local currLutValue = lut[i]
			local prevLutValue = lut[i - 1]
			local low2 = (i - 2) / (#lut - 1)
			local high2 = (i - 1) / (#lut - 1)
			local t = remap(targetDistance, prevLutValue, currLutValue, low2, high2)
			return t
		end
	end
	return 0
end

local function sampleReplays(
	replayAnimations: ReplayAnimations,
	animationTimeSeconds: number
): {
	{
		replayIndex: number,
		fileName: string,
		replayTimeSeconds: number,
	}
}
	local output: {
		{
			replayIndex: number,
			fileName: string,
			replayTimeSeconds: number,
		}
	} = {}
	for i = 1, #replayAnimations, 1 do
		-- Only include replays are currently running
		if
			replayAnimations[i].keyframes
			and #replayAnimations[i].keyframes >= 2
			and replayAnimations[i].keyframes[1].animationTime <= animationTimeSeconds
			and replayAnimations[i].keyframes[#replayAnimations[i].keyframes].animationTime >= animationTimeSeconds
		then
			-- Find the closest two keyframes
			local previousKeyframe = replayAnimations[i].keyframes[1]
			local nextKeyframe = replayAnimations[i].keyframes[2]
			for j = 2, #replayAnimations[i].keyframes do
				local currentKeyframe = replayAnimations[i].keyframes[j]
				if currentKeyframe.animationTime >= animationTimeSeconds then
					nextKeyframe = currentKeyframe
					break
				end
				previousKeyframe = currentKeyframe
			end
			local replayTimeSeconds = remap(
				animationTimeSeconds,
				previousKeyframe.animationTime,
				nextKeyframe.animationTime,
				previousKeyframe.replayTime,
				nextKeyframe.replayTime
			)

			table.insert(output, {
				replayIndex = i,
				fileName = replayAnimations[i].fileName,
				replayTimeSeconds = replayTimeSeconds,
			})
		end
	end
	return output
end

local function sampleSpline(spline: Spline, time01: number): SplineSample
	-- Timing by using keyframe durations

	local targetDuration = spline.totalDuration * time01

	local cumulativeDuration = 0
	for i = 1, #spline.curves, 1 do
		local curve: Curve = spline.curves[i]
		-- local curveDuration = 0
		if targetDuration < cumulativeDuration + curve.duration then
			-- local t = normalizeTByDistance(curve, (targetDuration - cumulativeDuration) / curve.duration)
			local t = (targetDuration - cumulativeDuration) / curve.duration
			return {
				keyframe = sampleCurve(curve, t),
				curveIdx = i,
				t = t,
				curveLength = getCurveArcLength(curve),
				curve = curve,
				curveKeyframes = #curve.keyframes,
			}
		end
		cumulativeDuration += curve.duration
	end

	return { keyframe = nil, curveIdx = 0, keyframeIdx = 0, t = 0, curveLength = 0, curveKeyframes = 0, curve = nil }
end

local function drawPathIfEnabled(spline: Spline)
	if showPath == false and showPathPoints == false then
		WorldDraw.clear()
		return
	end
	WorldDraw.clear()

	if showPath then
		local lastSample = sampleSpline(spline, 0)
		local splineSamples = 200
		if #keyframes == 0 then
			return
		end
		for i = 1, #keyframes, 1 do
			local color = generateRandomColor(keyframes[i])
			WorldDraw.drawPoint(keyframes[i].transform.position, color.r, color.g, color.b, pathPointsSize * 2, 0)
		end
		for i = 1, splineSamples - 1, 1 do
			local newSample = sampleSpline(spline, i / splineSamples)
			if newSample.curve == nil then
				break
			end
			local color = generateRandomColor(newSample.curve.keyframes[1])

			WorldDraw.drawLine(
				lastSample.keyframe.transform.position,
				newSample.keyframe.transform.position,
				color.r,
				color.g,
				color.b,
				lineThickness,
				0
			)
			lastSample = newSample
		end
	end
	if showPathPoints then
		for i = 1, spline.totalDuration * numPathPointsPerSecond, 1 do
			local sample = sampleSpline(spline, i / (spline.totalDuration * numPathPointsPerSecond))
			local color = { r = 1, g = 0, b = 0 }
			WorldDraw.drawPoint(sample.keyframe.transform.position, color.r, color.g, color.b, pathPointsSize, 0)
		end
	end
end

local function colorFromSpeed(speed: number): { number }
	local slowest = Vec3.new(0, 1, 0)
	local fastest = Vec3.new(1, 0, 0)
	local speed01 = math.clamp(speed / 1000, 0, 1)
	local out = Vec3.lerp(slowest, fastest, speed01)
	return { out.x, out.y, out.z }
end

local function drawReplayPaths(fileName: string)
	if showReplayPaths == false then
		WorldDraw.clear()
		return
	end
	WorldDraw.clear()
	local segments = 0
	local replay = Replay.load(fileName)
	local resolution = 1 -- how many times per frame to sample
	local lastFrame: ReplayFrame = nil
	for i = 1, replay:getDurationSeconds() * resolution do
		local frame = replay:getFrameAtTimeSeconds((i - 1) / resolution, true)
		for j = 1, #frame.players do
			local player = frame.players[j]
			local lastPlayer: ReplayPlayer = nil
			if lastFrame then
				lastPlayer = lastFrame:getPlayerById(player.playerId)
			end

			if lastPlayer then
				local c = colorFromSpeed(player.velocity:length())
				WorldDraw.drawLine(lastPlayer.head.position, player.head.position, c[1], c[2], c[3], replayLineThickness, 0)
				segments = segments + 1
			end
		end
		lastFrame = frame
	end
	print("Total line segments drawn: " .. segments)
	Replay.unloadByIndex(#Replay.listLoaded())
end

local function generateSpline(keyframes: { Keyframe }): Spline
	local spline: Spline = {
		curves = {},
		arcLength = 0,
		totalDuration = 0,
	}
	local currentCurve: Curve = {
		keyframes = {},
		lut = nil,
		duration = 0,
	}

	if #keyframes > 2 then
		--  loop through all keyframes except first
		for i = 2, #keyframes, 1 do
			local controlPointDistanceToUse = controlPointDistance01
			if keyframes[i].controlPointDistance ~= nil then
				controlPointDistanceToUse = keyframes[i].controlPointDistance
			end
			local lastKf: Keyframe = keyframes[i - 1]
			local currentKf: Keyframe = keyframes[i]
			local nextKf: Keyframe = keyframes[i + 1]
			if nextKf == nil then
				nextKf = currentKf
			end
			local dir = nextKf.transform.position - lastKf.transform.position
			local fovDiff = nextKf.transform.fieldOfView - lastKf.transform.fieldOfView
			fovDiff = math.min(
				(nextKf.transform.fieldOfView - currentKf.transform.fieldOfView),
				(currentKf.transform.fieldOfView - lastKf.transform.fieldOfView)
			)

			-- Add the first keyframe at the beginning of the spline
			if i == 2 then
				local d = lastKf.duration - lastKf.duration * controlPointDistanceToUse
				if currentKf.duration == 0 then
					d = lastKf.duration
				end
				table.insert(currentCurve.keyframes, {
					duration = d,
					transform = lastKf.transform,
					postProcessing = {
						depthOfFieldFocalDistance = lastKf.postProcessing.depthOfFieldFocalDistance,
						depthOfFieldFstop = lastKf.postProcessing.depthOfFieldFstop,
						depthOfFieldSensorWidth = lastKf.postProcessing.depthOfFieldSensorWidth,
					},
					smoothing = lastKf.smoothing,
					controlPointDistance = lastKf.controlPointDistance,
				})
			end

			if currentKf.duration ~= 0 then
				-- add the second control point
				table.insert(currentCurve.keyframes, {
					duration = lastKf.duration * controlPointDistanceToUse,
					transform = {
						position = currentKf.transform.position
							+ Vec3.lerp(lastKf.transform.position, nextKf.transform.position, 1 - controlPointDistanceToUse)
							- nextKf.transform.position,
						rotation = currentKf.transform.rotation,
						fieldOfView = currentKf.transform.fieldOfView - fovDiff * controlPointDistanceToUse,
					},
					postProcessing = {
						depthOfFieldFocalDistance = lerp(
							lastKf.postProcessing.depthOfFieldFocalDistance,
							currentKf.postProcessing.depthOfFieldFocalDistance,
							1 - controlPointDistanceToUse
						),
						depthOfFieldFstop = lerp(
							lastKf.postProcessing.depthOfFieldFstop,
							currentKf.postProcessing.depthOfFieldFstop,
							1 - controlPointDistanceToUse
						),
						depthOfFieldSensorWidth = lerp(
							lastKf.postProcessing.depthOfFieldSensorWidth,
							currentKf.postProcessing.depthOfFieldSensorWidth,
							1 - controlPointDistanceToUse
						),
					},
					smoothing = lerp(lastKf.smoothing, currentKf.smoothing, 1 - controlPointDistanceToUse),
					controlPointDistance = lastKf.controlPointDistance,
				})
			end
			-- add the last point in the curve - keyframe
			table.insert(currentCurve.keyframes, {
				duration = 0,
				transform = currentKf.transform,
				postProcessing = {
					depthOfFieldFocalDistance = currentKf.postProcessing.depthOfFieldFocalDistance,
					depthOfFieldFstop = currentKf.postProcessing.depthOfFieldFstop,
					depthOfFieldSensorWidth = currentKf.postProcessing.depthOfFieldSensorWidth,
				},
				smoothing = currentKf.smoothing,
				controlPointDistance = currentKf.controlPointDistance,
			})
			-- finish this curve and add it to the spline
			table.insert(spline.curves, currentCurve)
			spline.arcLength += getCurveArcLength(currentCurve)
			spline.totalDuration += lastKf.duration
			currentCurve = {
				keyframes = {},
				lut = nil,
				duration = 0,
			}

			------------------------

			-- add this keyframe as the first keyframe in the next curve
			local d = currentKf.duration * controlPointDistanceToUse
			if lastKf.duration == 0 then
				d = currentKf.duration - currentKf.duration * controlPointDistanceToUse
				if nextKf.duration == 0 then
					d = currentKf.duration
				end
			end
			table.insert(currentCurve.keyframes, {
				duration = d,
				transform = currentKf.transform,
				postProcessing = {
					depthOfFieldFocalDistance = currentKf.postProcessing.depthOfFieldFocalDistance,
					depthOfFieldFstop = currentKf.postProcessing.depthOfFieldFstop,
					depthOfFieldSensorWidth = currentKf.postProcessing.depthOfFieldSensorWidth,
				},
				smoothing = currentKf.smoothing,
				controlPointDistance = currentKf.controlPointDistance,
			})

			-- Add the last keyframe at the end of the curve
			if i == #keyframes then
				table.insert(currentCurve.keyframes, {
					duration = currentKf.duration - currentKf.duration * controlPointDistanceToUse,
					transform = currentKf.transform,
					postProcessing = {
						depthOfFieldFocalDistance = currentKf.postProcessing.depthOfFieldFocalDistance,
						depthOfFieldFstop = currentKf.postProcessing.depthOfFieldFstop,
						depthOfFieldSensorWidth = currentKf.postProcessing.depthOfFieldSensorWidth,
					},
					smoothing = currentKf.smoothing,
					controlPointDistance = currentKf.controlPointDistance,
				})
				table.insert(currentCurve.keyframes, {
					duration = 0,
					transform = currentKf.transform,
					postProcessing = {
						depthOfFieldFocalDistance = currentKf.postProcessing.depthOfFieldFocalDistance,
						depthOfFieldFstop = currentKf.postProcessing.depthOfFieldFstop,
						depthOfFieldSensorWidth = currentKf.postProcessing.depthOfFieldSensorWidth,
					},
					smoothing = currentKf.smoothing,
					controlPointDistance = currentKf.controlPointDistance,
				})
				table.insert(spline.curves, currentCurve)
				spline.arcLength += getCurveArcLength(currentCurve)
				spline.totalDuration += keyframes[#keyframes].duration
			elseif currentKf.duration ~= 0 and lastKf.duration ~= 0 then
				-- add the first control point
				local d2 = currentKf.duration - (2 * currentKf.duration * controlPointDistanceToUse)
				if nextKf.duration == 0 then
					d2 = currentKf.duration - currentKf.duration * controlPointDistanceToUse
				end
				table.insert(currentCurve.keyframes, {
					duration = d2,
					transform = {
						position = currentKf.transform.position
							+ Vec3.lerp(lastKf.transform.position, nextKf.transform.position, controlPointDistanceToUse)
							- lastKf.transform.position,
						rotation = currentKf.transform.rotation,
						fieldOfView = currentKf.transform.fieldOfView + fovDiff * controlPointDistanceToUse,
					},
					postProcessing = {
						depthOfFieldFocalDistance = lerp(
							currentKf.postProcessing.depthOfFieldFocalDistance,
							nextKf.postProcessing.depthOfFieldFocalDistance,
							controlPointDistanceToUse
						),
						depthOfFieldFstop = lerp(
							currentKf.postProcessing.depthOfFieldFstop,
							nextKf.postProcessing.depthOfFieldFstop,
							controlPointDistanceToUse
						),
						depthOfFieldSensorWidth = lerp(
							currentKf.postProcessing.depthOfFieldSensorWidth,
							nextKf.postProcessing.depthOfFieldSensorWidth,
							controlPointDistanceToUse
						),
					},
					smoothing = lerp(currentKf.smoothing, nextKf.smoothing, controlPointDistanceToUse),
					controlPointDistance = currentKf.controlPointDistance,
				})
			end
		end
		for i = 1, #spline.curves, 1 do
			for j = 1, #spline.curves[i].keyframes, 1 do
				spline.curves[i].duration += spline.curves[i].keyframes[j].duration
			end
		end
	elseif #keyframes == 2 then
		currentCurve = {
			keyframes = { keyframes[1], keyframes[2] },
			lut = nil,
			duration = keyframes[1].duration,
		}
		table.insert(spline.curves, currentCurve)
		spline.arcLength += getCurveArcLength(currentCurve)
		spline.totalDuration += keyframes[1].duration
	elseif #keyframes == 1 then
		currentCurve = { keyframes = { keyframes[1] }, lut = nil, duration = keyframes[1].duration }
		table.insert(spline.curves, currentCurve)
		spline.arcLength += getCurveArcLength(currentCurve)
		spline.totalDuration += keyframes[1].duration
	end

	drawPathIfEnabled(spline)
	return spline
end

local function appendKeyframe(anim: { Keyframe }, index: number)
	table.insert(anim, index, {
		duration = 3,
		transform = {
			position = Vec3.new(camera.position.x, camera.position.y, camera.position.z),
			rotation = Quat.new(camera.rotation.x, camera.rotation.y, camera.rotation.z, camera.rotation.w),
			fieldOfView = camera.fieldOfView,
		},
		postProcessing = {
			depthOfFieldFocalDistance = postProcessSettings.depthOfFieldFocalDistance,
			depthOfFieldFstop = postProcessSettings.depthOfFieldFstop,
			depthOfFieldSensorWidth = postProcessSettings.depthOfFieldSensorWidth,
		},
		smoothing = 0,
		controlPointDistance = controlPointDistance01,
	})
	spline = generateSpline(keyframes)
end

local function goTo(keyframe: Keyframe)
	setMode("Edit")
	sendMessage(freecam, {
		messageType = "setTransform",
		position = keyframe.transform.position,
		rotation = keyframe.transform.rotation,
		fieldOfView = keyframe.transform.fieldOfView,
	})
	postProcessSettings.depthOfFieldFocalDistance = keyframe.postProcessing.depthOfFieldFocalDistance
	local cumulativeTime = 0
	for i = 1, #keyframes, 1 do
		if keyframes[i] == keyframe then
			playbackTime01 = cumulativeTime / spline.totalDuration
			break
		end
		cumulativeTime += keyframes[i].duration
		print(cumulativeTime)
	end
end

-- Function to check if a list contains a specific value
function listContains(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

function main()
	local configKeyframes = config.keyframes or {}
	-- make sure all the necessary types are included
	local idx = 1
	for i = 1, #configKeyframes do
		if configKeyframes[idx] ~= nil then
			if configKeyframes[idx].postProcessing == nil or configKeyframes[idx].postProcessing.depthOfFieldFocalDistance == nil then
				configKeyframes[idx].postProcessing = { depthOfFieldFocalDistance = 0 }
			end
			if configKeyframes[idx].transform == nil then
				-- remove nil keyframes
				table.remove(configKeyframes, idx)
				idx -= 1
			end
		else
			-- remove nil keyframes
			table.remove(configKeyframes, idx)
			idx -= 1
		end
		idx += 1
	end
	keyframes = configKeyframes
	smoothing = config.smoothing or 0
	controlPointDistance01 = config.controlPointDistance01 or 0.3
	spline = generateSpline(keyframes)
	print("Loaded " .. #keyframes .. " keyframes from config")
	replayAnimations = config.replayKeyframes or {}
	print("Loaded " .. #replayAnimations .. " replay animations from config")
	freecam = getCameraById("anotheraxiom.freecam")
	camera:followCamera(freecam)
end

function onGui()
	startGoalTime = Gui.sliderFloat("Start Goal VFX 0 to 1", startGoalTime, 0, 1)
	endGoalTime = Gui.sliderFloat("End Goal VFX 0 to 1", endGoalTime, 0, 1)

	if Gui.collapsingHeader("Controls") then
		Gui.indent()
		Gui.text("Add Keyframe:     V or Top Gamepad Face Button")
		Gui.text("Toggle Playback:  Spacebar or Bottom Gamepad Face Button")
		Gui.text("Go to Start:      Home")
		Gui.text("Save Keyframes:   Control + S")
		Gui.text("Reset Keyframes:  Control + R")
		Gui.text("Scrub backwards:  < (hold)")
		Gui.text("Scrub forwards:   > (hold)")
		Gui.unindent()
	end

	if Gui.collapsingHeader("General Settings") then
		enableGlobalSmoothing = Gui.checkbox("Enable Global Smoothing", enableGlobalSmoothing)
		Gui.setItemTooltip("Check this box to use the below slider, otherwise per keyframe values will be used")
		Gui.spacing()
		smoothing = Gui.sliderFloat("Smoothing", smoothing, 0, 2)
		Gui.spacing()
		local newControlPointDistance01 = Gui.sliderFloat("Spline Control Point Distance", controlPointDistance01, 0, 1)
		if newControlPointDistance01 ~= controlPointDistance01 then
			controlPointDistance01 = newControlPointDistance01
			spline = generateSpline(keyframes)
		end
	end
	if enableGlobalSmoothing then
		camera.positionSmoothing = smoothing
		camera.rotationSmoothing = smoothing
		camera.fieldOfViewSmoothing = smoothing
	end
	if Gui.collapsingHeader("Manual Input") then
		local set = false
		local newPos = Gui.dragFloat3("Position", camera.position, 10, -100000, 100000)
		if Gui.isItemActive() then
			set = true
		end
		local newRot = Gui.dragFloat3("Rotation (roll, pitch, yaw)", camera.rotation:euler(), 1, -180, 180)
		if Gui.isItemActive() then
			set = true
		end
		local newFov = Gui.sliderFloat("Field of View", camera.fieldOfView, minFov, maxFov)
		if Gui.isItemActive() then
			set = true
		end
		if set == true then
			sendMessage(freecam, {
				messageType = "setTransform",
				position = newPos,
				rotation = Quat.fromEuler(newRot.x, newRot.y, newRot.z),
				fieldOfView = newFov,
			})
		end
	end

	Gui.spacing()

	Gui.separatorText("Playback")
	Gui.beginHorizontal("header bar 2")
	if Gui.button(Icon.ChevronLeft) then
		setMode("Playback")
		animating = false
		playbackTime01 = playbackTime01 - 0.005
	end
	if animating then
		if Gui.button(Icon.Pause) then
			animating = false
		end
	else
		if Gui.button(Icon.Play) then
			setMode("Playback")
			animating = true
		end
	end
	if Gui.button(Icon.ChevronRight) then
		setMode("Playback")
		animating = false
		playbackTime01 = playbackTime01 + 0.005
	end
	Gui.spacing()
	Gui.spacing()
	Gui.text("Current mode:")
	if mode == "Edit" then
		if Gui.button("Edit") then
			setMode("Playback")
		end
	elseif mode == "Playback" then
		if Gui.button("Playback") then
			setMode("Edit")
		end
	end

	loopAnimation = Gui.checkbox("Loop Playback", loopAnimation)

	Gui.endHorizontal()

	local t = playbackTime01 * spline.totalDuration
	local playbackTime = Gui.sliderFloat("Playback Slider (s)", t, 0, spline.totalDuration)
	if spline ~= nil and spline.totalDuration ~= 0 then
		playbackTime01 = playbackTime / spline.totalDuration
		if Gui.isItemActive() then
			animating = false
			setMode("Playback")
		end
	end

	Gui.spacing()
	local idx = lastSampledData.curveIdx

	if Gui.collapsingHeader("Main Keyframes") then
		detailedFrames = Gui.checkbox("Detailed Keyframe View", detailedFrames)
		Gui.sameLine()
		local newShowPath = Gui.checkbox("Show path", showPath)
		if newShowPath ~= showPath then
			showPath = newShowPath
			drawPathIfEnabled(spline)
		end
		Gui.sameLine()
		local newShowPathPoints = Gui.checkbox("Show path points", showPathPoints)
		if newShowPathPoints ~= showPathPoints then
			showPathPoints = newShowPathPoints
			drawPathIfEnabled(spline)
		end
		if showPath then
			local newLineThickness = Gui.sliderFloat("Line Thickness", lineThickness, 1, 50)
			if newLineThickness ~= lineThickness then
				lineThickness = newLineThickness
				drawPathIfEnabled(spline)
			end
		end
		if showPathPoints then
			local newPathPointsSize = Gui.sliderFloat("Path Points Size", pathPointsSize, 1, 100)
			if newPathPointsSize ~= pathPointsSize then
				pathPointsSize = newPathPointsSize
				drawPathIfEnabled(spline)
			end
			local newPathPointsInterval = Gui.sliderFloat("Path Points per Second", numPathPointsPerSecond, 0.1, 100)
			if newPathPointsInterval ~= numPathPointsPerSecond then
				numPathPointsPerSecond = newPathPointsInterval
				drawPathIfEnabled(spline)
			end
		end

		Gui.text("Keyframes:")
		Gui.beginHorizontal("Keyframes area")
		Gui.beginDisabled()
		local spacingMul = 103
		if detailedFrames then
			spacingMul = 232
		end
		Gui.vSliderInt("", #keyframes * spacingMul, #keyframes - idx + 1, 1, #keyframes)
		Gui.endDisabled()
		Gui.beginVertical("Keyframes Sliders")

		for i = 1, #keyframes, 1 do
			Gui.pushId("Keyframe " .. i)
			Gui.beginHorizontal("Keyframe horizontal " .. i)

			Gui.beginVertical("up/down")
			Gui.text(tostring(i))
			if i == 1 then
				Gui.beginDisabled()
			end
			if Gui.button(Icon.CaretUp) then
				if i > 1 then
					local temp = keyframes[i]
					keyframes[i] = keyframes[i - 1]
					keyframes[i - 1] = temp
				end
				spline = generateSpline(keyframes)
			end
			if i == 1 then
				Gui.endDisabled()
			end
			if i == #keyframes then
				Gui.beginDisabled()
			end
			Gui.setItemTooltip("Move Up")
			if Gui.button(Icon.CaretDown) then
				if i < #keyframes then
					local temp = keyframes[i]
					keyframes[i] = keyframes[i + 1]
					keyframes[i + 1] = temp
				end
				spline = generateSpline(keyframes)
			end
			if i == #keyframes then
				Gui.endDisabled()
			end
			Gui.setItemTooltip("Move Down")
			Gui.endVertical()

			Gui.beginVertical("Keyframe vertical " .. i)
			Gui.beginHorizontal("Keyframe " .. i .. " Horizontal 2")
			if Gui.button("Go to") then
				print("Going to keyframe " .. i)
				goTo(keyframes[i])
			end
			if Gui.button("Replace") then
				keyframes[i].transform = {
					position = Vec3.new(camera.position.x, camera.position.y, camera.position.z),
					rotation = Quat.new(camera.rotation.x, camera.rotation.y, camera.rotation.z, camera.rotation.w),
					fieldOfView = camera.fieldOfView,
				}
				keyframes[i].postProcessing.depthOfFieldFocalDistance = postProcessSettings.depthOfFieldFocalDistance
				spline = generateSpline(keyframes)
			end
			if Gui.button(Icon.Trash) then
				table.remove(keyframes, i)
				spline = generateSpline(keyframes)
			end
			Gui.setItemTooltip("Delete Keyframe")

			Gui.beginDisabled()
			if keyframes[i] ~= nil then
				Gui.text(tostring(keyframes[i].transform.position))
			end
			Gui.endDisabled()
			Gui.endHorizontal()

			if keyframes[i] ~= nil then
				if detailedFrames then
					keyframes[i].transform.position = Gui.dragFloat3("Position", keyframes[i].transform.position, 1, -1000000, 1000000)
					if Gui.isItemActive() then
						goTo(keyframes[i])
					end
					if Gui.isItemDeactivated() then
						spline = generateSpline(keyframes)
					end
					keyframes[i].transform.rotation = Gui.dragFloat4("Rotation", keyframes[i].transform.rotation, 0.01, -1, 1)
					if Gui.isItemActive() then
						goTo(keyframes[i])
					end
					if Gui.isItemDeactivated() then
						spline = generateSpline(keyframes)
					end
					keyframes[i].transform.fieldOfView = Gui.dragFloat("Field of View", keyframes[i].transform.fieldOfView, 0.1, 0, 179)
					if Gui.isItemActive() then
						goTo(keyframes[i])
					end
					if Gui.isItemDeactivated() then
						spline = generateSpline(keyframes)
					end
					keyframes[i].postProcessing.depthOfFieldFocalDistance =
						Gui.dragFloat("DoF Distance", keyframes[i].postProcessing.depthOfFieldFocalDistance, 1, 0, 100000)
					if Gui.isItemActive() then
						goTo(keyframes[i])
					end
					if Gui.isItemDeactivated() then
						spline = generateSpline(keyframes)
					end
					if keyframes[i].smoothing == nil then
						keyframes[i].smoothing = 0
					end
					keyframes[i].smoothing = Gui.dragFloat("Smoothing", keyframes[i].smoothing, 0.01, 0, 2)

					if Gui.isItemActive() then
						goTo(keyframes[i])
					end
					if Gui.isItemDeactivated() then
						spline = generateSpline(keyframes)
					end
					if keyframes[i].controlPointDistance == nil then
						keyframes[i].controlPointDistance = 0.03
					end
					keyframes[i].controlPointDistance = Gui.dragFloat("Control point distance", keyframes[i].controlPointDistance, 0.01, 0, 1)

					if Gui.isItemActive() then
						goTo(keyframes[i])
					end
					if Gui.isItemDeactivated() then
						spline = generateSpline(keyframes)
					end
				end
			end
			if keyframes[i] ~= nil then
				if keyframes[i].duration == 0 then
					Gui.beginDisabled()
				end
				local newDuration = Gui.dragFloat("Duration", keyframes[i].duration, 0.02, 0, 600)
				if newDuration ~= keyframes[i].duration then
					keyframes[i].duration = newDuration
					spline = generateSpline(keyframes)
				end
				if keyframes[i].duration == 0 then
					Gui.endDisabled()
				end
			end
			Gui.beginHorizontal("Between frames " .. i)
			Gui.spacing()
			Gui.spacing()
			Gui.spacing()
			if Gui.button(Icon.Plus .. " Add Keyframe ") then
				appendKeyframe(keyframes, i + 1)
			end
			Gui.setItemTooltip("Adds the current camera transform as a keyframe at this point in the list")

			if keyframes[i] ~= nil then
				local teleport = keyframes[i].duration == 0
				local newTeleport = Gui.checkbox("Instant teleport", teleport)
				if teleport ~= newTeleport then
					teleport = newTeleport
					if teleport then
						keyframes[i].duration = 0
					else
						keyframes[i].duration = 3
					end
					spline = generateSpline(keyframes)
				end
			end

			Gui.endHorizontal()

			Gui.endVertical()
			Gui.endHorizontal()
			Gui.separator()
			Gui.popId()
		end

		if Gui.button(Icon.Plus .. " Add Keyframe ") then
			appendKeyframe(keyframes, #keyframes + 1)
		end
		Gui.setItemTooltip("Adds the current camera transform as a keyframe at the end of the list")

		Gui.endVertical()
		Gui.endHorizontal()
		Gui.beginHorizontal("header bar 1")
		if Gui.button(Icon.Save) then
			saveToConfig(keyframes)
		end
		Gui.setItemTooltip("Save keyframes to config file")
		if Gui.button(Icon.Trash) then
			keyframes = {}

			spline = generateSpline(keyframes)
		end
		Gui.setItemTooltip("Clear keyframes")
		Gui.endHorizontal()
	end

	if Gui.collapsingHeader("Replay Keyframes") then
		for i = 1, #replayAnimations, 1 do
			local r = replayAnimations[i]
			if r ~= nil then
				if Gui.treeNode("Replay " .. i) then
					Gui.indent()
					Gui.pushId("Replay " .. i)

					Gui.beginHorizontal("Replay " .. i)
					Gui.text(r.fileName)
					if Gui.button(Icon.Trash) then
						table.remove(replayAnimations, i)
						r = nil
					end
					Gui.setItemTooltip("Delete")
					Gui.endHorizontal()
					if r ~= nil then
						local newShowPath = Gui.checkbox("Show player paths", showReplayPaths)
						if newShowPath ~= showReplayPaths then
							showReplayPaths = newShowPath
							drawReplayPaths(r.fileName)
						end
						if showReplayPaths then
							local newLineThickness = Gui.sliderFloat("Line Thickness", replayLineThickness, 1, 50)
							if newLineThickness ~= replayLineThickness then
								replayLineThickness = newLineThickness
								drawReplayPaths(r.fileName)
							end
						end

						Gui.separator()
						for j = 1, #r.keyframes, 1 do
							local k = r.keyframes[j]
							Gui.pushId("Keyframe " .. j)
							k.animationTime = Gui.dragFloat("Animation Time (s)", k.animationTime, 0.1, 0, 10000)
							k.replayTime = Gui.sliderFloat("Replay Time (s)", k.replayTime, 0, r.replayDuration)
							if Gui.button("Go to") then
								setMode("Playback")
								animating = false
								playbackTime = k.animationTime
							end
							Gui.sameLine()
							if Gui.button(Icon.Trash) then
								table.remove(r.keyframes, j)
							end
							Gui.setItemTooltip("Delete Keyframe")
							Gui.separator()
							Gui.popId()
						end
						if Gui.button("Add Keyframe +") then
							table.insert(r.keyframes, { animationTime = 0, replayTime = 0 })
						end
					end

					Gui.popId()
					Gui.unindent()
					Gui.treePop()
				end
			end
		end

		Gui.spacing()

		newReplayPlaybackHz = Gui.dragInt("Playback subsampling", newReplayPlaybackHz, 1, 0, 240)
		newReplayFileName = Gui.inputText("New Replay Name", newReplayFileName)
		Gui.sameLine()
		if Gui.button("Add Replay") then
			if listContains(Replay.listAll(), newReplayFileName) then
				local r = Replay.load(newReplayFileName)
				local duration = r:getDurationSeconds()
				Replay.unloadByIndex(#Replay.listLoaded())
				table.insert(replayAnimations, {
					fileName = newReplayFileName,
					keyframes = {
						{
							animationTime = 0,
							replayTime = 0,
						},
						{
							animationTime = duration,
							replayTime = duration,
						},
					},
					replayDuration = duration,
					playbackHz = newReplayPlaybackHz,
				})
			end
		end
	end

	Gui.separatorText("Debug")
	Gui.beginDisabled()

	Gui.text("Closest Keyframe: " .. idx .. " Camera speed: " .. tostring(cameraVelocity:length()))

	if lastSampledData.keyframe ~= nil then
		Gui.text(
			" curve: "
				.. lastSampledData.curveIdx
				.. " Spline Length: "
				.. math.round(spline.arcLength)
				.. " curveLength: "
				.. math.round(lastSampledData.curveLength)
				.. " curveKeyframes: "
				.. lastSampledData.curveKeyframes
		)
		-- Gui.sliderFloat("t (Keyframe)", lastSampledData.t, 0, 1)
		Gui.sliderFloat("t (Curve)", lastSampledData.t, 0, 1)
		Gui.sliderFloat("Velocity", cameraVelocity:length(), 0, 2 * spline.arcLength / spline.totalDuration)
		Gui.sameLine()
		Gui.text("Estimated total speed: " .. math.round(spline.arcLength / spline.totalDuration))
		Gui.sliderFloat("Distance covered", spline.arcLength * playbackTime01, 0, spline.arcLength)
	else
		Gui.text("No keyframe found")
	end
	Gui.endDisabled()
end

local function endswith(string: string, suffix: string): boolean
	return string:sub(-#suffix) == suffix
end

function tick(dt)
	if Input.getKeyDown(Input.Key.V) or Input.getKeyDown(Input.Gamepad.FaceButton_Top) then
		print(
			"Position: "
				.. tostring(camera.position)
				.. " Rotation: "
				.. tostring(camera.rotation)
				.. " Field of View "
				.. tostring(camera.fieldOfView)
		)
		appendKeyframe(keyframes, #keyframes + 1)
	end

	if Input.getKeyDown(Input.Key.SpaceBar) or Input.getKeyDown(Input.Gamepad.FaceButton_Bottom) then
		animating = not animating
		if animating then
			setMode("Playback")
		else
			setMode("Edit")
		end
		print("Animating: " .. tostring(animating))
	end

	if Input.getKey(Input.Key.Comma) then
		setMode("Playback")
		animating = false
		playbackTime01 = playbackTime01 - 0.01 * dt
		playbackTime01 = math.max(playbackTime01, 0)
	end
	if Input.getKey(Input.Key.Period) then
		setMode("Playback")
		animating = false
		playbackTime01 = playbackTime01 + 0.01 * dt
		playbackTime01 = math.min(playbackTime01, 1)
	end

	if Input.getKey(Input.Key.LeftControl) and Input.getKeyDown(Input.Key.S) then
		saveToConfig(keyframes)
	end

	if Input.getKeyDown(Input.Key.Home) then
		playbackTime01 = 0
		setMode("Playback")
	end

	if Input.getKey(Input.Key.LeftControl) and Input.getKeyDown(Input.Key.R) then
		logKeyframes(keyframes)
		print("Resetting animation")
		keyframes = {}
		spline = generateSpline(keyframes)
	end

	if animating then
		if playbackTime01 >= 1 then
			if loopAnimation then
				playbackTime01 = 0
			else
				animating = false
				playbackTime01 = 1
			end
		end
		if spline.totalDuration ~= 0 then
			playbackTime01 += dt / spline.totalDuration
		end
	end

	if mode == "Playback" then
		lastSampledData = sampleSpline(spline, playbackTime01)
		local replaySamples = sampleReplays(replayAnimations, playbackTime01 * spline.totalDuration)

		-- Show replay files
		local loadedReplays = Replay.listLoaded()
		for i = 1, #replayAnimations, 1 do
			if #replayAnimations ~= #loadedReplays or not endswith(loadedReplays[i], replayAnimations[i].fileName) then
				print("Replays changed. Reloading replays.")
				Replay.unloadAll()
				for j = 1, #replayAnimations, 1 do
					local replay = Replay.loadSubsampled(replayAnimations[j].fileName, replayAnimations[j].playbackHz or 0)
					replay.isPlaying = false
				end
				break
			end
		end

		for i = 1, #replaySamples, 1 do
			local replay = Replay.getByIndex(replaySamples[i].replayIndex)
			if replay then
				replay:setPlaybackTimeSeconds(replaySamples[i].replayTimeSeconds)
				replay.isPlaying = false
			end
		end

		if lastSampledData.keyframe ~= nil then
			camera.position = lastSampledData.keyframe.transform.position
			camera.rotation = lastSampledData.keyframe.transform.rotation
			camera.fieldOfView = lastSampledData.keyframe.transform.fieldOfView
			if lastSampledData.keyframe.postProcessing ~= nil and lastSampledData.keyframe.postProcessing.depthOfFieldFocalDistance ~= nil then
				postProcessSettings.depthOfFieldFocalDistance = lastSampledData.keyframe.postProcessing.depthOfFieldFocalDistance
			else
				print("No DoF distance found")
			end
		end
	end

	cameraVelocity = (camera.position - lastCamPos) / dt
	lastCamPos = Vec3.new(camera.position.x, camera.position.y, camera.position.z)

	-- TEMP
	if playbackTime01 > startGoalTime and playbackTime01 < endGoalTime then
		-- should play goal vfx
		if not currentGoal then
			currentGoal = true
			spectatorDebug.goalExplosions = true
		end
	else
		if currentGoal then
			currentGoal = false
			spectatorDebug.goalExplosions = false
		end
	end

	if shaking then
		shakeTimer += dt
		if shakeTimer >= 0.2 then
			shaking = false
			shakeTimer = 0
			sendMessage(freecam, {
				messageType = "setTransform",
				position = initialShakeTransform.position,
				rotation = initialShakeTransform.rotation,
				fieldOfView = initialShakeTransform.fieldOfView,
			})
		else
			local shakeAmount = 100
			local shake =
				Vec3.new(math.random(-shakeAmount, shakeAmount), math.random(-shakeAmount, shakeAmount), math.random(-shakeAmount, shakeAmount))
			camera.position += shake
			sendMessage(freecam, {
				messageType = "setTransform",
				position = camera.position,
				rotation = camera.rotation,
				fieldOfView = camera.fieldOfView,
			})
		end
	end
end
