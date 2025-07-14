declare class Settings end

declare Settings: {
	--- Whether or not the user has allowed camera scripts to write replay files. This is read-only.
	getLuauReplayControlAllowed: () -> boolean,
	--- Searches for a player by name and mutes/unmutes them if found. Returns true if the player was found.
	mutePlayerByName: (playerName: string, mute: boolean) -> boolean,
}