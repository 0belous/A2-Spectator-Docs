--!strict
metadata = {
	name = "Animator",
	description = "A camera used to define camera animations",
	author = "Another Axiom",
	defaultKeybind = "M",
}

camera.positionSmoothing = 0
camera.rotationSmoothing = 0
camera.fieldOfViewSmoothing = 0

type propertySpline = {
	properties: { Vec2 }?,
	lut: { Vec2 }?,
}?

type Curve = {
	p1: Vec2?,
	p2: Vec2?,
	p3: Vec2?,
	p4: Vec2?,
	lut: { number }?,
}?

type AnimationRow = {
	name: string,
	childrenShown: boolean, -- +
	children: { AnimationRow? }, -- +
	interpolationMode: number,
	isGraphOpen: boolean,
	spline: propertySpline?, -- may be nil if not a leaf
}?

local rows = {}

function initializeRows(propertyTree)
	if propertyTree == nil then
		return {}
	end
	local children = {}
	if propertyTree.children then
		for i = 1, #propertyTree.children do
			children[i] = initializeRows(propertyTree.children[i])
		end
	end
	return {
		name = propertyTree.name,
		childrenShown = false,
		children = children,
		interpolationMode = 3,
		isGraphOpen = false,
		spline = { properties = nil, lut = nil },
	}
end

local propertiesTree = {
	name = "all",
	children = {
		{
			name = "position",
			children = {
				{ name = "position.x", children = {} },
				{ name = "position.y", children = {} },
				{ name = "position.z", children = {} },
			},
		},
		{
			name = "rotation",
			children = {
				{ name = "roll", children = {} },
				{ name = "pitch", children = {} },
				{ name = "yaw", children = {} },
			},
		},
		{ name = "field of view", children = {} },
		{ name = "depth of field", children = {} },
	},
}
rows = initializeRows(propertiesTree)

local interpModes = {
	"Global Default",
	"Linear",
	"Smooth",
	"Custom",
}
local globalInterpSettings = {
	smoothing = 1,
}
local quaternionInterpolateRotation = true

local timelineStart = 0
local timelineEnd = 20
local snapTimeInterval = 0.05
local rangeStartTime = 0
local rangeEndTime = 5
local playbackTime = 0
local scrollSpeed = 1

local lutPointsPerCurve = 20
local visualSplineLOD = 50
local visualizeLut = true

local animating = false
local editing = true
--local keyframeCache = {} -- save a list of the last few keyframe states to allow for undo

type Animation = {
	timelineStart: number?,
	timelineEnd: number?,
	globalSmoothing: number?,
	replays: { string }?,
	rows: { AnimationRow }?,
}?

local function traverseLeaves(root)
	local allRows = {}
	if root.children and #root.children > 0 then
		for i = 1, #root.children do
			local newRows = traverseLeaves(root.children[i])
			for j = 1, #newRows do
				allRows[#allRows + 1] = newRows[j]
			end
		end
		return allRows
	else
		return { root }
	end
end

local function traverse(root)
	local allRows = {}
	if root.children and #root.children > 0 then
		allRows[1] = root
		for i = 1, #root.children do
			local newRows = traverse(root.children[i])
			for j = 1, #newRows do
				allRows[#allRows + 1] = newRows[j]
			end
		end
		return allRows
	else
		return { root }
	end
end

function onGui()
	if Gui.collapsingHeader("Controls") then
		Gui.indent()
		Gui.text("Toggle playback:     Spacebar")
		Gui.unindent()
	end
	if Gui.collapsingHeader("Timeline Settings") then
		Gui.indent()
		local timelineStartEnd = Gui.dragFloat2("Playback start/end", Vec2.new(timelineStart, timelineEnd), 0.1, 0, timelineEnd + 10)
		timelineStart = timelineStartEnd.x
		timelineEnd = timelineStartEnd.y
		if timelineStart >= timelineEnd - 1 then
			timelineEnd = timelineEnd + 1
		end
		snapTimeInterval = Gui.dragFloat("Snap Time Interval", snapTimeInterval, 0.01, 0, 2)
		Gui.unindent()
	end
	if Gui.collapsingHeader("Interpolation Settings") then
		globalInterpSettings.smoothing = Gui.sliderFloat("Global Default Smoothing", globalInterpSettings.smoothing, 0, 1)
		Gui.setItemTooltip("Change how smooth the Global Default smoothing option is")
		quaternionInterpolateRotation = Gui.checkbox("Enable Quaternion-based rotation interpolation", quaternionInterpolateRotation)
		Gui.text("Add smoothing on top of animation:")
		Gui.indent()
		camera.positionSmoothing = Gui.sliderFloat("Position Smoothing", camera.positionSmoothing, 0, 1)
		camera.rotationSmoothing = Gui.sliderFloat("Rotation Smoothing", camera.rotationSmoothing, 0, 1)
		Gui.unindent()
	end
	Gui.newLine()
	if animating then
		if Gui.button(Icon.Pause) then
			animating = false
		end
	else
		if Gui.button(Icon.Play) then
			play()
		end
	end
	Gui.sameLine()
	if editing then
		if Gui.button(Icon.PenSquare) then
			editing = false
		end
		Gui.setItemTooltip("Exit freecam editing mode")
	else
		if Gui.button(Icon.PencilAlt) then
			editing = true
		end
		Gui.setItemTooltip("Enter freecam editing mode")
	end

	if Gui.beginTable("Animation Table", 3) then
		Gui.tableSetupColumn("Name")
		Gui.tableSetupColumn("Controls")
		Gui.tableSetupColumn("Timeline")
		Gui.tableHeadersRow()

		Gui.tableNextColumn()
		-- select replay to animate
		local replays = Replay.listAll()
		if Gui.beginCombo("##replay selector", "add a replay...") then
			for i, replay in replays do
				if Gui.selectable(replay, false) then
					addReplay(replay)
				end
			end
			Gui.endCombo()
		end
		Gui.tableNextColumn()
		Gui.tableNextColumn()
		local range = Gui.rangeSlider("timelineRange", Vec2.new(rangeStartTime, rangeEndTime), timelineStart, timelineEnd)
		rangeStartTime = range.x
		rangeEndTime = range.y
		playbackTime = Gui.timeline("timeline", playbackTime, roundUp(rangeStartTime, snapTimeInterval), rangeEndTime, snapTimeInterval)

		Gui.tableNextColumn()
		renderRowsRecursive(rows, 0)
		Gui.endTable()
	end
	if Gui.button("Reset All") then
		load(config.savedAnimation)
	end
	Gui.sameLine()
	if Gui.button(Icon.Save) then
		saveToConfig()
	end
	Gui.setItemTooltip("Save")
	Gui.sameLine()
	if Gui.button("Clear All") then
		rows = initializeRows(propertiesTree)
	end
end

function addReplay(replayName: string): boolean
	if not rows.children then
		return false
	end
	local replayDropdown = getProperty("replays")
	if not replayDropdown then
		table.insert(rows.children, {
			name = "replays",
			childrenShown = true,
			children = {},
			interpolationMode = 3,
			isGraphOpen = false,
			spline = { properties = nil, lut = nil },
		})
		replayDropdown = getProperty("replays")
	end
	if not replayDropdown or not replayDropdown.children then
		return false
	end
	-- don't allow duplicate replays for now
	for i, child in replayDropdown.children do
		if child and child.name == replayName then
			return false
		end
	end

	table.insert(replayDropdown.children, {
		name = replayName,
		childrenShown = false,
		children = {},
		interpolationMode = 3,
		isGraphOpen = false,
		spline = { properties = nil, lut = nil },
	})
	return true
end

function removeReplay(replayName: string): boolean
	if not rows.children then
		return false
	end
	local replayDropdown = getProperty("replays")
	if not replayDropdown or not replayDropdown.children then
		return false
	end
	for i, child in replayDropdown.children do
		if child and child.name == replayName then
			table.remove(replayDropdown.children, i)
			unloadReplayByName(replayName)
			break
		end
	end
	-- remove replays dropdown if there are no more replays under it
	if #replayDropdown.children <= 0 then
		for i, child in rows.children do
			if child and child.name == "replays" then
				table.remove(rows.children, i)
			end
		end
	end
	return true
end

-- unloads all replays with a given name
function unloadReplayByName(replayName: string)
	local loadedReplays = Replay.listLoaded()
	for i = 1, #loadedReplays do
		local reversedI = #loadedReplays + 1 - i
		if loadedReplays[reversedI]:sub(-#replayName) == replayName then
			Replay.unloadByIndex(reversedI)
		end
	end
end

function traverseDownAndCollectPoints(root)
	local xValues = {}
	local seenX = {}
	for i, row in ipairs(traverseLeaves(root)) do
		for j, p in ipairs(getKeyframesFromGraph(row.spline.properties)) do
			-- add to table unless it's a duplicate
			local alignedX = alignTo(p.x, snapTimeInterval)
			if not seenX[alignedX] then
				table.insert(xValues, alignTo(alignedX, snapTimeInterval))
				seenX[alignedX] = true
			end
		end
	end
	local allPoints = {} -- x is only meaningful value, y is always zero
	for _, xVal in ipairs(xValues) do
		table.insert(allPoints, Vec2.new(xVal, 0))
	end
	return allPoints
end

function copySpline(spline: propertySpline): propertySpline
	local splineCopy = { properties = {}, lut = nil }

	if not spline or not spline.properties then
		return splineCopy
	end
	for i = 1, #spline.properties do
		splineCopy.properties[i] = Vec2.new(spline.properties[i].x, spline.properties[i].y)
	end
	return splineCopy
end

function dragPoints(points: { Vec2 }, dragDelta: number, childSpline: propertySpline): propertySpline
	local returnSpline = copySpline(childSpline)
	for _, point in ipairs(points) do
		local kfIndex = keyframeAtTime(returnSpline, point.x)
		if kfIndex ~= -1 and returnSpline and returnSpline.properties and childSpline and childSpline.properties then
			returnSpline.properties[kfIndex * 3 - 1].x = childSpline.properties[kfIndex * 3 - 1].x + dragDelta
		end
	end
	return returnSpline
end

local wasDragging = {}
local dragCopies = {}
local dragParentCopy = {}
function renderRowsRecursive(row, depth)
	if row == nil then
		return
	end
	-- Spacing based on depth
	Gui.text(string.rep(" ", 2 * depth))
	Gui.sameLine()

	if #row.children ~= 0 then
		-- row is not a leaf, so it can be expanded or minimized
		if row.childrenShown then
			if Gui.button(Icon.CaretDown .. "##" .. row.name) then
				row.childrenShown = false
			end
		else
			if Gui.button(Icon.CaretRight .. "##" .. row.name) then
				row.childrenShown = true
			end
		end
	end
	Gui.sameLine()
	-- Property name
	Gui.text(row.name)

	-- press x to remove replay
	local replayExists = false
	local replayDropdown = getProperty("replays")
	if replayDropdown and replayDropdown.children then
		for i, child in replayDropdown.children do
			if child and child.name == row.name then
				replayExists = true
				break
			end
		end
	end
	if replayExists then
		Gui.sameLine()
		if Gui.smallButton("x##removereplay" .. row.name) then
			removeReplay(row.name)
		end
	end
	Gui.tableNextColumn()

	local rangeStartTimeRounded = roundUp(rangeStartTime, snapTimeInterval)
	if row.children and #row.children ~= 0 then
		-- Row has children (no data / metarow)
		local subPoints = traverseDownAndCollectPoints(row)
		local hoveredKf = pointAtX(subPoints, playbackTime)
		if hoveredKf == -1 then
			if Gui.button(Icon.Plus .. "##" .. row.name) then
				addPointRecursive(row, playbackTime)
				updateAllSplineLuts()
			end
			Gui.setItemTooltip("Add a keyframe")
		else
			if Gui.button(Icon.Minus .. "##" .. row.name) then
				removePointRecursive(row, playbackTime)
				updateAllSplineLuts()
			end
			Gui.setItemTooltip("Remove a keyframe")
		end
		Gui.sameLine()
		if Gui.beginCombo("##" .. row.name, interpModes[row.interpolationMode]) then
			for j = 1, #interpModes do
				if Gui.selectable(interpModes[j], j == row.interpolationMode) then
					row.interpolationMode = j
					setInterpModeRecursive(row, j)
				end
			end
			Gui.endCombo()
		end
		if row.name == "rotation" and quaternionInterpolateRotation then
			-- only linear and smooth are allowed
			if row.interpolationMode == 1 or row.interpolationMode == 4 then
				row.interpolationMode = 3
			end
		end
		Gui.tableNextColumn()
		local keyframeRowID = "keyframeRow" .. row.name
		-- if one of the dragged points is over another point, add another dummy point
		if wasDragging[keyframeRowID] and #dragParentCopy < #subPoints then
			for i, point in ipairs(dragParentCopy) do
				local selectedKfs = Gui.keyframeRowSelectedKeyframes(keyframeRowID)
				if pointAtX(subPoints, point.x) ~= selectedKfs[i] then
					table.insert(subPoints, subPoints[#subPoints])
				end
			end
		end
		local newSubPoints = Gui.keyframeRow(keyframeRowID, subPoints, playbackTime, rangeStartTimeRounded, rangeEndTime, snapTimeInterval)
		-- handle dragging of parent keyframes
		if Gui.keyframeRowIsDragging(keyframeRowID) then
			local selectedKfs = Gui.keyframeRowSelectedKeyframes(keyframeRowID)
			if not wasDragging[keyframeRowID] then
				-- runs once when dragging starts
				wasDragging[keyframeRowID] = true
				-- create a copy of all the row data for all the children
				local leaves = traverseLeaves(row)
				for _, leaf in leaves do
					dragCopies[leaf.name] = copySpline(leaf.spline)
				end
				-- copy of parent points
				local allParentPoints = {}
				dragParentCopy = {}
				for i, point in ipairs(subPoints) do
					allParentPoints[i] = Vec2.new(point.x, point.y)
				end
				for _, kfIndex in ipairs(selectedKfs) do
					if allParentPoints[kfIndex] then
						table.insert(dragParentCopy, allParentPoints[kfIndex])
					end
				end
			end
			local firstSelectedKf = selectedKfs[1]
			local dragDelta = newSubPoints[firstSelectedKf].x - dragParentCopy[1].x
			local leaves = traverseLeaves(row)
			for _, leaf in leaves do
				leaf.spline = dragPoints(dragParentCopy, dragDelta, dragCopies[leaf.name])
			end
		else
			wasDragging[keyframeRowID] = false
		end
	else
		-- Leaf row
		-- Property Controls
		-- Add/remove a keyframe
		if not (quaternionInterpolateRotation and (row.name == "pitch" or row.name == "yaw" or row.name == "roll")) then
			local hoveredKf = keyframeAtTime(row.spline, playbackTime)
			local valueAtPlayhead = evalSpline(playbackTime, row.spline)
			if hoveredKf == -1 then
				if Gui.button(Icon.Plus .. "##" .. row.name) then
					writePoint(row.spline, playbackTime, getRealValue(row.name))
				end
				Gui.setItemTooltip("Add a keyframe##2")
			else
				if Gui.button(Icon.Minus .. "##" .. row.name) then
					removePoint(row.spline, hoveredKf)
				end
				Gui.setItemTooltip("Remove a keyframe##2")
			end
			Gui.sameLine()
			if Gui.beginCombo("##" .. row.name, interpModes[row.interpolationMode]) then
				for j = 1, #interpModes do
					if Gui.selectable(interpModes[j], j == row.interpolationMode) then
						row.interpolationMode = j
					end
				end
				Gui.endCombo()
			end
			Gui.sameLine()
			if not row.spline or not row.spline.properties or #row.spline.properties <= 0 then
				Gui.beginDisabled()
				row.isGraphOpen = false
			end
			if Gui.button(Icon.ChartLine .. "##" .. row.name) then
				row.isGraphOpen = not row.isGraphOpen
			end
			if not row.spline or not row.spline.properties or #row.spline.properties <= 0 then
				Gui.setItemTooltip("Add points to view graph")
				Gui.endDisabled()
			else
				if row.isGraphOpen then
					Gui.setItemTooltip("Close graph view")
				else
					Gui.setItemTooltip("Open graph view")
				end
			end
			Gui.sameLine()
			Gui.text(string.format("%.2f", valueAtPlayhead))
		else
			-- for quaternion interpolated rotation keyframes, just show values and no controls
			local valueAtPlayhead = 0
			local rotEval = evalRotationSquad(playbackTime)
			if rotEval then
				if row.name == "roll" then
					valueAtPlayhead = rotEval:euler().x
				end
				if row.name == "pitch" then
					valueAtPlayhead = rotEval:euler().y
				end
				if row.name == "yaw" then
					valueAtPlayhead = rotEval:euler().z
				end
			end
			Gui.text(string.format("%.2f", valueAtPlayhead))
		end
		Gui.tableNextColumn()

		if interpModes[row.interpolationMode] == "Custom" and row.isGraphOpen then
			Gui.beginDisabled()
		end
		local keyframeRowID = "keyframeRow" .. row.name
		if not row.spline then
			return
		end
		if not row.spline.properties then
			row.spline.properties = {}
		end
		if not row.spline.properties then
			return
		end
		local onCurvePoints = Gui.keyframeRow(
			keyframeRowID,
			getKeyframesFromGraph(row.spline.properties),
			playbackTime,
			rangeStartTimeRounded,
			rangeEndTime,
			snapTimeInterval
		)
		if interpModes[row.interpolationMode] == "Custom" and row.isGraphOpen then
			Gui.endDisabled()
		end
		-- merge keyframes in the same position
		if not Gui.keyframeRowIsDragging(keyframeRowID) then
			onCurvePoints = mergeAlignDuplicateX(onCurvePoints)
		end

		-- Graph
		updateGraphPoints(onCurvePoints, row.spline.properties, row.interpolationMode)
		if row.isGraphOpen then
			if interpModes[row.interpolationMode] ~= "Custom" then
				Gui.beginDisabled()
			end
			Gui.text("test " .. row.name)
			local graphOutput = prependFirstPoint(
				Gui.graphEditor(
					"graphEditor" .. row.name,
					ignoreFirstPoint(sortByXBezier(row.spline.properties)),
					playbackTime,
					rangeStartTimeRounded,
					rangeEndTime,
					snapTimeInterval
				)
			)
			if interpModes[row.interpolationMode] == "Custom" then
				row.spline.properties = graphOutput
			end
			if interpModes[row.interpolationMode] ~= "Custom" then
				Gui.endDisabled()
			end
		end
	end

	-- Recursively handle children
	if row.childrenShown and row.children then
		for i = 1, #row.children do
			Gui.tableNextRow()
			Gui.tableNextColumn()
			if row.children[i] then
				renderRowsRecursive(row.children[i], depth + 1)
			end
		end
	end
end

function mergeAlignDuplicateX(points: { Vec2 }): { Vec2 }
	local seenX = {}
	local mergedTable = {}
	for i, p in ipairs(points) do
		local alignedX = alignTo(p.x, snapTimeInterval)
		if not seenX[alignedX] then
			table.insert(mergedTable, Vec2.new(alignedX, p.y))
			seenX[alignedX] = true
		end
	end
	return mergedTable
end

function keyframeAtTime(spline: propertySpline, time: number): number
	if not spline or not spline.properties then
		return -1
	end
	local onCurvePoints = getKeyframesFromGraph(spline.properties)
	if #onCurvePoints < 1 then
		return -1
	end
	for i, point in ipairs(onCurvePoints) do
		if math.abs(point.x - time) < snapTimeInterval / 2 then
			return i
		end
	end
	return -1
end
function pointAtX(points: { Vec2 }, xVal: number): number
	if #points < 1 then
		return -1
	end
	for i, point in ipairs(points) do
		if math.abs(point.x - xVal) < snapTimeInterval / 2 then
			return i
		end
	end
	return -1
end

local function lerp(a: number, b: number, t: number): number
	return a * (1.0 - t) + b * t
end

-- Use a lookup table to efficiently approximate a spline's value at a given time (x)
function evalSpline(time: number, spline: propertySpline): number
	if not spline then
		return 0
	end
	if not spline.lut or #spline.lut == 0 then
		spline.lut = updateSplineLut(spline)
	end
	if not spline.lut or #spline.lut == 0 then
		return 0
	end
	if spline.lut[1].x >= time then
		return spline.lut[1].y
	end
	if spline.lut[#spline.lut].x <= time then
		return spline.lut[#spline.lut].y
	end

	-- linear search
	for i = 1, #spline.lut - 1, 1 do
		-- Check if our time is between the two adjacent points
		if spline.lut[i].x <= time and spline.lut[i + 1].x > time then
			local alpha = (time - spline.lut[i].x) / (spline.lut[i + 1].x - spline.lut[i].x)
			local interpValue = lerp(spline.lut[i].y, spline.lut[i + 1].y, alpha)
			return interpValue
		end
	end
	return 0
end

function getClosestLutPoint(spline: propertySpline, time: number): number -- closest without going over if possible
	if not spline or not spline.lut then
		return -1
	end
	local left = 1
	local right = #spline.lut

	while left <= right do
		local mid = (left + right) // 2
		if spline.lut[mid].x == time then
			return mid
		elseif spline.lut[mid].x < time then
			left = mid + 1
		else
			right = mid - 1
		end
	end
	return left
end

function updateSplineLut(spline: propertySpline): { Vec2 }
	if not spline then
		return {}
	end
	if not spline.properties then
		spline.properties = {}
	end
	if not spline.properties then
		return {}
	end
	local lutPoints = {}
	local sortedProperties = sortByX(spline.properties)
	if #sortedProperties == 0 then
		return {}
	end
	if #sortedProperties <= 3 then
		table.insert(lutPoints, Vec2.new(sortedProperties[1].x, sortedProperties[1].y))
	end
	-- Loop through each curve
	for i = 2, #sortedProperties - 4, 3 do
		local p1 = sortedProperties[i]
		local p2 = sortedProperties[i + 1]
		local p3 = sortedProperties[i + 2]
		local p4 = sortedProperties[i + 3]

		for j = 1, lutPointsPerCurve do
			local t = j / lutPointsPerCurve
			local point =
				Vec2.lerp(Vec2.lerp(Vec2.lerp(p1, p2, t), Vec2.lerp(p2, p3, t), t), Vec2.lerp(Vec2.lerp(p2, p3, t), Vec2.lerp(p3, p4, t), t), t)
			table.insert(lutPoints, point)
		end
	end
	return lutPoints
end

function updateAllSplineLuts()
	if not rows then
		return
	end
	for i, row in ipairs(traverseLeaves(rows)) do
		if row and row.spline then
			row.spline.lut = updateSplineLut(row.spline)
		end
	end
end

function sortByX(arr: { Vec2 }): { Vec2 }
	local copy = {}
	for i = 1, #arr do
		copy[i] = Vec2.new(arr[i].x, arr[i].y)
	end

	for i = 2, #copy do
		local key = copy[i]
		local j = i - 1

		while j > 0 and copy[j].x > key.x do
			copy[j + 1] = copy[j]
			j = j - 1
		end
		copy[j + 1] = key
	end
	return copy
end
function sortByXBezier(arr: { Vec2 }): { Vec2 } -- Sorts control points with adjacent points following.
	local points = {}
	if #arr <= 0 then
		return points
	end
	local triplets = {}
	for i = 1, #arr, 3 do
		if #arr - i >= 2 then
			table.insert(triplets, { arr[i], arr[i + 1], arr[i + 2] })
		end
	end
	table.sort(triplets, function(a, b)
		return a[2].x < b[2].x
	end)

	for _, triplet in ipairs(triplets) do
		for _, p in ipairs(triplet) do
			table.insert(points, Vec2.new(p.x, p.y))
		end
	end
	return points
end

-- Function to check if a list contains a specific value. If it exists, it returns the index
function findIndexInList(list, value)
	for i, v in ipairs(list) do
		if v == value then
			return i
		end
	end
	return -1
end

-- Find the index of the first instance of a replay that is loaded
function findReplayIndex(name: string): number
	for i, v in ipairs(Replay.listLoaded()) do
		-- check if string (file path) ends with the replay name
		if v:sub(-#name) == name then
			return i
		end
	end
	return -1
end

function ignoreFirstPoint(points: { Vec2 }): { Vec2 }
	if #points <= 0 then
		return {}
	end
	local smallerList = {}
	for i = 2, #points do
		table.insert(smallerList, points[i])
	end
	return smallerList
end

function prependFirstPoint(points: { Vec2 }): { Vec2 }
	if #points <= 0 then
		return {}
	end
	local largerList = { Vec2.zeroVector }
	--table.insert(largerList, otherList[1])
	for i = 1, #points do
		table.insert(largerList, points[i])
	end
	return largerList
end

function listOfOnCurveCtrlPointsToGraph(string, points): propertySpline
	-- sets up linear control points
	local biggerList = {}
	for i = 1, #points - 2 do
		table.insert(biggerList, points[i])
		table.insert(biggerList, points[i])
		table.insert(biggerList, points[i + 1])
	end
	table.insert(biggerList, points[#points])
	return { properties = biggerList, lut = {} }
end

function getKeyframesFromGraph(points: { Vec2 }): { Vec2 }
	if points == nil then
		return {}
	end

	local smallerList = {}
	for i = 2, #points, 3 do
		table.insert(smallerList, points[i])
	end
	return smallerList
end

local sortedIndices = {}

function updateGraphPoints(onCurvePoints: { Vec2 }, graphPoints: { Vec2 }, currentMode: number)
	if graphPoints == nil then
		graphPoints = {}
	end
	if #onCurvePoints == 0 then
		graphPoints = {}
		return
	end
	local offset = 1
	if interpModes[currentMode] == "Global Default" then
		local sortedIndices = {}
		for i = 1, #onCurvePoints do
			table.insert(sortedIndices, i)
		end
		table.sort(sortedIndices, function(a, b)
			return onCurvePoints[a].x < onCurvePoints[b].x
		end)
		local tension = 0.33 * globalInterpSettings.smoothing
		for i = 1, #onCurvePoints do
			local j = sortedIndices[i]
			if i < 2 then
				-- left edge (no easing)
				graphPoints[j * 3 - 1 + offset] = onCurvePoints[j]
			elseif i > #onCurvePoints - 1 then
				-- right edge (easing)
				local vec = Vec2.new(onCurvePoints[sortedIndices[i]].x - onCurvePoints[sortedIndices[i - 1]].x, 0)
				graphPoints[j * 3 - 3 + offset] = onCurvePoints[j] - vec * tension
				graphPoints[j * 3 - 1 + offset] = onCurvePoints[j]
			else
				-- everywhere in the middle
				local leftCurveWidth = onCurvePoints[j].x - onCurvePoints[sortedIndices[i - 1]].x
				local rightCurveWidth = onCurvePoints[sortedIndices[i + 1]].x - onCurvePoints[j].x
				local vec = onCurvePoints[sortedIndices[i + 1]] - onCurvePoints[sortedIndices[i - 1]]
				local a = lerp(0, 1, leftCurveWidth / (leftCurveWidth + rightCurveWidth))
				graphPoints[j * 3 - 3 + offset] = onCurvePoints[j] - vec * tension * a -- left
				graphPoints[j * 3 - 1 + offset] = onCurvePoints[j] + vec * tension * (1 - a) -- right
			end
			graphPoints[i * 3 - 2 + offset] = onCurvePoints[i] -- on curve
		end
		graphPoints[#graphPoints] = onCurvePoints[#onCurvePoints]
	elseif interpModes[currentMode] == "Linear" then
		for i = 1, #onCurvePoints - 1 do
			graphPoints[i * 3 - 1 + offset] = onCurvePoints[i]
			graphPoints[i * 3 + offset] = onCurvePoints[i + 1]
			graphPoints[i * 3 - 2 + offset] = onCurvePoints[i]
		end
		graphPoints[#graphPoints] = onCurvePoints[#onCurvePoints]
	elseif interpModes[currentMode] == "Smooth" then
		table.clear(graphPoints)
		sortedIndices = {}
		for i = 1, #onCurvePoints do
			table.insert(sortedIndices, i)
		end
		table.sort(sortedIndices, function(a, b)
			return onCurvePoints[a].x < onCurvePoints[b].x
		end)
		graphPoints[sortedIndices[1] * 3 - 1 + offset] = onCurvePoints[sortedIndices[1]]
		local tension = 0.33
		for i = 1, #onCurvePoints do
			local center = i --sortedIndices[i]
			local left = 0
			local right = 0
			for unsortedIndex, sortedIndex in ipairs(sortedIndices) do
				if sortedIndex == center then
					left = sortedIndices[unsortedIndex - 1]
					right = sortedIndices[unsortedIndex + 1]
					break
				end
			end
			if not left then --i < 2 then
				-- left edge (no easing)
				graphPoints[i * 3 - 1 + offset] = onCurvePoints[center] -- right
				if i * 3 - 3 + offset >= 0 then
					graphPoints[i * 3 - 3 + offset] = onCurvePoints[center]
				end
			elseif not right then --i > #onCurvePoints - 1 then
				-- right edge (easing)
				local vec = Vec2.new(onCurvePoints[center].x - onCurvePoints[left].x, 0)
				graphPoints[i * 3 - 3 + offset] = onCurvePoints[center] - vec * tension -- left
				graphPoints[i * 3 - 1 + offset] = onCurvePoints[center] -- right
			else
				-- everywhere in the middle
				local leftCurveWidth = onCurvePoints[center].x - onCurvePoints[left].x
				local rightCurveWidth = onCurvePoints[right].x - onCurvePoints[center].x
				local vec = onCurvePoints[right] - onCurvePoints[left]
				local a = lerp(0, 1, leftCurveWidth / (leftCurveWidth + rightCurveWidth))
				graphPoints[i * 3 - 3 + offset] = onCurvePoints[center] - vec * tension * a -- left
				graphPoints[i * 3 - 1 + offset] = onCurvePoints[center] + vec * tension * (1 - a) -- right
			end
			graphPoints[i * 3 - 2 + offset] = onCurvePoints[i] -- on curve
		end
	elseif interpModes[currentMode] == "Custom" then
	end
end

function alignTo(x: number, alignment: number): number
	if alignment == 0 then
		return x
	end
	return math.round(x / alignment) * alignment
end

function writePoint(spline: propertySpline, time: number, newValue: number)
	-- Overwrite value if the point already exists and adjust control points as necessary
	if not newValue or not spline or not time then
		return
	end
	if not spline.properties then
		spline.properties = {}
	end
	if not spline.properties then
		return
	end

	time = alignTo(time, snapTimeInterval)
	local i = keyframeAtTime(spline, time)
	if i ~= -1 then
		-- there was another keyframe at this location already, so it should be overwritten
		local deltaY = newValue - spline.properties[i].y
		spline.properties[i] = Vec2.new(spline.properties[i].x, spline.properties[i].y + deltaY)
		if i > 1 then
			spline.properties[i - 1] = Vec2.new(spline.properties[i - 1].x, spline.properties[i - 1].y + deltaY)
		end
		if i < #spline.properties then
			spline.properties[i + 1] = Vec2.new(spline.properties[i + 1].x, spline.properties[i + 1].y + deltaY)
		end
		spline.properties = sortByXBezier(spline.properties)
		return
	end
	-- Add new point if it doesn't already exist
	table.insert(spline.properties, Vec2.new(time, newValue))
	table.insert(spline.properties, Vec2.new(time, newValue))
	table.insert(spline.properties, Vec2.new(time, newValue))
	spline.properties = sortByXBezier(spline.properties)
	spline.lut = updateSplineLut(spline)
end

function removePoint(spline: propertySpline, index: number)
	if not spline or not spline.properties then
		return
	end
	local adjustedIndex = 3 * index - 2
	table.remove(spline.properties, adjustedIndex)
	if adjustedIndex <= #spline.properties then
		table.remove(spline.properties, adjustedIndex)
	end
	if adjustedIndex >= 1 then
		table.remove(spline.properties, adjustedIndex)
	end
	spline.lut = updateSplineLut(spline)
end

function copyTree(root: AnimationRow): AnimationRow
	if not root then
		return nil
	end
	local row = {
		name = root.name,
		childrenShown = root.childrenShown,
		children = {},
		interpolationMode = root.interpolationMode,
		isGraphOpen = root.isGraphOpen,
		spline = { properties = {}, lut = {} },
	}
	if root.spline and root.spline.properties then
		row.spline = { properties = {}, lut = {} }
		for i = 1, #root.spline.properties do
			table.insert(row.spline.properties, Vec2.new(root.spline.properties[i].x, root.spline.properties[i].y))
		end
	end

	if root.children and #root.children > 0 then
		for i = 1, #root.children do
			table.insert(row.children, copyTree(root.children[i]))
		end
	end
	return row
end

function saveToConfig()
	print("saving!")
	local saveTable = {}
	for i, row in ipairs(traverse(rows)) do
		saveTable[i] = {}
		saveTable[i]["name"] = row.name
		saveTable[i]["interpMode"] = row.interpolationMode
		saveTable[i]["properties"] = {}
		if row.spline and row.spline.properties then
			for j, point in ipairs(row.spline.properties) do
				saveTable[i]["properties"][j] = Vec2.new(point.x, point.y)
			end
		end
	end
	config.savedAnimation = saveTable
	saveConfig()
end

function getProperty(name: string): AnimationRow?
	for i, row in ipairs(traverse(rows)) do
		if row and row.name == name then
			return row
		end
	end
	return nil
end

function load(anim)
	rows = initializeRows(propertiesTree)
	if not config.savedAnimation or #config.savedAnimation == 0 then
		return
	end
	for i, row in ipairs(config.savedAnimation) do
		local propRow = getProperty(row["name"])
		if propRow and propRow.spline then
			propRow.spline.properties = row["properties"]
			propRow.interpolationMode = row["interpMode"]
		end
	end
end

function tick(dt)
	WorldDraw.clear()
	if Input.getKeyDown(Input.Key.SpaceBar) then
		if animating then
			animating = false
		else
			play()
		end
	end
	if animating then
		playbackTime += dt
	end
	local cameraRotEuler = camera.rotation:euler()

	-- UI
	local scrollAmount = (rangeEndTime - rangeStartTime) * scrollSpeed * dt
	if playbackTime > rangeEndTime and rangeEndTime < timelineEnd then
		rangeStartTime += scrollAmount
		rangeEndTime += scrollAmount
	end
	if playbackTime < rangeStartTime and rangeStartTime > timelineStart then
		rangeStartTime -= scrollAmount
		rangeEndTime -= scrollAmount
	end

	for i, row in ipairs(traverse(rows)) do
		-- apply spline data
		local name = row.name
		if name == nil then
			return
		elseif name == "position.x" then
			camera.position = Vec3.new(updateProperty(row, camera.position.x), camera.position.y, camera.position.z)
		elseif name == "position.y" then
			camera.position = Vec3.new(camera.position.x, updateProperty(row, camera.position.y), camera.position.z)
		elseif name == "position.z" then
			camera.position = Vec3.new(camera.position.x, camera.position.y, updateProperty(row, camera.position.z))
		elseif name == "roll" and not quaternionInterpolateRotation then
			cameraRotEuler.x = updateProperty(row, cameraRotEuler.x)
		elseif name == "pitch" and not quaternionInterpolateRotation then
			cameraRotEuler.y = updateProperty(row, cameraRotEuler.y)
		elseif name == "yaw" and not quaternionInterpolateRotation then
			cameraRotEuler.z = updateProperty(row, cameraRotEuler.z)
		elseif name == "field of view" then
			camera.fieldOfView = updateProperty(row, camera.fieldOfView)
		elseif name == "depth of field" then
			postProcessSettings.depthOfFieldFocalDistance = updateProperty(row, postProcessSettings.depthOfFieldFocalDistance)
		else
			-- load replay
			if findIndexInList(Replay.listAll(), name) > 0 then
				local replay
				local replayIndex = findReplayIndex(name)
				-- TODO: currently does not support the same replay being loaded more than once
				if replayIndex == -1 then
					replay = Replay.load(name)
				else
					replay = Replay.getByIndex(replayIndex)
				end
				replay:setPlaybackTimeSeconds(updateProperty(row, replay:getPlaybackTimeSeconds()))
			end
		end
	end
	if quaternionInterpolateRotation then
		local newRotation = updateRotationQuaternion(camera.rotation)
		if newRotation then
			camera.rotation = newRotation
		end
	end

	if not quaternionInterpolateRotation then
		camera.rotation = Quat.fromEuler(cameraRotEuler.x, cameraRotEuler.y, cameraRotEuler.z)
	end
	if animating or not editing then
		camera:followCamera(nil)
		editing = false
	else
		local freecam = getCameraById("anotheraxiom.freecam")
		camera:followCamera(freecam)
	end

	-- Visualize LUT
	if editing and visualizeLut then
		local allPoints = traverseDownAndCollectPoints(rows)
		if #allPoints > 0 then
			local animStart = allPoints[1].x
			local animEnd = allPoints[#allPoints].x
			local xSpline = getProperty("position.x").spline
			local ySpline = getProperty("position.y").spline
			local zSpline = getProperty("position.z").spline
			local lastPoint = Vec3.new(evalSpline(0, xSpline), evalSpline(0, ySpline), evalSpline(0, zSpline))
			for i = 2, visualSplineLOD do
				local t = i / visualSplineLOD * (animEnd - animStart) + animStart
				local vec = Vec3.new(evalSpline(t, xSpline), evalSpline(t, ySpline), evalSpline(t, zSpline))
				WorldDraw.drawLine(lastPoint, vec, 0.8, 0, 0, 10, 0)
				lastPoint = vec
			end
			for i, point in ipairs(allPoints) do
				local t = point.x
				local vec = Vec3.new(evalSpline(t, xSpline), evalSpline(t, ySpline), evalSpline(t, zSpline))
				WorldDraw.drawPoint(vec, 1, 0, 0, 10, 0)
			end
			-- point to represent camera
			WorldDraw.drawPoint(camera.position, 1, 1, 1, 20, 0)
		end
	end

	local rowsCopy = {}
	for i = 1, #rows do
		local rowCopy = {
			name = rows[i].name,
			interpolationMode = rows[i].interpolationMode,
			isGraphOpen = rows[i].isGraphOpen,
			spline = { properties = {}, lut = nil },
		}
		for j = 1, #rows[i].spline.properties do
			table.insert(rowCopy.spline.properties, Vec2.new(rows[i].spline.properties[j].x, rows[i].spline.properties[j].y))
		end
		table.insert(rowsCopy, rowCopy)
	end
end

function getRealValue(name: string): number
	if name == "position.x" then
		return camera.position.x
	elseif name == "position.y" then
		return camera.position.y
	elseif name == "position.z" then
		return camera.position.z
	elseif name == "roll" then
		return camera.rotation:euler().x
	elseif name == "pitch" then
		return camera.rotation:euler().y
	elseif name == "yaw" then
		return camera.rotation:euler().z
	elseif name == "field of view" then
		return camera.fieldOfView
	elseif name == "depth of field" then
		return postProcessSettings.depthOfFieldFocalDistance
	end
	return 0
end

function returnClosest(target: number, v1: number, v2: number)
	if math.abs(target - v1) <= math.abs(target - v2) then
		return v1
	else
		return v2
	end
end

function updateProperty(row: AnimationRow, currentValue: number): number
	if not row or not row.spline then
		return 0
	end
	local newValue = evalSpline(playbackTime, row.spline)
	if newValue ~= currentValue and not animating then
		row.spline.lut = updateSplineLut(row.spline)
	end
	return newValue
end

function updateRotationQuaternion(currentRotation: Quat)
	local newValue = evalRotationSquad(playbackTime)
	return newValue
end

function evalRotationSquad(playbackTime: number): Quat?
	local rotationDropdown = getProperty("rotation")
	local pitch = getProperty("pitch")
	local yaw = getProperty("yaw")
	local roll = getProperty("roll")

	if not rotationDropdown or not pitch or not yaw or not roll then
		return nil
	end

	local rotationKeyframes = traverseDownAndCollectPoints(rotationDropdown)
	-- evaluate rotation at playbackTime
	local quats = {}
	local pitchKeyframes = {}
	local yawKeyframes = {}
	local rollKeyframes = {}
	if pitch.spline and pitch.spline.properties then
		pitchKeyframes = getKeyframesFromGraph(pitch.spline.properties)
	end
	if yaw.spline and yaw.spline.properties then
		yawKeyframes = getKeyframesFromGraph(yaw.spline.properties)
	end
	if roll.spline and roll.spline.properties then
		rollKeyframes = getKeyframesFromGraph(roll.spline.properties)
	end

	local t = 0
	if Input.getKeyDown(Input.Key.Seven) then
		print("yawKeyframes")
		print(yawKeyframes)
	end

	for i, kf in ipairs(rotationKeyframes) do
		local pitchKf = pointAtX(pitchKeyframes, kf.x)
		local yawKf = pointAtX(yawKeyframes, kf.x)
		local rollKf = pointAtX(rollKeyframes, kf.x)
		local resultQuat = Quat.fromEuler(rollKeyframes[rollKf].y, pitchKeyframes[pitchKf].y, yawKeyframes[yawKf].y)
		quats[i] = resultQuat
		if playbackTime > kf.x then
			if i >= #rotationKeyframes then
				t = i - 1
			else
				t = (playbackTime - kf.x) / (rotationKeyframes[i + 1].x - kf.x) + i - 1
			end
		end
	end
	if Input.getKeyDown(Input.Key.Seven) then
		print("quats:")
		print(quats)
	end
	return interpQuatList(t, quats) -- todo optimize to only consider relevant sections of spline
end

function computeSquadTangents(prevQuat: Quat, currentQuat: Quat, nextQuat: Quat)
	local invCurrent = currentQuat:inverse()
	local log1 = quatLog(invCurrent * prevQuat)
	local log2 = quatLog(invCurrent * nextQuat)
	local frac = (log1 + log2) / -4
	return currentQuat * quatExp(frac)
end

function computeAllSquadTangents(quats: { Quat })
	local tangents = {}
	local n = #quats

	tangents[1] = quats[1]
	tangents[n] = quats[n]
	for i = 2, n - 1 do
		tangents[i] = computeSquadTangents(quats[i - 1], quats[i], quats[i + 1])
	end
	return tangents
end

function interpQuatList(t: number, quats: { Quat }): Quat?
	if not quats or #quats <= 0 then
		return nil
	end
	if #quats == 1 then
		return quats[1]
	end
	if t >= #quats - 1 then
		return quats[#quats]
	end
	if t <= 0 then
		return quats[1]
	end
	local tangents = computeAllSquadTangents(quats)
	local segmentIndex = math.ceil(t) + 1
	if t <= 0 then
		segmentIndex = 2
	end
	local alpha = t - math.floor(t)
	if #quats == 2 then
		return Quat.slerp(quats[1], quats[2], alpha)
	end
	local rot1 = quats[segmentIndex - 1]
	local rot2 = quats[segmentIndex]
	-- interpolate linearly
	local rotationRow = getProperty("rotation")
	if rotationRow and interpModes[rotationRow.interpolationMode] == "Linear" then
		return Quat.slerp(rot1, rot2, alpha)
	end
	local tangent1 = tangents[segmentIndex - 1]
	local tangent2 = tangents[segmentIndex]
	return squad(alpha, rot1, rot2, tangent1, tangent2)
end

function squad(t: number, q1: Quat, q2: Quat, tangent1: Quat, tangent2: Quat)
	if not q1 or not q2 or not tangent1 or not tangent2 then
		print("invalid args to squad")
		return
	end
	local slerp1 = Quat.slerp(q1, q2, t)
	local slerp2 = Quat.slerp(tangent1, tangent2, t)
	return Quat.slerp(slerp1, slerp2, 2 * t * (1 - t))
end

function quaternionAbs(q: Quat)
	if q.w >= 0 then
		return q
	else
		return Quat.new(-q.x, -q.y, -q.z, -q.w)
	end
end

function quatLog(q: Quat): Vec3
	local length = math.sqrt(q.x * q.x + q.y * q.y + q.z * q.z)
	if length < 0.0000001 then
		return Vec3.new(q.x, q.y, q.z)
	else
		local halfAngle = math.acos(math.clamp(q.w, -1, 1))
		return (Vec3.new(q.x, q.y, q.z) / length) * halfAngle
	end
end
function quatExp(v: Vec3): Quat
	local length = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
	if length < 0.0000001 then
		local result = Quat.new(v.x, v.y, v.z, 1)
		result:normalize()
		return result
	else
		local cos = math.cos(length)
		local sin = math.sin(length) / length
		return Quat.new(sin * v.x, sin * v.y, sin * v.z, cos)
	end
end
function quatToAngleAxis(q: Quat): Vec3
	local result = quatLog(q) * 2
	return result
end
function quatFromAngleAxis(v: Vec3): Quat
	return quatExp(v / 2)
end

function play()
	animating = true
	for i, row in ipairs(traverseLeaves(rows)) do
		if row.spline then
			row.spline.lut = updateSplineLut(row.spline)
		end
	end
end

function setInterpModeRecursive(root: AnimationRow, newMode: number)
	if root == nil then
		return
	end
	root.interpolationMode = newMode
	if root.children then
		for i, child in ipairs(root.children) do
			setInterpModeRecursive(child, newMode)
		end
	end
end

function removePointRecursive(root: AnimationRow, t: number)
	if root == nil then
		return
	end
	local pointAtT = keyframeAtTime(root.spline, t)
	if pointAtT ~= -1 then
		removePoint(root.spline, pointAtT)
	end
	if root.children then
		for i, child in ipairs(root.children) do
			removePointRecursive(child, t)
		end
	end
end

function addPointRecursive(root: AnimationRow, t: number)
	if root == nil then
		return
	end
	if root.name then
		writePoint(root.spline, t, getRealValue(root.name))
	else
		writePoint(root.spline, t, 0)
	end
	if root.children then
		for i, child in ipairs(root.children) do
			addPointRecursive(child, t)
		end
	end
end

function roundUp(x: number, increment: number): number
	return math.floor((x / increment) + 0.5) * increment
end

updateAllSplineLuts()
