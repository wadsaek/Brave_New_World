local myConBotItem
local myConBot
local myLogiBotItem
local myLogiBot


myConBotItem = util.table.deepcopy(data.raw["item"]["construction-robot"])
myConBotItem.name = "starter-constuction-robot"
myConBotItem.place_result = "starter-construction-robot"
data:extend({myConBotItem})

myLogiBotItem = util.table.deepcopy(data.raw["item"]["logistic-robot"])
myLogiBotItem.name = "starter-logistic-robot"
myLogiBotItem.place_result = "starter-logistic-robot"
data:extend({myLogiBotItem})

myConBot = util.table.deepcopy(data.raw["construction-robot"]["construction-robot"])
myConBot.name = "starter-construction-robot"
myConBot.speed = 0.8
myConBot.minable = {mining_time = 10, result = "starter-construction-robot"}
data:extend({myConBot})

myLogiBot = util.table.deepcopy(data.raw["logistic-robot"]["logistic-robot"])
myLogiBot.name = "starter-logistic-robot"
myLogiBot.speed = 0.6
myLogiBot.minable = {mining_time = 10, result = "starter-logistic-robot"}
data:extend({myLogiBot})
