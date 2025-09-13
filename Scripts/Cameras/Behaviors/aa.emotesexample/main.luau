--!strict

local currentEmoteIdx = 1
local cycling = true
local maxEmoteIndex = 11
local lastCycleTime = os.clock()
local cycleInterval = 5

function onGui()
	currentEmoteIdx = Gui.sliderInt("Current Emote Idx", currentEmoteIdx, 0, maxEmoteIndex)
	if Gui.button("Set Emote") then
		camera:setEmote(currentEmoteIdx)
	end

	cycling = Gui.checkbox("Cycle through emotes", cycling)
end

function tick(dt)
	if cycling then
		if os.clock() - lastCycleTime > cycleInterval then
			currentEmoteIdx += 1
			if currentEmoteIdx > maxEmoteIndex then
				currentEmoteIdx = 0
			end
			lastCycleTime = os.clock()
			camera:setEmote(currentEmoteIdx)
		end
	end
end
