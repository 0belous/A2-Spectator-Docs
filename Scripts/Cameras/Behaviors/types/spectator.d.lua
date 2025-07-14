declare class GamemodeSlot
	slotId: string
	transform: Transform
end

--- This class represents this script's camera in game.
declare class SpectatorCamera
	--- The current position of the camera (before smoothing). Setting this will change the position of this camera in game.
	position: Vec3
	--- The current rotation of the camera (before smoothing). Setting this will change the rotation of this camera in game.
	rotation: Quat
	--- The current vertical field of view of the camera in degrees (before smoothing). Setting this will change the field of view of this camera in game.
	fieldOfView: number
	--- Whether this camera is set as the active camera. There can only be one active camera at a time.
	isActive: boolean
	--- This is true when another camera script is following this camera. Usually you want to enable your camera script inputs when this is true.
	isFollowed: boolean
	--- How much smoothing is applied to the position. This number is the time it takes for the position to reach 50% of the target value.
	positionSmoothing: number
	--- How much smoothing is applied to the rotation. This number is the time it takes for the rotation to reach 50% of the target value.
	rotationSmoothing: number
	--- How much smoothing is applied to the field of view. This number is the time it takes for the field of view to reach 50% of the target value.
	fieldOfViewSmoothing: number
	--- The angular distance offset (radians) for rotation to occur
	rotationDeadzone: number
	isTransitioning: boolean
	--- If name tags are visible in game. Defaults to true
	showNameTags: boolean
	--- The near clip plane of the camera. This is the closest distance that the camera will render objects.
	nearClippingPlane: number
	--- If the closest head to the camera should be visible
	hideNearestHead: boolean

	--- Gets the actual position of the camera after smoothing is applied. 
	function getSmoothedPosition(self): Vec3
	--- Gets the actual rotation of the camera after smoothing is applied. 
	function getSmoothedRotation(self): Quat
	--- Gets the actual field of view of the camera after smoothing is applied. 
	function getSmoothedFieldOfView(self): number
	--- Rotates the camera so the forward vector points at target position.
	function lookAt(self, target: Vec3, upVector: Vec3): ()
	--- Uses the global up vector (0, 1, 0) as the up vector.
	function lookAtBasic(self, target: Vec3): ()
	--- Once set, the camera will follow the target camera. If nil, the camera will stop following.
	function followCamera(self, target: SpectatorCamera): ()
	--- Once set, the camera will follow the target camera. If nil, the camera will stop following.
	function followCamera(self, target: nil): ()
	--- Performs a raycast starting at the startVector position and ending at the endVector position. Returns a RayHit object.
	function castRay(self, startVector: Vec3, endVector: Vec3): RayHit
	function castRayFromMouse(self): RayHit
	function getClosestGamemodeSlot(self): GamemodeSlot
	--- Shows or hides quest items and progress for the player(s) with the given player id.
	function showQuestsForPlayerById(self, playerId: number, showQuests: boolean): boolean
		--- Shows or hides quest items and progress for the player(s) with the given player name.
	function showQuestsForPlayerByName(self, playerName: string, showQuests: boolean): boolean
end

--- The camera object for this script.
declare camera: SpectatorCamera

--- Transitions are used by the game when switching between cameras.
declare class Transition
	--- The length of the transition in seconds.
	length: number
	easeIn: number
	easeOut: number
	startTime: number
	startPosition: Vec3
	startRotation: Quat
	startFieldOfView: number
	mode: string
	previousCamera: SpectatorCamera
end

declare class RayHit
	successful: boolean
	position: Vec3
	normal: Vec3
end

--- Returns a reference to the camera with the given identifier, e.g. "anotheraxiom.freecam"
declare function getCameraById(id: string): SpectatorCamera
--- Sends a message to the camera with the given identifier, e.g. "anotheraxiom.freecam". The message can be received by the camera's `OnMessageReceived()` function.
declare function sendMessage(camera: SpectatorCamera, message: any): ()

declare class GravityComponent
	--- The current gravity down vector in world space, scaled by the current gravity strength.
	gravity: Vec3
	--- The current gravity strength in cm/s^2.
	strength: number
	--- The current normalized gravity up vector in world space.
	upDirection: Vec3
	--- A Quaternion representing the current rotation of the gravity up vector.
	upRotation: Quat
end

declare gravity: GravityComponent


--- Saves the currently active camera's config to a file. Returns true if successful.
declare function saveConfig(): boolean
--- Saves the currently active camera's config to a file with the given name. The file name will be prepended by the camera identifier, e.g. "anotheraxiom.freecam.myconfig.json". This config will not be active unless you switch to it, which will requier setting a keybind. Returns true if successful.
-- declare function saveConfigAs(fileName: string): boolean

declare class PostProcessSettings
	--- Multiplier for all bloom contributions >=0: off, 1(default), >1 brighter
	bloomIntensity: number
	--- Minimum brightness the bloom starts having effect. 1:all pixels affect bloom equally (physically correct, faster as a threshold pass is omitted), 0:all pixels affect bloom brights more, 1(default), >1 brighter
	bloomThreshold: number
	--- Defines the opening of the camera lens, Aperture is 1/ fstop, typical lens go down to f/ 1.2 (large opening), larger numbers reduce the DOF effect
	depthOfFieldFstop: number
	--- Distance in which the Depth of Field effect should be sharp, in unreal units (cm)
	depthOfFieldFocalDistance: number
	--- Width of the camera sensor to assume, in mm.
	depthOfFieldSensorWidth: number
	--- In percent, Scene chromatic aberration / color fringe (camera imperfection) to simulate an artifact that happens in real-world lens, mostly visible in the image corners.
	chromaticAberrationIntensity: number
	--- Strength of motion blur, 0:off
	motionBlurAmount: number
	--- 0..1 0=off/ no vignette .. 1=strong vignette
	vignetteIntensity: number
	--- Logarithmic adjustment for the exposure. Only used if a tonemapper is specified. 0: no adjustment, -1:2x darker, -2:4x darker, 1:2x brighter, 2:4x brighter, ...
	autoExposureBias: number
	--- Reset post processing to its initial state
	function reset(self): ()
end

--- The post processing settings for this camera
declare postProcessSettings: PostProcessSettings

--- If this is set to true, the camera will always call the tick function, even if it's not active or being followed. The default behavior is to only tick when active or followed.
declare alwaysTick: boolean


-- Spectator Gamemodes
declare class SpectatorGamemodes
end

declare class SpectatorGamemodes_Class
	-- List Gamemodes
	listGamemodes: () -> { ModuleStateSpectatorLuaApi }
	-- List Gamemode Ids
	listGamemodeIds: () -> { string }
	-- Get Gamemode Data
	getGamemodeData: (SlotId: string) -> SpectatorGamemodeData
	-- Get Gamemode
	getGamemode: (SlotId: string) -> ModuleStateSpectatorLuaApi
end
declare SpectatorGamemodes: SpectatorGamemodes_Class

-- Spectator Luau APIs for the GameTimeComponent
declare class SpectatorGameTimeComponent
	-- Returns the shown time in decimal seconds
	function getTimeSeconds (self): number
	-- Returns the secondary shown time in decimal seconds
	function getSecondaryTimeSeconds (self): number
end

declare class SpectatorGameTimeComponent_Class
end
declare SpectatorGameTimeComponent: SpectatorGameTimeComponent_Class


-- Module State Spectator Lua Api
declare class ModuleStateSpectatorLuaApi
	-- Gets the current score for the specified team
	function getTeamScore (self, TeamIndex: number): number
	-- Gets the number of round wins for the specified team
	function getTeamRoundsWon (self, TeamIndex: number): number
	-- Get Team Colors Array
	function getTeamColorsArray (self): { TeamColor }
	-- Get Slot Id
	function getSlotId (self): string
	-- Get Is Game Running
	function getIsGameRunning (self): boolean
	-- Returns an object that contains game time information
	function getGameTimeComponent (self): SpectatorGameTimeComponent
end

declare class ModuleStateSpectatorLuaApi_Class
end
declare ModuleStateSpectatorLuaApi: ModuleStateSpectatorLuaApi_Class


-- Spectator Gamemode Team Data
declare class SpectatorGamemodeTeamData
	score: number
	roundsWon: number
end

declare class SpectatorGamemodeTeamData_Class
	new:
		((score: number, roundsWon: number) -> SpectatorGamemodeTeamData) &
		({score: number?, roundsWon: number?}) -> SpectatorGamemodeTeamData
end
declare SpectatorGamemodeTeamData: SpectatorGamemodeTeamData_Class


-- Spectator Gamemode Data
declare class SpectatorGamemodeData
	slotId: string
	timeSeconds: number
	secondaryTimeSeconds: number
	isGameRunning: boolean
	teams: { SpectatorGamemodeTeamData }
end

declare class SpectatorGamemodeData_Class
	new:
		((slotId: string, timeSeconds: number, secondaryTimeSeconds: number, bIsGameRunning: boolean, teams: { SpectatorGamemodeTeamData}) -> SpectatorGamemodeData) &
		({slotId: string?, timeSeconds: number?, secondaryTimeSeconds: number?, bIsGameRunning: boolean?, teams: { SpectatorGamemodeTeamData}?}) -> SpectatorGamemodeData
end
declare SpectatorGamemodeData: SpectatorGamemodeData_Class



-- Screenshot
declare class Screenshot
end

declare class Screenshot_Class
	-- Takes a high-res screenshot at a given resolution. Screenshots are saved to Documents/Another-Axiom/A2/Screenshots
	takeScreenshot: (width: number, height: number) -> string
end
declare Screenshot: Screenshot_Class


-- Utility functions for managing connections to game servers
declare class Network
end

declare class Network_Class
	-- Returns the name of the station we are currently connected to. Returns an empty string if not connected.
	getCurrentServer: () -> string
	-- Disconnects from the current server if connected. Returns true on success, false otherwise.
	disconnectFromServer: () -> boolean
	-- Connect to a game server using the given station name
	connectToServer: (stationName: string) -> boolean
end
declare Network: Network_Class


