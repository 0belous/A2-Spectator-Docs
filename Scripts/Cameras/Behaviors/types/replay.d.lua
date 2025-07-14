--- Represents a single frame of game data.
declare class ReplayFrame
	--- Array of all balls in the game
	balls: {ReplayBall}
	--- Array of all players in the game
	players: {ReplayPlayer}
	--- Array of all spectators in the game
	spectators: {ReplaySpectator}
	time: number
	--- Gets a player by id. This id is generated when the player joins the server
	function getPlayerById(self, index: number): ReplayPlayer
	function getLocalPlayer(self): ReplayPlayer
	--- Gets a player by name
	function getPlayerByName(self, name: string): ReplayPlayer
	function toJson(self): string
end

--- This represents a player in game. The format is the same as player data in replay files.
declare class ReplayPlayer
	--- Arbitrary id for the player, given by the server when they join
	playerId: number
	--- The name of the player
	playerName: string
	--- True if this is the local player
	isLocalPlayer: boolean
	--- Transform of the player's rig
	root: ReplayTransform
	--- Transform of the player's camera position
	head: ReplayTransform
	--- Transform of the player's left hand
	leftHand: ReplayTransform
	--- Transform of the player's right hand
	rightHand: ReplayTransform
	--- Speed of the player's rig
	velocity: Vec3
	--- True if using the left hand thruster
	leftThrusterActive: boolean
	--- True if using the right hand thruster
	rightThrusterActive: boolean
	isBraking: boolean
	isBigBoosting: boolean
	teamIndex: number
	playerColor: TeamColor
	leftClimbing: boolean
	rightClimbing: boolean
	leftColliding: boolean
	rightColliding: boolean
	leftSliding: boolean
	rightSliding: boolean
	leftHandPosebits: number
	rightHandPosebits: number
	localClimbOffset: Vec3
	grabbedByAnotherPlayerCounter: number
	function toJson (self): string
end

--- This represents a spectator player in game.
declare class ReplaySpectator
	--- Arbitrary id for the player, given by the server when they join
	playerId: number
	--- True if this is the local player
	isLocalPlayer: boolean
	--- Pos/rot of the spectator
	transform: ReplayTransform
	function toJson (self): string
end

declare class ReplayBall
	transform: ReplayTransform
	velocity: Vec3
	arena: number
	function toJson (self): string
end

declare class ReplayTransform
	position: Vec3
	rotation: Quat
	function toJson (self): string
end

declare class TeamColor
	teamLogoIndex: number
	teamName: string
	teamRowId: string
end

--- Returns a ReplayFrame object representing the current game state
declare function getGameData(): ReplayFrame
--- Returns a list of ReplayFrames containing the current game state and the current game state of any active replays
declare function getAllGameData(): {ReplayFrame}


declare class Replay
	--- Should the time of this replay file automatically advance?
	isPlaying: boolean
	function setPlaybackTimestamp(self, timestamp: DateTime): ()
	function getPlaybackTimestamp(self): DateTime
	function setPlaybackTimeSeconds(self, time: number): ()
	function getPlaybackTimeSeconds(self): number
	--- The timestamp of the first frame in the replay
	function getStartTime(self): DateTime
	--- The timestamp of the last frame in the replay
	function getEndTime(self): DateTime
	--- The duration of the replay in seconds
	function getDurationSeconds(self): number
	function getFrameAtTimestamp(self, time: DateTime, interpolate: boolean): ReplayFrame
	function getFrameAtTimeSeconds(self, time: number, interpolate: boolean): ReplayFrame
	--- Gets the ReplayFrame at the current playback time. Setting interpolate to false will only return frames that are in the original data
	function getCurrentFrame(self, interpolate: boolean): ReplayFrame
end

declare Replay: {
	--- Loads a replay from the given fileName inside the standard replays folder. Returns a Replay object.
	load: (fileName: string) -> Replay,
	--- Loads a replay with the given subsampling hz - DEBUG: This will be removed in the future
	loadSubsampled: (fileName: string, subsampleHz:number) -> Replay,
	--- Unloads all replay files from memory.
	unloadAll: () -> (),
	--- Returns a list of all replay files in the standard replays folder.
	listAll: () -> {string},
	--- Returns a list of all replay files that have been loaded.
	listLoaded: () -> {string},
	--- Returns the replay object at the given index.
	getByIndex: (index: number) -> Replay?,
	--- Unloads the replay object at the given index.
	unloadByIndex: (index: number) -> (),
	--- Starts recording a replay file with an automatic file name. Returns false if the user has not allowed camera scripts to write replay files. 
	startRecording: () -> boolean,
	--- Stops recording the current replay file. Returns false if the user has not allowed camera scripts to write replay files. 
	stopRecording: () -> boolean,
}