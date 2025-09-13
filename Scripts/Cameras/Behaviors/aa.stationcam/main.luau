--!strict

-- This is a helper function to initialize the config with default values
local function initializeConfig(defaultConfig: {
	autoSwitch: boolean,
	autoSwitchDelay: number,
	cameraPositions: { CameraPositionPreset },
})
	for i, v in pairs(defaultConfig) do
		if config[i] == nil then
			config[i] = v
		end
	end
end

local editingMode = false
local lastSwitchTime = 0

type DistrictName = "Driftball" | "Scraprun" | "Club" | "Parkour" | "Space"

type CameraPositionPreset = {
	name: string,
	position: Vec3,
	rotation: Quat,
	fieldOfView: number,
	motionVector: Vec3?,
	district: DistrictName,
}

function main()
	initializeConfig({
		autoSwitch = true,
		autoSwitchDelay = 10,
		smoothing = 0,
		cameraPositions = {
			{
				name = "Main Entrance",
				position = Vec3.new(0, -5000, -27000),
				rotation = Quat.new(0, 0, 0.707107, 0.707107),
				fieldOfView = 70,
				district = "Driftball",
			},
			{
				name = "Arena Window",
				position = Vec3.new(3904.242484555357, 7281.041352496758, -29224.007999180325),
				rotation = Quat.new(-0.010468011182851143, 0.0034439552565942036, 0.948135781433171, 0.3176745187769652),
				fieldOfView = 65,
				district = "Driftball",
			},
			{
				name = "Parkour Entrance",
				position = Vec3.new(-18779.821352123487, 2354.431397355944, 15520.902592680606),
				rotation = Quat.new(0.27073732565886943, 0.8826377640097397, 0.23468215687617278, 0.30426331241692217),
				fieldOfView = 104.9999771118164,
				district = "Parkour",
			},
			{
				name = "Scraprun 1",
				position = Vec3.new(-32827.210341658, 10166.027432993775, -749.7070513018222),
				rotation = Quat.new(0.5425660688064267, 0.3678205240834544, 0.6995771719887454, 0.28446775471948077),
				fieldOfView = 84.99996948242188,
				district = "Scraprun",
			},
			{
				name = "Scraprun 2",
				position = Vec3.new(-33019.28994862582, 16042.04982294495, -702.3429049670468),
				rotation = Quat.new(0.5815895765705128, 0.31008354357394585, 0.7078808828257546, 0.253981133470553),
				fieldOfView = 99.99996948242188,
				district = "Scraprun",
			},
			{
				name = "Scraprun 3",
				position = Vec3.new(-33505.1135524764, 21863.272261138653, -652.1989859953721),
				rotation = Quat.new(-0.7188081645073158, 0.24891751148577373, -0.566879438544549, 0.31623187263267866),
				fieldOfView = 99.99996948242188,
				district = "Scraprun",
			},
			{
				name = "Scraprun 4",
				position = Vec3.new(-33219.17087983194, 28011.853931935886, -751.1311831612352),
				rotation = Quat.new(-0.5626785517393709, 0.3713916953686879, -0.6690158614486588, 0.31285593034776427),
				fieldOfView = 99.9999771118164,
				district = "Scraprun",
			},
			{
				name = "Scraprun 5",
				position = Vec3.new(-29977.33906539682, 26931.70186354928, -1790.752062638552),
				rotation = Quat.new(-0.6722298215893858, 0.0017076067299041271, -0.7403373977606847, 0.002165299539759382),
				fieldOfView = 95.0000228881836,
				district = "Scraprun",
			},
			{
				name = "Scraprun 6",
				position = Vec3.new(-30028.21905982368, 23544.991402561813, -1860.834811333557),
				rotation = Quat.new(-0.5699993324677781, 0.40033577989933866, -0.6131197638344964, 0.372714608667553),
				fieldOfView = 60.0000114440918,
				district = "Scraprun",
			},
			{
				name = "Scraprun 7",
				position = Vec3.new(-30234.31269526416, 10453.63750776281, -1442.081411398038),
				rotation = Quat.new(0.5891568828275554, 0.3960885520682953, 0.5775712976830794, 0.40301293084719214),
				fieldOfView = 74.9999771118164,
				district = "Scraprun",
			},
			{
				name = "Scraprun Exterior",
				position = Vec3.new(-27139.29411452756, -13765.531033074794, 11.519577802319684),
				rotation = Quat.new(0.4897890932997666, 0.5107381276989169, 0.5087050008984467, 0.49037988443665675),
				fieldOfView = 29.99999237060547,
				district = "Scraprun",
			},
			{
				name = "Parkour Entrance Low",
				position = Vec3.new(-23961.643447219714, 1755.8390815718328, 15239.828756868957),
				rotation = Quat.new(0.40715250930926206, 0.7462475561385694, 0.2069334192267973, 0.4842726289266106),
				fieldOfView = 74.99996948242188,
				district = "Parkour",
			},
			{
				name = "Parkour Doorway",
				position = Vec3.new(-26469.27814302699, 11945.240502028186, 11672.620280706487),
				rotation = Quat.new(-0.7156854746414069, 0.5003576730639188, -0.3560818064282032, 0.33262929444682443),
				fieldOfView = 54.9999885559082,
				district = "Parkour",
			},
			{
				name = "Parkour Crystal",
				position = Vec3.new(-23550.919744700823, 30538.886363559563, 15845.706046133198),
				rotation = Quat.new(-0.5323977424249202, 0.6187007910672071, -0.1775324138119529, 0.5497674208606421),
				fieldOfView = 105.0000228881836,
				district = "Parkour",
			},
			{
				name = "Parkour Gym",
				position = Vec3.new(-29980.69205313505, 15689.949481998616, 10880.441248767818),
				rotation = Quat.new(-0.6883091885402726, 0.4590314121821553, -0.12110423729874967, 0.5485019483186689),
				fieldOfView = 120.0000228881836,
				district = "Parkour",
			},
			{
				name = "Parkour Hole",
				position = Vec3.new(-26737.28950451447, 5217.74928190132, 15428.220988009209),
				rotation = Quat.new(-0.7104407025952255, 0.17594577627719168, 0.18956586184461016, 0.6545088814747506),
				fieldOfView = 114.99996948242188,
				district = "Parkour",
			},
			{
				name = "Club 1",
				position = Vec3.new(24493.126014018857, 34371.916717970096, 10127.953898738511),
				rotation = Quat.new(0.57397761285677, -0.6456105645301848, -0.3108909566330361, 0.3963376237377112),
				fieldOfView = 39.9999885559082,
				district = "Club",
			},
			{
				name = "Club 2",
				position = Vec3.new(21098.945930986345, 22412.817151798798, 20691.18156778582),
				rotation = Quat.new(-0.7416250545432844, -0.294801462882519, 0.5913759543010351, 0.11558052011709063),
				fieldOfView = 100.0000228881836,
				district = "Club",
			},
			{
				name = "Club 3",
				position = Vec3.new(26078.339086405103, 1985.9191176609995, 8256.214871878003),
				rotation = Quat.new(-0.4809908703911413, -0.6884146943462541, 0.21545529379278602, 0.49830914860675674),
				fieldOfView = 95.00003051757812,
				district = "Club",
			},
			{
				name = "Fuel Cells",
				position = Vec3.new(7287.928710201454, -95533.14646085014, -828.6661971978751),
				rotation = Quat.new(-0.02671546972957156, 0.019655936673257955, 0.7756037502508115, 0.6303481184452782),
				fieldOfView = 79.99998474121094,
				district = "Space",
			},
			{
				name = "Overview",
				position = Vec3.new(121102.00530449886, 177537.76853542659, 25179.89896620115),
				rotation = Quat.new(0.06835280817379522, 0.029576379852266965, -0.9085699021522595, 0.4110399789225176),
				fieldOfView = 65.00003051757812,
				district = "Space",
			},
			{
				name = "Prime Overview",
				position = Vec3.new(-6.565116559615317, 29539.54062206416, -26453.50068726581),
				rotation = Quat.new(0.1867538200981489, 0.1857059094040467, -0.6838126011519494, 0.6804679657389977),
				fieldOfView = 125.0000228881836,
				district = "Driftball",
			},
			{
				name = "Driftplex Entrance",
				position = Vec3.new(6251.780197687672, 18410.752687025084, -28374.25842418776),
				rotation = Quat.new(0.001565008797139448, -0.15489342058230665, 0.010609863020328004, 0.9878729725093544),
				fieldOfView = 114.9999771118164,
				district = "Driftball",
			},
			{
				name = "Crane",
				position = Vec3.new(5873.181090344515, 24085.708266127513, -27073.02222661239),
				rotation = Quat.new(-0.02124234968477417, 0.010029970792308975, 0.9026349594822676, 0.42976539202944286),
				fieldOfView = 114.99996948242188,
				district = "Driftball",
			},
			{
				name = "Window to Entrance",
				position = Vec3.new(6731.400221382023, 22984.461357911372, -27551.63590111842),
				rotation = Quat.new(0.007977315037192876, 0.0028831899178311388, -0.8259274034660367, 0.5637126695973275),
				fieldOfView = 59.9999885559082,
				district = "Driftball",
			},
			{
				name = "Fieldhouse",
				position = Vec3.new(1.5373476239309454, 30671.48267534886, -29021.291177198225),
				rotation = Quat.new(0.07651963920234797, 0.07655734738009964, -0.7021280081401982, 0.70377551645645),
				fieldOfView = 99.9999771118164,
				district = "Driftball",
			},
			{
				name = "Prime Overview 2",
				position = Vec3.new(-3524.230989769899, 29822.1402461112, -26630.122175183915),
				rotation = Quat.new(0.04964148969575636, 0.13327614322234987, -0.3450678318716586, 0.9277399331471907),
				fieldOfView = 79.99996948242188,
				district = "Driftball",
			},
			{
				name = "Driftball Entrance",
				position = Vec3.new(-1691.469109205072, 9770.56288042978, -27722.82155380309),
				rotation = Quat.new(0.016634520741928647, 0.021325503841351248, -0.6176455112433725, 0.7859914363697051),
				fieldOfView = 35.00001525878906,
				district = "Driftball",
			},
			{
				name = "Prime Exterior",
				position = Vec3.new(6492.786156671163, 5927.924811992213, -25451.774214106976),
				rotation = Quat.new(-0.03363909197143147, 0.023987206151338755, 0.8121736502084383, 0.5819510179899099),
				fieldOfView = 45.0000114440918,
				district = "Driftball",
			},
			{
				name = "Prime Center",
				position = Vec3.new(19.429420035667768, 29479.04551610363, -27802.899579601115),
				rotation = Quat.new(0.10977867987775108, 0.1124240901746605, -0.6904103701784099, 0.7061465755371252),
				fieldOfView = 125.0000228881836,
				district = "Driftball",
			},
			{
				name = "Prime Right Goal",
				position = Vec3.new(1370.1160193882943, 28686.89851980872, -27065.525187225634),
				rotation = Quat.new(0.06917484771743328, 0.20773874653722096, -0.30852542907261216, 0.9256735457200747),
				fieldOfView = 99.9999771118164,
				district = "Driftball",
			},
			{
				name = "Prime Right Goal Far",
				position = Vec3.new(-697.2120651284234, 29357.783458032325, -27727.794610542453),
				rotation = Quat.new(0.0317862903849158, 0.0875141798857166, -0.3405505850284671, 0.9356047237478362),
				fieldOfView = 99.9999771118164,
				district = "Driftball",
			},
			{
				name = "Prime Left Goal Far",
				position = Vec3.new(1219.2492594569749, 29334.27100740288, -27623.738340237393),
				rotation = Quat.new(0.08613476865470061, 0.03295959529843393, -0.9302337120590182, 0.3551896784191002),
				fieldOfView = 99.9999771118164,
				district = "Driftball",
			},
			{
				name = "Prime Left Goal",
				position = Vec3.new(-894.9866672339225, 28740.259323822338, -26987.667456623858),
				rotation = Quat.new(0.22066615791031496, 0.10286181005880089, -0.8792243050264458, 0.40950032507348577),
				fieldOfView = 90.00003051757812,
				district = "Driftball",
			},
		},
	})

	setCameraPosition(config.cameraPositions[1])
end

function onGui()
	if editingMode then
		if Gui.button("Exit Edit Mode") then
			editingMode = false
			camera:followCamera(nil)
		end
		Gui.newLine()

		if Gui.button("Log Position") then
			print(
				'{name= "New Position", position= Vec3.new('
					.. tostring(camera.position.x)
					.. ", "
					.. tostring(camera.position.y)
					.. ", "
					.. tostring(camera.position.z)
					.. "), rotation= Quat.new("
					.. tostring(camera.rotation.x)
					.. ", "
					.. tostring(camera.rotation.y)
					.. ", "
					.. tostring(camera.rotation.z)
					.. ", "
					.. tostring(camera.rotation.w)
					.. "), fieldOfView= "
					.. tostring(camera.fieldOfView)
					.. "}"
			)
		end
	else
		config.autoSwitch = Gui.checkbox("Cycle cameras", config.autoSwitch)
		if config.autoSwitch then
			config.autoSwitchDelay = Gui.dragFloat("Auto Switch Delay (seconds)", config.autoSwitchDelay, 0.5, 0.1, 6000)
			Gui.beginDisabled()
			Gui.sliderFloat("", os.clock() - lastSwitchTime, 0, config.autoSwitchDelay)
			Gui.endDisabled()
		end
		config.smoothing = Gui.sliderFloat("Camera Smoothing", config.smoothing, 0, 1)

		if Gui.button("Save Config") then
			saveConfig()
		end

		local districts: { DistrictName } = {
			"Club",
			"Driftball",
			"Parkour",
			"Scraprun",
			"Space",
		}
		for districtIdx, district in districts do
			Gui.newLine()
			Gui.text(district)
			local buttonCount = 0
			for i, v in ipairs(config.cameraPositions) do
				if v.district == district then
					Gui.pushId(tostring(i))
					buttonCount += 1
					if buttonCount % 4 ~= 1 then
						Gui.sameLine()
					end

					if Gui.button(v.name) then
						setCameraPosition(v)
					end
					Gui.popId()
				end
			end
		end

		Gui.newLine()
		Gui.newLine()

		if Gui.button("Edit Mode") then
			editingMode = true
			camera:followCamera(getCameraById("anotheraxiom.freecam"))
		end
	end
end

function tick(dt: number)
	if config.autoSwitch then
		local currentTime = os.clock()
		if currentTime - lastSwitchTime >= config.autoSwitchDelay then
			lastSwitchTime = currentTime
			local nextPositionIndex = math.random(1, #config.cameraPositions - 1)
			setCameraPosition(config.cameraPositions[nextPositionIndex])
		end
	end

	camera.positionSmoothing = config.smoothing
	camera.rotationSmoothing = config.smoothing
	camera.fieldOfViewSmoothing = config.smoothing
end

function setCameraPosition(presetName: CameraPositionPreset?)
	editingMode = false
	camera:followCamera(nil)
	if presetName == nil then
		error("Invalid camera position preset provided.")
		return
	end
	camera.position = presetName.position
	camera.rotation = presetName.rotation
	camera.fieldOfView = presetName.fieldOfView
end
