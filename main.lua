-- run is not needed. just replaces love.run to cap game to 60 fps
require "run"
local rmap = require "retromap"
-- res also not needed. it's a screen resolution handler
local res = require "res"

local show_merged = false

local world = rmap.new_map({
	cell_size = 48,
	tilemap = 	{
	        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
	        {0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0},
	        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
	        {0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
	        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
	        {0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0},
	        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
	        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
	        {0,0,0,0,0,0,0,8,8,8,0,0,0,2,2,2,0,0,0,0,0,0,0,0,0},
	        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
	        {1,1,2,2,2,0,0,0,4,5,0,0,0,0,0,0,0,0,0,3,3,3,1,1,1},
	        {1,1,1,1,1,0,0,2,0,0,0,4,5,6,7,0,0,0,0,1,1,1,1,1,1},
	        {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
	}
})

local player = world:create_ent(64, 64, 12, 16)
player.filter = function(player, item, other)
	if other.is_coin then return "cross"
	else return "slide" end
end

local coin = world:create_ent(150, 64, 8, 8)
coin.is_coin = true
coin.filter = function(coin, item, other)
	return false
end

function love.update(dt)
    player.vx = 0
    if love.keyboard.isDown("left") then
        player.vx = -player.speed
    end
    if love.keyboard.isDown("right") then
        player.vx = player.speed
    end

    if (love.keyboard.isDown("z")) and player.grounded then
        player.vy = -player.jump_force
    end
    
    -- update all entities
    world:update_all(dt)

    -- or you could do just one at a time
    --world:apply_physics(player, dt)

    -- check player collisions
    for _, col in ipairs(player.collisions) do
    	-- touched a coin
    	if col.other.is_coin then
    		world:remove_ent(col.other)
    		coin = nil
    	end
    end
end

function love.draw()
	res.set(320, 200)
	love.graphics.setColor(1, 1, 1)
   
   	-- show the "real" tile layout
    --world:draw_map()
    
    if show_merged then
    	-- draw just the merged collisions
    	world:draw_merged_collisions()
    else
    	-- draw map with merged collisions
    	world:draw_debug()
    end

    love.graphics.setColor(0, 1, 1)
    world:draw_rect(player)

    -- draw coin
    if coin then
	    love.graphics.setColor(1, 1, 0)
	    world:draw_rect(coin)
	end

    res.unset()
end

function love.keypressed(key)
	if key == "m" then
		show_merged = not show_merged
	end
end