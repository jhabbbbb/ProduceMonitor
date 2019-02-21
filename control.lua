if not global.panelDisplayed then global.panelDisplayed = false end

-- data.raw["assembling-machine"]["assembling-machine-1"].crafting_speed = 0.5

local function printResult(dict)
	for key, value in pairs(dict) do
		game.print(string.format("Name: %s required: %0.3f/s production: %0.3f/s", key, value['required'], value['production']))
	end
end

local function getRecipeFromOutput(entity)
	for item, _ in pairs(entity.get_output_inventory().get_contents()) do --can get several *oil*?
		return game.recipe_prototypes[item]
	end
	return nil
end

local function getRecipeFromFurnace(entity)
	if entity.type == "furnace" then
		return entity.previous_recipe
	else
		return nil
	end
end

local function getRecipe(entity)
	return entity.get_recipe() or getRecipeFromOutput(entity) or getRecipeFromFurnace(entity)
end

-- Model
local function calculate()

	local result = {} 
	--[[
		result is a dictionary with a structure below
		{
			iron: {
				production: 0, 
				required: 0
			},
			iron-plate: {
				production: 0, 
				required: 0
			}
		}
		new structure
		{
			iron: { -- mining-drill
				name: iron
				amount: 1
				ingredients: {
					{
						name: coal
						amount: 1
					}
				}
				energy: 2
				factoryIndex: 10
				production: 0
				required: 0 
			},
			iron-plate: { -- furnace
				name: iron-plate
				amount: 1
				ingredients: {
					{
						name: iron
						amount: 1
					}
					{
						name: coal
						amount: 1
					}
				}
				energy: 3.5
				factoryIndex: 100
				production: 0
				required: 0
			}
			belt: { -- assembling-machine
				name: belt
				amount: 2
				ingredients: {
					{
						name: iron-plate
						amount: 1
					}
					{
						name: gear
						amount: 1
					}
				}
				energy: 0.5
				factoryIndex: 2
				production: 0
				required: 0
			}
			technology: { -- lab
				name: nil
				amount: 0
				ingredients: {
					{
						name: science-pack-1
						amount: 1
					}
					{
						name: science-pack-2
						amount: 1
					}
				}
				energy: 10
				factoryIndex: 2
				production: 0
				required: 0
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
		if recipe then
			local productList = recipe.products
			for _, product in pairs(productList) do
				-- game.print('type: '..product.type..' name: '..product.name..' amount: '..product.amount)
				if not result[product.name] then 
					result[product.name] = {name = product.name, amount = product.amount, ingredients = {}, energy = recipe.energy, factoryIndex = 0, production = 0, required = 0}
					for _, ingredient in pairs(ingredientList) do
						table.insert(result[product.name]['ingredients'], {name = ingredient.name, amount = ingredient.amount})
					end
				end
				result[product.name]['factoryIndex'] = result[product.name]['factoryIndex'] + 1*machine.prototype.crafting_speed
			end
		end
	end
	
	-- count recipes from furnace, consume some coals and ores to get productions in general 
	for _, furnace in pairs(furnaceList) do
		local fuel = furnace.get_fuel_inventory().get_contents()
		local recipe = getRecipe(furnace)
		local speed = furnace.prototype.crafting_speed
		if recipe then
			local productList = recipe.products
			for _, product in pairs(productList) do
				if not result[product.name] then 
					result[product.name] = {name = product.name, amount = product.amount, ingredients = {}, energy = recipe.energy, factoryIndex = 0, production = 0, required = 0}
					for _, ingredient in pairs(ingredientList) do
						table.insert(result[product.name]['ingredients'], {name = ingredient.name, amount = ingredient.amount})
					end
				end
				result[product.name]['factoryIndex'] = result[product.name]['factoryIndex'] + 1*machine.prototype.crafting_speed
			end
		end
	end
	
	-- calculate the ingredient and product from mining-drill
	-- for _, drill in pairs(miningDrillList) do
		-- local product = drill.mining_target
		-- if product then
			-- -- productivity calculating formula is (Power-Hardness)/Time*Speed
			-- local miningSpeed = drill.prototype.mining_speed
			-- local miningPower = drill.prototype.mining_power
			-- local miningHardness = product.prototype.mineable_properties ['hardness']
			-- local miningTime = product.prototype.mineable_properties ['mining_time']
			-- local productivity = (miningPower - miningHardness) / miningTime * miningSpeed
			-- -- calculate products
			-- if not result[product.name] then 
				-- result[product.name] = {production = 0, required = 0}
			-- end
			-- result[product.name]['production'] = result[product.name]['production'] + productivity
		-- end
	-- end
	
	-- calculate the ingredient for lab
	-- for _, lab in pairs(labList) do
		-- local research = player.force.current_research
		-- if research then
			-- local ingredientList = research.research_unit_ingredients
			-- local energy = research.research_unit_energy / 60 -- have no idea, but it is 60 times of seconds 
			-- for _, ingredient in pairs(ingredientList) do
				-- -- game.print('type: '..ingredient.type..' name: '..ingredient.name..' amount: '..ingredient.amount)
				-- if not result[ingredient.name] then 
					-- result[ingredient.name] = {production = 0, required = 0}
				-- end
				-- result[ingredient.name]['required'] = result[ingredient.name]['required'] + ingredient.amount/energy
			-- end
		-- end
	-- end
	
	return result
end

-- local function testFunction()
	-- local a = data.raw["boiler"]["boiler"]
	-- for key, value in pairs(value) do
		-- game.print(key)
	-- end
-- end

-- view
local function initUI()
	for _, player in pairs(game.players) do
		player.gui.left.add{type='button', name='openPanelButton', caption='P.M.', mouse_button_filter={'left'}}
	end
end

local function updateCalculate()
	
end


script.on_init(
	function()
		initUI()
	end
)

-- controller
script.on_event(defines.events.on_gui_click,
	function(event)
		player = game.players[event.player_index]
		if event.element.name == 'openPanelButton' then
			if not global.produceMonitorFrame then -- run when enter game the first time
				global.produceMonitorFrame = player.gui.left.add{type='frame', name='produceMonitorFrame', caption='Produce Monitor', direction='vertical'}
			end
			if global.panelDisplayed == true then
				global.produceMonitorFrame.clear()
				global.produceMonitorFrame.style.visible = false
				global.panelDisplayed = false
			else
				local tempResult = calculate()
				local result = {}
				for key, value in pairs(tempResult) do
					table.insert(result, {name=key, data=value, ratio=value['production']/value['required']})
				end
				table.sort(result, function(x, y) return x.ratio < y.ratio end)
				for _, item in pairs(result) do
					-- each flow describe one item's data
					local flow = global.produceMonitorFrame.add{type='flow', name=item['name']..'_flow', direction='horizontal'}
					flow.style.vertical_align = 'center'
					-- icon
					local spriteButton = flow.add{type='sprite-button', name=item['name']..'_image', sprite='item/'..item['name']}
					-- 1 progressbar if production <= required; 2 progressbar if production > required
					local progressbarFlow = flow.add{type='flow', name=item['name']..'_progressbarflow', direction='vertical'}
					local progressbarValue = item.data['production']/item.data['required']
					local progressbarValue1 = 0
					local progressbarValue2 = 0
					if progressbarValue <= 1 then 
						progressbarValue1 = progressbarValue 
						local progressbar1 = progressbarFlow.add{type='progressbar', name=item['name']..'_progressbar1', value=progressbarValue1}
						progressbar1.style.maximal_width = 100
						progressbar1.style.color = {r=1-progressbarValue1, g=progressbarValue1, b=0, a=1}
					else
						progressbarValue1 = 1 
						local progressbar1 = progressbarFlow.add{type='progressbar', name=item['name']..'_progressbar1', value=progressbarValue1}
						progressbar1.style.maximal_width = 100
						progressbar1.style.color = {r=0, g=progressbarValue1, b=0, a=1}
						progressbarValue2 = (progressbarValue - 1) / 5
						if progressbarValue2 > 1 then progressbarValue2 = 1 end
						local progressbar2 = progressbarFlow.add{type='progressbar', name=item['name']..'_progressbar2', value=progressbarValue2}
						progressbar2.style.maximal_width = 100
						progressbar2.style.color = {r=0, g=1-progressbarValue2, b=progressbarValue2, a=1}
					end
					-- local label = flow.add{type='label', name=item['name']..'_label', caption=string.format("required: %0.3f/s production: %0.3f/s", value['required'], value['production'])}
					local labelFlow = flow.add{type='flow', name=item['name']..'_labelFlow', direction='vertical'}
					labelFlow.style.vertical_align = 'center'
					labelFlow.style.left_padding = 15
					local productionLabel = labelFlow.add{type='label', name=item['name']..'_productionLabel', caption=string.format("production: %0.3f/m", item.data['production']*60)}
					local requiredLabel = labelFlow.add{type='label', name=item['name']..'_requiredLabel', caption=string.format("required: %0.3f/m", item.data['required']*60)}
					requiredLabel.style.font = 'produceMonitorLabelFont'
					productionLabel.style.font = 'produceMonitorLabelFont'
				end
				global.produceMonitorFrame.style.visible = true
				global.panelDisplayed = true
			end
		end
	end
)

script.on_event(defines.events.on_built_entity,
	function(event)
		game.print(event.created_entity.prototype.name)
	end
)