require("lib/tools")

-- Model
local function initModel()
	techMode = true
	if not playerIndex then playerIndex = -1 end
end

local function convertRecipe(recipe, speed)
	local productList = recipe.products
	local ingredientList = recipe.ingredients
	for _, product in pairs(productList) do
		if not recipeList[product.name] then 
			recipeList[product.name] = {name = product.name, amount = product.amount, ingredients = {}, energy = recipe.energy, factoryIndex = 0, production = 0, target = 0}
			for _, ingredient in pairs(ingredientList) do
				table.insert(recipeList[product.name]['ingredients'], {name = ingredient.name, amount = ingredient.amount})
			end
		end
		recipeList[product.name]['factoryIndex'] = recipeList[product.name]['factoryIndex'] + speed * 1
	end
end

local function buildProduceTree()
	produceTree = {root = {ingredients = {}, productions = {}}}
	for key, value in pairs(recipeList) do
		if not produceTree[key] then produceTree[key] = {ingredients = {}, productions = {}} end
		for _, ingredient in pairs(value.ingredients) do
			table.insert(produceTree[key].ingredients, ingredient.name)
			table.insert(produceTree[ingredient.name].productions, key)
		end
	end
	
end

local function calculateProductionAndtarget()
	for _, data in pairs(recipeList) do
		data.production = data.amount / data.energy * data.factoryIndex
		for _, ingredient in pairs(data.ingredients) do
			recipeList[ingredient.name].target = recipeList[ingredient.name].target + ingredient.amount / data.energy * data.factoryIndex
		end
	end
end

local function sortRecipeList()
	local result = {}
	for key, value in pairs(recipeList) do
		if value.name ~= 'tech' then
			table.insert(result, {name = key, production = value.production, target = value.target, ratio = value.production / value.target})
		end
	end
	table.sort(result, function(x, y) return x.ratio < y.ratio end)
	return result
end

local function calculateRecipes()

	recipeList = {} 
	--[[
		recipeList is a dictionary with a structure below:
		{
			iron: { -- mining-drill
				name: iron,
				amount: 1,
				ingredients: {},
				energy: 2,
				factoryIndex: 10,
				production: 0,
				target: 0 
			},
			iron-plate: { -- furnace
				name: iron-plate,
				amount: 1,
				ingredients: {
					{
						name: iron,
						amount: 1
					},
					{
						name: coal,
						amount: 1
					}
				},
				energy: 3.5,
				factoryIndex: 100,
				production: 0,
				target: 0
			},
			belt: { -- assembling-machine
				name: belt,
				amount: 2,
				ingredients: {
					{
						name: iron-plate,
						amount: 1
					},
					{
						name: gear,
						amount: 1
					}
				},
				energy: 0.5,
				factoryIndex: 2,
				production: 0,
				target: 0
			},
			technology: { -- lab
				name: nil,
				amount: 0,
				ingredients: {
					{
						name: science-pack-1,
						amount: 1
					},
					{
						name: science-pack-2,
						amount: 1
					}
				},
				energy: 10,
				factoryIndex: 2,
				production: 0,
				target: 0
			}
		}
	]]--
	
	-- find all entities that produceing things, there are five category
	local assemblingMachineList = game.surfaces['nauvis'].find_entities_filtered{type = 'assembling-machine'}
	local furnaceList = game.surfaces['nauvis'].find_entities_filtered{type = 'furnace'}
	local labList = game.surfaces['nauvis'].find_entities_filtered{type = 'lab'}
	local miningDrillList = game.surfaces['nauvis'].find_entities_filtered{type = 'mining-drill'}
	local rocketSiloList = game.surfaces['nauvis'].find_entities_filtered{type = 'rocket-silo'}
	
	-- count recipes from assembling-machine
	for _, machine in pairs(assemblingMachineList) do
		local recipe = getRecipe(machine)
		local speed = machine.prototype.crafting_speed
		if recipe then convertRecipe(recipe, speed) end
	end
	
	-- count recipes from furnace, consume some coals and ores to get productions in general 
	for _, furnace in pairs(furnaceList) do
		-- local fuel = furnace.get_fuel_inventory().get_contents()
		local recipe = getRecipe(furnace)
		local speed = furnace.prototype.crafting_speed
		if recipe then convertRecipe(recipe, speed) end
	end
	
	-- calculate the ingredient and product from mining-drill
	for _, drill in pairs(miningDrillList) do
		local product = drill.mining_target
		if product then
			-- productivity calculating formula is (Power-Hardness)/Time*Speed
			local miningSpeed = drill.prototype.mining_speed
			local miningPower = drill.prototype.mining_power
			local miningHardness = product.prototype.mineable_properties['hardness']
			local miningTime = product.prototype.mineable_properties['mining_time']
			-- calculate products
			if not recipeList[product.name] then 
				recipeList[product.name] = {name = product.name, amount = 1, ingredients = {}, energy = miningTime, factoryIndex = 0, production = 0, target = 0}
			end
			if drill.name == 'pumpjack' then
				local oilAmount =  product.amount / 30000
				recipeList[product.name]['factoryIndex'] = recipeList[product.name]['factoryIndex'] + (miningPower - miningHardness) * miningSpeed * oilAmount
			else
				recipeList[product.name]['factoryIndex'] = recipeList[product.name]['factoryIndex'] + (miningPower - miningHardness) * miningSpeed
			end
		end
	end
	
	for _, lab in pairs(labList) do
		local tech = game.players[playerIndex].force.current_research
		if not recipeList['tech'] then
			recipeList['tech'] = {name = 'tech', amount = 1, ingredients = {}, energy = tech.research_unit_energy, factoryIndex = 0, production = 0, target = 0}
			for _, ingredient in pairs(tech.research_unit_ingredients) do
				table.insert(recipeList['tech']['ingredients'], {name = ingredient.name, amount = ingredient.amount * 60}) -- don't kown why, but you need to * 60 to get the right data
			end
		end
		recipeList['tech'].factoryIndex = recipeList['tech'].factoryIndex + 1 -- research time in fact
	end
end

-- view
local function initUI()
	for _, player in pairs(game.players) do
		player.gui.left.add{type = 'button', name = 'panelButton', caption = 'P.M.', mouse_button_filter = {'left'}}
		global.produceMonitorFrame = player.gui.left.add{type='frame', name='produceMonitorFrame', caption='Produce Monitor'}
		global.produceMonitorFrame.style.maximal_height = 500
		global.produceMonitorFrame.style.visible = false
		global.panelDisplayed = false
	end
end

local function updateUI()
	if global.panelDisplayed == true then
		global.produceMonitorFrame.clear()
		global.produceMonitorFrame.style.visible = false
		global.panelDisplayed = false
	else
		local pane = global.produceMonitorFrame.add{type = 'scroll-pane', name = 'mainScrollPane', vertical_scroll_policy = 'always'}
		result = sortRecipeList()
		for _, item in pairs(result) do
			-- each flow describe one item's data
			local flow = pane.add{type = 'flow', name = item['name']..'_flow', direction = 'horizontal'}
			flow.style.vertical_align = 'center'
			-- identify the type of this item, bad implementation
			local sprite = ''
			if game.fluid_prototypes[item.name] then 
				sprite = 'fluid/'..item.name
			else
				sprite = 'item/'..item.name
			end
			-- icon
			local spriteButton = flow.add{type = 'sprite-button', name = item['name']..'_image', sprite = sprite}
			-- spriteButton.style.color = {r = 0, g = 0, b = 0, a = 1}
			-- 1 progressbar if production <= target; 2 progressbar if production > target
			local progressbarFlow = flow.add{type = 'flow', name = item['name']..'_progressbarflow', direction = 'vertical'}
			local progressbarValue = item.production / item.target
			local progressbarValue1 = 0
			local progressbarValue2 = 0
			if progressbarValue <= 1 then 
				progressbarValue1 = progressbarValue 
				local progressbar1 = progressbarFlow.add{type = 'progressbar', name = item['name']..'_progressbar1', value = progressbarValue1}
				progressbar1.style.maximal_width = 100
				progressbar1.style.color = {r = 1-progressbarValue1, g = progressbarValue1, b = 0, a = 1}
			else
				progressbarValue1 = 1 
				local progressbar1 = progressbarFlow.add{type = 'progressbar', name = item['name']..'_progressbar1', value = progressbarValue1}
				progressbar1.style.maximal_width = 100
				progressbar1.style.color = {r = 0, g = progressbarValue1, b = 0, a = 1}
				progressbarValue2 = (progressbarValue - 1) / 5
				if progressbarValue2 > 1 then progressbarValue2 = 1 end
				local progressbar2 = progressbarFlow.add{type = 'progressbar', name = item['name']..'_progressbar2', value = progressbarValue2}
				progressbar2.style.maximal_width = 100
				progressbar2.style.color = {r = 0, g = 1-progressbarValue2, b = progressbarValue2, a=1}
			end
			-- local label = flow.add{type = 'label', name = item['name']..'_label', caption = string.format("target: %0.3f/s production: %0.3f/s", item.target, item.production)}
			local labelFlow = flow.add{type = 'flow', name = item['name']..'_labelFlow', direction = 'vertical'}
			labelFlow.style.vertical_align = 'center'
			labelFlow.style.left_padding = 15
			local productionLabel = labelFlow.add{type = 'label', name = item['name']..'_productionLabel', caption = string.format("production: %0.3f/m", item.production*60)}
			local targetLabel = labelFlow.add{type = 'label', name = item['name']..'_targetLabel', caption = string.format("target: %0.3f/m", item.target*60)}
			targetLabel.style.font = 'produceMonitorLabelFont'
			productionLabel.style.font = 'produceMonitorLabelFont'
		end
		global.produceMonitorFrame.style.visible = true
		global.panelDisplayed = true
	end
end


script.on_init(
	function()
		initUI()
		initModel()
	end
)

-- controller
script.on_event(defines.events.on_gui_click,
	function(event)
		player = game.players[event.player_index]
		if event.element.name == 'panelButton' then
			if global.panelDisplayed == false then
				playerIndex = event.player_index
				calculateRecipes()
				calculateProductionAndtarget()
				-- buildProduceTree()
				-- printRecipeList(recipeList)
			end
			updateUI()
		end
	end
)

script.on_event(defines.events.on_built_entity,
	function(event)
		game.print(event.created_entity.prototype.type..' '..event.created_entity.prototype.name)
	end
)