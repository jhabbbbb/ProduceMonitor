if not PM then PM = {} end

local function printResult(dict)
	for key, value in pairs(dict) do
		game.print(string.format("Name: %s target: %0.3f/s production: %0.3f/s", key, value['target'], value['production']))
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

function getRecipe(entity)
	return entity.get_recipe() or getRecipeFromOutput(entity) or getRecipeFromFurnace(entity)
end

function printRecipeList(recipeList)
	for _, recipe in pairs(recipeList) do
		local ingredients = ""
		for _, item in pairs(recipe.ingredients) do
			ingredients = ingredients..item.name..' '..item.amount..' '
		end
		game.print(recipe.name.." <- {"..ingredients.."}".." energy: "..recipe.energy.." factoryIndex: "..recipe.factoryIndex.." production: "..recipe.production.." target: "..recipe.target)
	end
end