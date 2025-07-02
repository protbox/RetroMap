## What is this?

RetroMap is a lightweight tilemap collision library for LÖVE that gets you up and running in minutes. No complex setup, no bloated features - just clean, efficient collision detection with the essentials baked in.

## Features

- Solid tiles, slopes (45° and 26.5°), and one-way platforms
- Entity-to-entity collision with spatial hashing for optimization
- Pixel-perfect physics with delta time support
- Collision filtering (solid, pass-through, or ignored)
- Zero dependencies. Everything you need in a single file

## Getting Started

Honestly, I hate writing documentation, so this will quick (sorry).

Your first step will be requiring the module and creating a world

```lua
local rmap = require "path.to.retromap"

local world = rmap.new_map({
	tilemap = {...} -- supplying a tilemap is a MUST. see demo in main.lua for an example
})

function love.draw()
	-- draw the collision shapes to screen
	world:draw_debug()
end
```

That's all you need to get a map up and running. But it's not a lot of use without a player to run around.
We can use `rmap:create_ent(x, y, w, h)` to create and return a retromap-friendly entity.

```lua
local player = rmap:create_ent(64, 64, 12, 16)
```

Then, to make them move.

```lua
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
end
```

`world:update_all(dt)` updates all entities added to retromap via `create_ent`. This includes collision response and physics.
You can check collisions like so:

```lua
for _, col in ipairs(player.collisions) do
	-- col is a table that provides useful collision information
	-- other = the entity object it collided with
	-- type = the type of collision (slide or cross)
	-- normal = where the collision took place (x, y)
	-- overlap_x = the x overlap
	-- overlap_y = the y overlap

	-- let's say we wanted to make it so you had to jump on coins to collect them
	if col.other.is_coin and col.normal.y == -1 then
		col.other:collect()
	end
end
```

## Tile Types

Being a tilemap collision system, the tile numbers are incredibly important. Here's a list so far:

	0 = Empty space
	1 = Solid block
	2 = 45 degree slope ascending right /
	3 = 45 degree slope ascending left \
	4 = 26.5 degree slope ascending right (lower half) _/
	5 = 26.5 degree slope ascending right (upper half) /‾
	6 = 26.5 degree slope ascending left (upper half) \‾
	7 = 26.5 degree slope ascending left (lower half) \_
	8 = One-way platform

There should be enough there to get you up and running. For anything else, you can use the entity system.