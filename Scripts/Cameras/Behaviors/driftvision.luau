--[[
Drift Vision V2.1 (Stable Edition, New Features)
Developed & Debugged by Pub | Nips

A comprehensive camera system for Orion Drift with robust state management,
improved keybind tracking, reliable recall functionality, and new third-person mode.
Released into the public domain.
]]

metadata = {
	name = "Drift Vision",
	description = "A comprehensive camera system built for Orion Drift, featuring multiple viewing modes, extension arm functionality, view rotation, and owner-based recall.",
	author = "Pub | Nips",
	defaultKeybind = "",
}

--====================================
--          CONFIGURATION           --
--====================================

config.viewpointOffset = config.viewpointOffset or Vec3.new(0, 0, 0)
config.fov = config.fov or 90
config.nearClip = config.nearClip or 1
config.hideHead = config.hideHead or true
config.nameTagType = config.nameTagType or 1  -- 0 = Always show, 1 = Show when not in POV, 2 = Always hide
config.currentPlayerId = config.currentPlayerId or nil
config.ownerId = config.ownerId or nil
config.useTriggerControl = true
config.headGrabRadius = config.headGrabRadius or 30     -- Range for grabbing camera from head
config.headDropRadius = config.headDropRadius or 22     -- Range for dropping camera onto head
config.cameraGrabRadius = config.cameraGrabRadius or 50 -- Range for picking up a free-floating camera
config.ownerRecallTime = config.ownerRecallTime or 0.5  -- Time (sec) for owner to hold trigger to recall camera
config.thirdPersonDistance = config.thirdPersonDistance or 300  -- Third-person view distance
config.grabDelayTime = config.grabDelayTime or 0.0      -- Delay (sec) to grab camera from POV

-- Hand offsets in world space
local rightHandOffset = Vec3.new(0, 10, -5)
local leftHandOffset = Vec3.new(0, 10, -5)

-- Extension arm settings
config.extensionEnabled = config.extensionEnabled or true
config.minExtension = config.minExtension or 5
config.maxExtension = config.maxExtension or 500
config.extensionStep = config.extensionStep or 10
config.extensionSmoothness = config.extensionSmoothness or 0.2
config.flipEnabled = config.flipEnabled or true

--====================================
--         STATE MANAGEMENT         --
--====================================

local t = 0                            -- Global time counter
local activePlayerId = nil             -- Currently followed player's ID
local selectedPlayerId = nil           -- Player selected in UI
local searchText = ""                  -- Search filter for players
local debugMode = false                -- Debug toggle flag

local ownerIsPresent = false           -- Flag indicating if owner is in game
local ownerPlayer = nil                -- Owner player reference

-- Camera modes
local viewpointMode = true             -- First-person mode (attached to head)
local thirdPersonMode = false          -- Third-person tracking mode
local cameraInHand = false             -- Camera is currently being held
local handHolding = nil                -- Which hand is holding the camera ("left" or "right")
local freeFloatingMode = false         -- Camera is free-floating

local worldUp = Vec3.new(0, 1, 0)        -- Up direction (gravity)

-- Extension and view state variables
local currentExtension = config.minExtension
local targetExtension = config.minExtension
local facingUser = true                -- Camera orientation relative to user
local viewFlipped = false              -- Indicates if view is flipped

-- Input tracking for grip toggling
local lastRightGripState = false
local lastLeftGripState = false

-- Owner recall uses a simple timer (mirroring grab delay logic)
local ownerRecallTimer = 0

-- Grab delay variables for hand-based camera grabs
local grabAttemptTime = 0
local isRightGrabAttempt = false
local isLeftGrabAttempt = false

-- New variables for initial startup POV fix
local initialPovSet = false            -- Flag to mark if initial POV has been forced
local initialDelay = 0                 -- Short delay counter before forcing POV

--====================================
--         INITIALIZATION           --
--====================================

function updateNameTagsVisibility()
    if not camera then return end
    if config.nameTagType == 0 then
        camera.showNameTags = true
    elseif config.nameTagType == 1 then
        camera.showNameTags = not viewpointMode
    else -- config.nameTagType == 2
        camera.showNameTags = false
    end
end

function onLoad()
    -- Initialize camera settings
    if camera then
        camera.fieldOfView = config.fov
        camera.nearClippingPlane = config.nearClip
        camera.hideNearestHead = config.hideHead
        updateNameTagsVisibility()
        camera.rotationSmoothing = 0.01
        camera.positionSmoothing = 0  -- No lag on startup
    end

    -- Reset state flags and timers
    activePlayerId = nil
    viewpointMode = true
    thirdPersonMode = false
    cameraInHand = false
    handHolding = nil
    freeFloatingMode = false
    facingUser = true
    viewFlipped = false
    currentExtension = config.minExtension
    targetExtension = config.minExtension
    lastRightGripState = false
    lastLeftGripState = false
    grabAttemptTime = 0
    isRightGrabAttempt = false
    isLeftGrabAttempt = false

    -- Check for owner presence
    checkForOwnerPresence()

    -- Prepare for initial POV fix
    activePlayerId = findAnyPlayer()
    initialPovSet = false   -- Ensure the flag is reset
    initialDelay = 0        -- Reset delay counter

    if debugMode then
        print("Camera loaded. Waiting to force POV mode on startup.")
        print("Config player ID: " .. tostring(config.currentPlayerId))
        print("Owner ID: " .. tostring(config.ownerId) .. ", Owner Present: " .. tostring(ownerIsPresent))
    end
end

function onUnload()
    if camera then
        camera.hideNearestHead = false
        camera.showNameTags = true
    end
    -- Save the active player state
    if activePlayerId then
        config.currentPlayerId = activePlayerId
        saveConfig()
        if debugMode then
            print("Saved player ID: " .. tostring(activePlayerId))
        end
    end
end

--====================================
--         PLAYER UTILITIES         --
--====================================

function getPlayers()
    local players = {}
    local sessions = getAllGameData()
    for i = 1, #sessions do
        if sessions[i].players then
            for j = 1, #sessions[i].players do
                local playerId = sessions[i].players[j].playerId
                local player = sessions[i]:getPlayerById(playerId)
                if player and player.playerName then
                    table.insert(players, { id = playerId, name = player.playerName })
                end
            end
        end
    end
    return players
end

function getPlayerById(playerId)
    if not playerId then return nil end
    local sessions = getAllGameData()
    for i = 1, #sessions do
        if sessions[i].getPlayerById then
            local player = sessions[i]:getPlayerById(playerId)
            if player then return player end
        end
    end
    return nil
end

function getPlayerName(playerId)
    if not playerId then return "None" end
    local player = getPlayerById(playerId)
    if player and player.playerName then
        return player.playerName
    end
    return "Unknown"
end

function checkForOwnerPresence()
    ownerIsPresent = false
    ownerPlayer = nil
    if config.ownerId then
        ownerPlayer = getPlayerById(config.ownerId)
        ownerIsPresent = (ownerPlayer ~= nil)
    end
    return ownerIsPresent
end

function findAnyPlayer()
    if config.currentPlayerId then
        local player = getPlayerById(config.currentPlayerId)
        if player then return config.currentPlayerId end
    end
    if config.ownerId then
        local player = getPlayerById(config.ownerId)
        if player then return config.ownerId end
    end
    local players = getPlayers()
    if #players > 0 then return players[1].id end
    return nil
end

function playerMatchesSearch(playerName, search)
    if search == "" then return true end
    local lowerName = string.lower(playerName)
    local lowerSearch = string.lower(search)
    return string.find(lowerName, lowerSearch) ~= nil
end

--====================================
--      INPUT & HAND UTILITIES      --
--====================================

function getHandPosition(player, isLeftHand)
    if not player or not player.root or not player.root.position or not player.root.rotation then return nil, nil end
    local handPos, handRot = nil, nil
    if isLeftHand then
        if player.leftHand and player.leftHand.position and player.leftHand.rotation then
            handPos = player.root.position + player.root.rotation:rotateVector(player.leftHand.position)
            handRot = player.leftHand.rotation
            return handPos, handRot
        end
    else
        if player.rightHand and player.rightHand.position and player.rightHand.rotation then
            handPos = player.root.position + player.root.rotation:rotateVector(player.rightHand.position)
            handRot = player.rightHand.rotation
            return handPos, handRot
        end
    end
    return nil, nil
end

function getUserInputState(player, isLeftHand)
    if not player then return "00000000" end
    local leftInputState = player.leftHandPosebits or 0
    local rightInputState = player.rightHandPosebits or 0
    local leftStateFormatted = encodeButtonState(leftInputState)
    local rightStateFormatted = encodeButtonState(rightInputState)
    return isLeftHand and leftStateFormatted or rightStateFormatted
end

function isButtonPressed(player, isLeftHand, buttonBit)
    local buttonState = getUserInputState(player, isLeftHand)
    return buttonState:sub(buttonBit, buttonBit) == "1"
end

function isGripPressed(player, isLeftHand)
    return isButtonPressed(player, isLeftHand, 5)
end

function isTriggerPressed(player, isLeftHand)
    return isButtonPressed(player, isLeftHand, 7)
end

function encodeButtonState(stateBits)
    if not stateBits then return "00000000" end
    local output = ""
    for i = 0, 7 do
        if bit32 and bit32.band and bit32.lshift then
            if bit32.band(stateBits, bit32.lshift(1, i)) > 0 then
                output = "1" .. output
            else
                output = "0" .. output
            end
        else
            output = "0" .. output
        end
    end
    return output
end

--====================================
--         CAMERA CONTROL           --
--====================================

function flipCameraView()
    facingUser = not facingUser
    viewFlipped = not facingUser
    if debugMode then 
        print("Camera view flipped. Facing user: " .. tostring(facingUser))
    end
end

function lerp(a, b, t)
    return a + (b - a) * t
end

function setViewpointMode(player)
    if not player or not player.head then
        if debugMode then print("Invalid player for POV mode") end
        return
    end
    local viewOffset = player.head.rotation:rotateVector(config.viewpointOffset)
    camera.position = player.head.position + viewOffset
    camera.rotation = player.head.rotation
    camera.hideNearestHead = config.hideHead
    camera.positionSmoothing = 0

    viewpointMode = true
    thirdPersonMode = false
    cameraInHand = false
    handHolding = nil
    freeFloatingMode = false
    facingUser = true
    viewFlipped = false
    currentExtension = config.minExtension
    targetExtension = config.minExtension

    updateNameTagsVisibility()
end

function setThirdPersonMode(player)
    if not player or not player.head then
        if debugMode then print("Invalid player for third person mode") end
        return
    end
    viewpointMode = false
    thirdPersonMode = true
    cameraInHand = false
    handHolding = nil
    freeFloatingMode = false

    local headPos = player.head.position
    local headRot = player.head.rotation
    local behindVector = headRot:getForwardVector() * -config.thirdPersonDistance
    local hit = camera:castRay(headPos, headPos + behindVector)
    if hit.successful then
        camera.position = hit.position + (hit.normal * 10)
    else
        camera.position = headPos + behindVector
    end
    camera.rotation = headRot
    camera.hideNearestHead = false
    updateNameTagsVisibility()

    if debugMode then print("Third person mode activated") end
end

function updateThirdPersonMode(player, dt)
    if not player or not player.head then return end
    local headPos = player.head.position
    local headRot = player.head.rotation
    local targetPos = headPos + (headRot:getForwardVector() * -config.thirdPersonDistance)
    local hit = camera:castRay(headPos, targetPos)
    if hit.successful then
        targetPos = hit.position + (hit.normal * 10)
    end
    camera.positionSmoothing = 0.1
    camera.position = targetPos
    camera:lookAt(headPos, worldUp)
    camera.hideNearestHead = false
    local distToTarget = Vec3.distance(camera.position, headPos)
    camera.fieldOfView = math.max(60, math.min(config.fov, config.fov - ((config.thirdPersonDistance - distToTarget) / 10)))
end

function processOwnerRecall(dt)
    if not config.ownerId then
        ownerRecallTimer = 0
        return false 
    end
    local owner = getPlayerById(config.ownerId)
    if not owner or not owner.head then
        ownerRecallTimer = 0
        return false 
    end
    if activePlayerId == config.ownerId and (viewpointMode or cameraInHand) then
        ownerRecallTimer = 0
        return false
    end
    local rightHeld = isTriggerPressed(owner, false)
    local leftHeld  = isTriggerPressed(owner, true)
    if not (rightHeld or leftHeld) then
        ownerRecallTimer = 0
        return false
    end
    ownerRecallTimer = ownerRecallTimer + dt
    if ownerRecallTimer >= config.ownerRecallTime then
        activePlayerId = config.ownerId
        config.currentPlayerId = activePlayerId
        saveConfig()
        setViewpointMode(owner)
        ownerRecallTimer = 0
        return true
    end
    return false
end

function displayOwnerRecallStatus()
    if config.ownerId then
        local progress = ownerRecallTimer / config.ownerRecallTime
        local progressPct = math.floor(progress * 100)
        Gui.text("Recall Progress: " .. progressPct .. "%")
    end
end

--====================================
--         HAND-BASED GRAB           --
--====================================

function beginRightHandGrip(player, handPos, handRot)
    if not player or not handPos or not handRot then return end
    local headPos = player.head.position
    local headToHand = handPos - headPos
    local headToHandDir = headToHand:normalize()
    local upVector = worldUp
    local rightVector = Vec3.cross(headToHandDir, upVector):normalize()
    local stableForward = Vec3.cross(upVector, rightVector):normalize()
    local cameraPos = handPos + (upVector * rightHandOffset.y) + (stableForward * rightHandOffset.z)
    camera.position = cameraPos
    if facingUser then
        camera:lookAt(player.head.position, worldUp)
    else
        local lookAwayPoint = cameraPos + (headToHandDir * -100)
        camera:lookAt(lookAwayPoint, worldUp)
    end
    camera.hideNearestHead = false
    updateNameTagsVisibility()

    currentExtension = config.minExtension
    targetExtension = config.minExtension

    cameraInHand = true
    handHolding = "right"
    viewpointMode = false
    thirdPersonMode = false
    freeFloatingMode = false

    isRightGrabAttempt = false
    isLeftGrabAttempt = false
    grabAttemptTime = 0

    if debugMode then print("Camera grabbed with right hand") end
end

function beginLeftHandGrip(player, handPos, handRot)
    if not player or not handPos or not handRot then return end
    local headPos = player.head.position
    local headToHand = handPos - headPos
    local headToHandDir = headToHand:normalize()
    local upVector = worldUp
    local rightVector = Vec3.cross(headToHandDir, upVector):normalize()
    local stableForward = Vec3.cross(upVector, rightVector):normalize()
    local cameraPos = handPos + (upVector * leftHandOffset.y) + (stableForward * leftHandOffset.z)
    camera.position = cameraPos
    if facingUser then
        camera:lookAt(player.head.position, worldUp)
    else
        local lookAwayPoint = cameraPos + (headToHandDir * -100)
        camera:lookAt(lookAwayPoint, worldUp)
    end
    camera.hideNearestHead = false
    updateNameTagsVisibility()

    currentExtension = config.minExtension
    targetExtension = config.minExtension

    cameraInHand = true
    handHolding = "left"
    viewpointMode = false
    thirdPersonMode = false
    freeFloatingMode = false

    isRightGrabAttempt = false
    isLeftGrabAttempt = false
    grabAttemptTime = 0

    if debugMode then print("Camera grabbed with left hand") end
end

function updateRightHandGrip(player, handPos, handRot, dt)
    if not player or not handPos or not handRot then return end
    local headPos = player.head.position
    local headToHand = handPos - headPos
    local headToHandDir = headToHand:normalize()
    local upVector = worldUp
    local rightVector = Vec3.cross(headToHandDir, upVector):normalize()
    local stableForward = Vec3.cross(upVector, rightVector):normalize()
    local basePos = handPos + (upVector * rightHandOffset.y) + (stableForward * rightHandOffset.z)
    
    local rightGripPressed = isGripPressed(player, false)
    local leftGripPressed = isGripPressed(player, true)
    local leftTriggerPressed = isTriggerPressed(player, true)
    
    if config.flipEnabled and rightGripPressed and not lastRightGripState then
        flipCameraView()
    end
    lastRightGripState = rightGripPressed
    
    if config.extensionEnabled then
        if leftTriggerPressed then
            targetExtension = math.min(targetExtension + config.extensionStep * dt * 60, config.maxExtension)
        elseif leftGripPressed then
            targetExtension = math.max(targetExtension - config.extensionStep * dt * 60, config.minExtension)
        end
        if config.extensionSmoothness > 0 then
            currentExtension = lerp(currentExtension, targetExtension, (1 - config.extensionSmoothness))
        else
            currentExtension = targetExtension
        end
    end
    
    local extensionVector = headToHandDir * currentExtension
    local extendedPos = basePos + extensionVector
    camera.position = extendedPos
    
    if facingUser then
        camera:lookAt(headPos, worldUp)
    else
        local awayFromHead = (camera.position - headPos):normalize()
        local lookAwayPoint = camera.position + (awayFromHead * 100)
        camera:lookAt(lookAwayPoint, worldUp)
    end
    
    camera.hideNearestHead = false
    updateNameTagsVisibility()
    camera.positionSmoothing = 0
    
    if debugMode then
        print("Right Hand Grip: Extension=" .. tostring(currentExtension) .. ", Facing=" .. tostring(facingUser))
    end
end

function updateLeftHandGrip(player, handPos, handRot, dt)
    if not player or not handPos or not handRot then return end
    local headPos = player.head.position
    local headToHand = handPos - headPos
    local headToHandDir = headToHand:normalize()
    local upVector = worldUp
    local rightVector = Vec3.cross(headToHandDir, upVector):normalize()
    local stableForward = Vec3.cross(upVector, rightVector):normalize()
    local basePos = handPos + (upVector * leftHandOffset.y) + (stableForward * leftHandOffset.z)
    
    local leftGripPressed = isGripPressed(player, true)
    local rightGripPressed = isGripPressed(player, false)
    local rightTriggerPressed = isTriggerPressed(player, false)
    
    if config.flipEnabled and leftGripPressed and not lastLeftGripState then
        flipCameraView()
    end
    lastLeftGripState = leftGripPressed
    
    if config.extensionEnabled then
        if rightTriggerPressed then
            targetExtension = math.min(targetExtension + config.extensionStep * dt * 60, config.maxExtension)
        elseif rightGripPressed then
            targetExtension = math.max(targetExtension - config.extensionStep * dt * 60, config.minExtension)
        end
        if config.extensionSmoothness > 0 then
            currentExtension = lerp(currentExtension, targetExtension, (1 - config.extensionSmoothness))
        else
            currentExtension = targetExtension
        end
    end
    
    local extensionVector = headToHandDir * currentExtension
    local extendedPos = basePos + extensionVector
    camera.position = extendedPos
    
    if facingUser then
        camera:lookAt(headPos, worldUp)
    else
        local awayFromHead = (camera.position - headPos):normalize()
        local lookAwayPoint = camera.position + (awayFromHead * 100)
        camera:lookAt(lookAwayPoint, worldUp)
    end
    
    camera.hideNearestHead = false
    updateNameTagsVisibility()
    camera.positionSmoothing = 0
    
    if debugMode then
        print("Left Hand Grip: Extension=" .. tostring(currentExtension) .. ", Facing=" .. tostring(facingUser))
    end
end

function handleCameraRelease(player)
    local headNearby = false
    local newOwnerFound = false
    local players = getPlayers()
    for i = 1, #players do
        local otherPlayer = getPlayerById(players[i].id)
        if otherPlayer and otherPlayer.head then
            local distToHead = Vec3.distance(camera.position, otherPlayer.head.position)
            if distToHead < config.headDropRadius then
                activePlayerId = players[i].id
                local headPos = otherPlayer.head.position
                local camPos = camera.position
                local camForward = camera.rotation:getForwardVector()
                local headToCam = (camPos - headPos):normalize()
                local isFacingHead = Vec3.dot(camForward, headToCam) < 0
                if isFacingHead then
                    facingUser = true
                    viewFlipped = false
                    currentExtension = config.minExtension
                    targetExtension = config.minExtension
                    setViewpointMode(otherPlayer)
                else
                    setThirdPersonMode(otherPlayer)
                end
                headNearby = true
                newOwnerFound = true
                if debugMode then 
                    print("Camera dropped on player: " .. otherPlayer.playerName)
                    print("Camera mode: " .. (isFacingHead and "First Person" or "Third Person"))
                end
                return newOwnerFound
            end
        end
    end
    if not headNearby and player and player.head then
        local distToHead = Vec3.distance(camera.position, player.head.position)
        if distToHead < config.headDropRadius then
            local headPos = player.head.position
            local camPos = camera.position
            local camForward = camera.rotation:getForwardVector()
            local headToCam = (camPos - headPos):normalize()
            local isFacingHead = Vec3.dot(camForward, headToCam) < 0
            if isFacingHead then
                facingUser = true
                viewFlipped = false
                currentExtension = config.minExtension
                targetExtension = config.minExtension
                setViewpointMode(player)
            else
                setThirdPersonMode(player)
            end
            headNearby = true
            if debugMode then 
                print("Camera returned to original player")
                print("Camera mode: " .. (isFacingHead and "First Person" or "Third Person"))
            end
            return newOwnerFound
        end
    end
    if not headNearby then
        freeFloatingMode = true
        viewpointMode = false
        thirdPersonMode = false
        cameraInHand = false
        handHolding = nil
        updateNameTagsVisibility()
        if debugMode then print("Camera placed in free-floating mode") end
    end
    return newOwnerFound
end

--====================================
--         MAIN UPDATE LOOP         --
--====================================

function tick(dt)
    t = t + dt

    -- Delay forcing POV mode on startup to ensure player data is ready
    if not initialPovSet then
        initialDelay = initialDelay + dt
        if initialDelay >= 0.1 then  -- Adjust delay as needed
            local currentPlayer = getPlayerById(activePlayerId)
            if currentPlayer and currentPlayer.head then
                setViewpointMode(currentPlayer)
                initialPovSet = true
                if debugMode then print("Forced POV mode after startup delay.") end
            end
        end
    end

    if gravity and gravity.upDirection and gravity.upDirection ~= Vec3.zeroVector then
        worldUp = gravity.upDirection
    end

    if math.floor(t) % 5 == 0 then
        checkForOwnerPresence()
    end

    if not activePlayerId then
        activePlayerId = findAnyPlayer()
        if not activePlayerId then
            if debugMode then print("No player found to follow") end
            return
        end
        if debugMode then print("Now following player ID: " .. tostring(activePlayerId)) end
    end

    local currentPlayer = getPlayerById(activePlayerId)
    if not currentPlayer or not currentPlayer.head then
        activePlayerId = findAnyPlayer()
        if not activePlayerId then return end
        currentPlayer = getPlayerById(activePlayerId)
        if not currentPlayer or not currentPlayer.head then return end
        if debugMode then print("Switched to player ID: " .. tostring(activePlayerId)) end
    end

    local recallTriggered = processOwnerRecall(dt)
    if recallTriggered then
        return
    end

    local rightHandPos, rightHandRot = getHandPosition(currentPlayer, false)
    local leftHandPos, leftHandRot = getHandPosition(currentPlayer, true)
    local isRightTrigger = isTriggerPressed(currentPlayer, false)
    local isLeftTrigger = isTriggerPressed(currentPlayer, true)

    if viewpointMode then
        if rightHandPos and isRightTrigger then
            local distToHead = Vec3.distance(rightHandPos, currentPlayer.head.position)
            if distToHead <= config.headGrabRadius then
                if not isRightGrabAttempt and not isLeftGrabAttempt then
                    isRightGrabAttempt = true
                    grabAttemptTime = t
                    if debugMode then print("Right hand grab attempt started") end
                end
                if isRightGrabAttempt and (t - grabAttemptTime) >= config.grabDelayTime then
                    beginRightHandGrip(currentPlayer, rightHandPos, rightHandRot)
                    isRightGrabAttempt = false
                    isLeftGrabAttempt = false
                    grabAttemptTime = 0
                end
            else
                if isRightGrabAttempt then
                    isRightGrabAttempt = false
                    grabAttemptTime = 0
                    if debugMode then print("Right hand grab attempt canceled - out of range") end
                end
            end
        else
            if isRightGrabAttempt then
                isRightGrabAttempt = false
                grabAttemptTime = 0
                if debugMode then print("Right hand grab attempt canceled - trigger released") end
            end
        end

        if leftHandPos and isLeftTrigger then
            local distToHead = Vec3.distance(leftHandPos, currentPlayer.head.position)
            if distToHead <= config.headGrabRadius then
                if not isLeftGrabAttempt and not isRightGrabAttempt then
                    isLeftGrabAttempt = true
                    grabAttemptTime = t
                    if debugMode then print("Left hand grab attempt started") end
                end
                if isLeftGrabAttempt and (t - grabAttemptTime) >= config.grabDelayTime then
                    beginLeftHandGrip(currentPlayer, leftHandPos, leftHandRot)
                    isRightGrabAttempt = false
                    isLeftGrabAttempt = false
                    grabAttemptTime = 0
                end
            else
                if isLeftGrabAttempt then
                    isLeftGrabAttempt = false
                    grabAttemptTime = 0
                    if debugMode then print("Left hand grab attempt canceled - out of range") end
                end
            end
        else
            if isLeftGrabAttempt then
                isLeftGrabAttempt = false
                grabAttemptTime = 0
                if debugMode then print("Left hand grab attempt canceled - trigger released") end
            end
        end

        local headOffset = currentPlayer.head.rotation:rotateVector(config.viewpointOffset)
        camera.position = currentPlayer.head.position + headOffset
        camera.rotation = currentPlayer.head.rotation
        camera.hideNearestHead = config.hideHead
        updateNameTagsVisibility()
        camera.positionSmoothing = 0
    elseif thirdPersonMode then
        updateThirdPersonMode(currentPlayer, dt)
        if rightHandPos and isRightTrigger then
            local distToCamera = Vec3.distance(rightHandPos, camera.position)
            if distToCamera <= config.cameraGrabRadius then
                beginRightHandGrip(currentPlayer, rightHandPos, rightHandRot)
            end
        elseif leftHandPos and isLeftTrigger then
            local distToCamera = Vec3.distance(leftHandPos, camera.position)
            if distToCamera <= config.cameraGrabRadius then
                beginLeftHandGrip(currentPlayer, leftHandPos, leftHandRot)
            end
        end
    elseif cameraInHand then
        if handHolding == "right" then
            if isRightTrigger then
                updateRightHandGrip(currentPlayer, rightHandPos, rightHandRot, dt)
            else
                handleCameraRelease(currentPlayer)
            end
        elseif handHolding == "left" then
            if isLeftTrigger then
                updateLeftHandGrip(currentPlayer, leftHandPos, leftHandRot, dt)
            else
                handleCameraRelease(currentPlayer)
            end
        end
    elseif freeFloatingMode then
        if rightHandPos and isRightTrigger then
            local distToCamera = Vec3.distance(rightHandPos, camera.position)
            if distToCamera <= config.cameraGrabRadius then
                beginRightHandGrip(currentPlayer, rightHandPos, rightHandRot)
            end
        elseif leftHandPos and isLeftTrigger then
            local distToCamera = Vec3.distance(leftHandPos, camera.position)
            if distToCamera <= config.cameraGrabRadius then
                beginLeftHandGrip(currentPlayer, leftHandPos, leftHandRot)
            end
        end
        camera.positionSmoothing = 0
        camera.hideNearestHead = false
        updateNameTagsVisibility()
    end
end

--====================================
--              UI                  --
--====================================

function onGui()
    Gui.text("DRIFT VISION")
    Gui.text("by Pub | Nips")
    Gui.separator()

    Gui.text("== CAMERA STATUS ==")
    if config.ownerId then
        local ownerName = getPlayerName(config.ownerId)
        local ownerText = "Owner: " .. ownerName
        if ownerIsPresent then
            Gui.text(ownerText .. " [ONLINE]")
            displayOwnerRecallStatus()
        else
            Gui.text(ownerText .. " [OFFLINE]")
        end
    else
        Gui.text("No Owner Set")
    end

    local currentPlayerName = getPlayerName(activePlayerId)
    Gui.text("Following: " .. currentPlayerName)

    local stateText = "Mode: "
    if viewpointMode then
        stateText = stateText .. "First Person View"
        Gui.text(stateText)
        if isRightGrabAttempt or isLeftGrabAttempt then
            local progress = (t - grabAttemptTime) / config.grabDelayTime
            local progressPct = math.floor(progress * 100)
            Gui.text("Grab Progress: " .. progressPct .. "%")
        end
    elseif thirdPersonMode then
        stateText = stateText .. "Third Person Tracking"
        Gui.text(stateText)
        Gui.text("   Distance: " .. string.format("%.0f", config.thirdPersonDistance) .. "cm")
    elseif cameraInHand then
        local handText = (handHolding == "right" and "Right" or "Left") .. " Hand"
        local facingText = facingUser and "Facing User" or "Facing Away"
        local extText = string.format("%.0f", currentExtension) .. "cm"
        stateText = stateText .. "Handheld (" .. handText .. ")"
        Gui.text(stateText)
        Gui.text("   Direction: " .. facingText)
        Gui.text("   Extension: " .. extText)
    elseif freeFloatingMode then
        stateText = stateText .. "Free-Floating"
        Gui.text(stateText)
    else
        stateText = stateText .. "Unknown"
        Gui.text(stateText)
    end

    Gui.separator()

    Gui.text("== PLAYER SELECTION ==")
    searchText = Gui.inputText("Search Players", searchText)
    local players = getPlayers()
    local filteredPlayerNames = {}
    local filteredPlayerIds = {}
    for i = 1, #players do
        if playerMatchesSearch(players[i].name, searchText) then
            local displayName = players[i].name
            if players[i].id == activePlayerId then
                displayName = "► " .. displayName
            end
            if players[i].id == config.ownerId then
                displayName = displayName .. " (Owner)"
            end
            table.insert(filteredPlayerNames, displayName)
            table.insert(filteredPlayerIds, players[i].id)
        end
    end

    local currentSelection = 1
    if selectedPlayerId then
        for i = 1, #filteredPlayerIds do
            if filteredPlayerIds[i] == selectedPlayerId then
                currentSelection = i
                break
            end
        end
    end

    if #filteredPlayerNames > 0 then
        local selectedLabel = filteredPlayerNames[currentSelection]
        if Gui.beginCombo("Select Player", selectedLabel) then
            for i = 1, #filteredPlayerNames do
                local isSelected = (i == currentSelection)
                if Gui.selectable(filteredPlayerNames[i], isSelected) then
                    selectedPlayerId = filteredPlayerIds[i]
                    currentSelection = i
                end
            end
            Gui.endCombo()
        end

        if selectedPlayerId then
            if Gui.button("Follow Selected Player") then
                activePlayerId = selectedPlayerId
                config.currentPlayerId = activePlayerId
                saveConfig()
                local newPlayer = getPlayerById(activePlayerId)
                if newPlayer then
                    setViewpointMode(newPlayer)
                end
                if debugMode then
                    print("Now following player ID: " .. tostring(activePlayerId))
                end
            end

            Gui.sameLine()
            local isCurrentlyOwner = (selectedPlayerId == config.ownerId)
            local ownerButtonText = isCurrentlyOwner and "Clear Owner" or "Set as Owner"
            if Gui.button(ownerButtonText) then
                if isCurrentlyOwner then
                    config.ownerId = nil
                    ownerIsPresent = false
                    ownerPlayer = nil
                else
                    config.ownerId = selectedPlayerId
                    checkForOwnerPresence()
                end
                saveConfig()
            end
        end
    else
        if searchText ~= "" then
            Gui.text("No players match search")
        else
            Gui.text("No players found")
        end
    end

    Gui.separator()

    Gui.text("== QUICK ACTIONS ==")
    if Gui.button("Reset to Viewpoint Mode") then
        local player = getPlayerById(activePlayerId)
        if player then
            facingUser = true
            viewFlipped = false
            currentExtension = config.minExtension
            targetExtension = config.minExtension
            setViewpointMode(player)
        end
    end
    Gui.sameLine()
    if Gui.button("Switch to Third Person") then
        local player = getPlayerById(activePlayerId)
        if player then
            setThirdPersonMode(player)
        end
    end

    Gui.separator()

    Gui.text("== HOW TO USE ==")
    Gui.text("• Hold TRIGGER near your head for " .. string.format("%.1f", config.grabDelayTime) .. " sec to grab camera")
    Gui.text("• While holding camera, use GRIP to flip view 180°")
    Gui.text("• Use opposite hand's TRIGGER to extend camera out")
    Gui.text("• Use opposite hand's GRIP to pull camera in")
    Gui.text("• Release camera on your head when:")
    Gui.text("  - Camera facing you → First Person mode")
    Gui.text("  - Camera facing away → Third Person mode")
    Gui.text("• Use trigger near free camera to pick it up")
    Gui.text("• Drop on another player's head to transfer control")

    if config.ownerId then
        Gui.separator()
        Gui.text("Owner Controls:")
        Gui.text("• Hold any TRIGGER for " .. string.format("%.1f", config.ownerRecallTime) .. " sec to recall camera")
    end

    Gui.separator()

    if Gui.collapsingHeader("Camera Settings") then
        config.fov = Gui.sliderFloat("Field Of View", config.fov, 60, 150)
        config.hideHead = Gui.checkbox("Hide Head in First Person", config.hideHead)
        local nameTagTypeString = "Show Name Tags when not in POV"
        if config.nameTagType == 0 then
            nameTagTypeString = "Always show Name Tags"
        elseif config.nameTagType == 1 then
            nameTagTypeString = "Show Name Tags when not in POV"
        elseif config.nameTagType == 2 then
            nameTagTypeString = "Always hide Name Tags"
        end
        if Gui.beginCombo("Name Tags Visibility", nameTagTypeString) then
            local is0Selected = (config.nameTagType == 0)
            local is1Selected = (config.nameTagType == 1)
            local is2Selected = (config.nameTagType == 2)
            if Gui.selectable("Always show Name Tags", is0Selected) then
                config.nameTagType = 0
                updateNameTagsVisibility()
            end
            if Gui.selectable("Show Name Tags when not in POV", is1Selected) then
                config.nameTagType = 1
                updateNameTagsVisibility()
            end
            if Gui.selectable("Always hide Name Tags", is2Selected) then
                config.nameTagType = 2
                updateNameTagsVisibility()
            end
            Gui.endCombo()
        end

        Gui.text("View Offset:")
        config.viewpointOffset = Gui.dragFloat3("View Offset", config.viewpointOffset, 0.1, -10, 10)
        config.headGrabRadius = Gui.sliderFloat("Head Grab Range", config.headGrabRadius, 10, 100)
        config.headDropRadius = Gui.sliderFloat("Head Drop Range", config.headDropRadius, 10, 50)
        config.cameraGrabRadius = Gui.sliderFloat("Camera Grab Range", config.cameraGrabRadius, 10, 100)
        config.grabDelayTime = Gui.sliderFloat("Grab Delay Time (sec)", config.grabDelayTime, 0.0, 3.0)

        Gui.text("Third Person Settings:")
        config.thirdPersonDistance = Gui.sliderFloat("Camera Distance", config.thirdPersonDistance, 50, 500)

        Gui.text("Extension Arm Settings:")
        config.extensionEnabled = Gui.checkbox("Enable Extension Arm", config.extensionEnabled)
        config.minExtension = Gui.sliderFloat("Minimum Extension", config.minExtension, 0, 50)
        config.maxExtension = Gui.sliderFloat("Maximum Extension", config.maxExtension, 50, 500)
        config.extensionStep = Gui.sliderFloat("Extension Speed", config.extensionStep, 0.5, 20)
        config.extensionSmoothness = Gui.sliderFloat("Extension Smoothing", config.extensionSmoothness, 0, 0.95)

        Gui.text("View Flip Settings:")
        config.flipEnabled = Gui.checkbox("Enable Camera Flipping", config.flipEnabled)

        if config.ownerId then
            Gui.text("Owner Recall Settings:")
            config.ownerRecallTime = Gui.sliderFloat("Recall Hold Time (sec)", config.ownerRecallTime, 0.5, 6.0)
        end

        if Gui.button("Apply Settings") then
            if camera then
                camera.fieldOfView = config.fov
                camera.hideNearestHead = config.hideHead
                updateNameTagsVisibility()
            end
            saveConfig()
        end
    end

    Gui.separator()

    if Gui.button(debugMode and "Disable Debug Mode" or "Enable Debug Mode") then
        debugMode = not debugMode
    end

    if debugMode then
        if Gui.collapsingHeader("Debug Info") then
            Gui.text("Active Player ID: " .. tostring(activePlayerId))
            Gui.text("Selected Player ID: " .. tostring(selectedPlayerId))
            Gui.text("Config Player ID: " .. tostring(config.currentPlayerId))
            Gui.text("Owner ID: " .. tostring(config.ownerId))
            Gui.text("Owner Present: " .. tostring(ownerIsPresent))
            Gui.text("Viewpoint Mode: " .. tostring(viewpointMode))
            Gui.text("Third Person Mode: " .. tostring(thirdPersonMode))
            Gui.text("Camera In Hand: " .. tostring(cameraInHand))
            Gui.text("Holding Hand: " .. tostring(handHolding))
            Gui.text("Free-Floating Mode: " .. tostring(freeFloatingMode))
            Gui.text("Facing User: " .. tostring(facingUser))
            Gui.text("View Flipped: " .. tostring(viewFlipped))
            Gui.text("Current Extension: " .. string.format("%.2f", currentExtension))
            Gui.text("Target Extension: " .. string.format("%.2f", targetExtension))
            Gui.text("Right Hand Grab Attempt: " .. tostring(isRightGrabAttempt))
            Gui.text("Left Hand Grab Attempt: " .. tostring(isLeftGrabAttempt))
            if isRightGrabAttempt or isLeftGrabAttempt then
                local timeRemaining = config.grabDelayTime - (t - grabAttemptTime)
                Gui.text("Grab Time Remaining: " .. string.format("%.1f", timeRemaining) .. " sec")
            end

            if Gui.button("Force Rescan") then
                activePlayerId = nil
            end

            Gui.sameLine()

            if Gui.button("Clear Saved Player") then
                config.currentPlayerId = nil
                saveConfig()
            end

            if ownerIsPresent and Gui.button("Test Owner Recall") then
                activePlayerId = config.ownerId
                config.currentPlayerId = activePlayerId
                saveConfig()
                setViewpointMode(ownerPlayer)
            end

            Gui.sameLine()

            if Gui.button("Test Third Person") then
                local player = getPlayerById(activePlayerId)
                if player then
                    setThirdPersonMode(player)
                end
            end
        end
    end
end
