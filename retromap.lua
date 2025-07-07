--[[
    RetroMap - Lightweight tilemap collision library for LÖVE
	Author: poltergasm

    Tile Types:
    0 = Empty space
    1 = Solid block
    2 = 45 degree slope ascending right /
    3 = 45 degree slope ascending left \
    4 = 26.5 degree slope ascending right (lower half) _/
    5 = 26.5 degree slope ascending right (upper half) /‾
    6 = 26.5 degree slope ascending left (upper half) ‾\
    7 = 26.5 degree slope ascending left (lower half) \_
    8 = One-way platform
--]]

local rmap = {}
local rmap_mt = { __index = rmap }

function rmap.new_map(t)
	assert(type(t) == "table", "new_map expects a table")
	assert(t.tilemap, "new_map: No tilemap provided")

	local obj = {
		tilemap = t.tilemap,
		tile_size = 16,
		gravity = 8 * 60,
		max_fall_speed = 12 * 60,
		height = #t.tilemap,
		width = #t.tilemap[1],
		default_speed = 3 * 60,
		default_jump_force = 4 * 60,

		-- entity management
		entities = {},

		-- spatial hash settings
		cell_size = 64,
		spatial_hash = {},

		-- timing
		target_fps = 60,

		-- for merged collision shapes
		merged_solids = {},
		merged_oneways = {}
	}

	local invalid_opts = {
		tilemap = -1, -- no message required. it just needs to be ignored
		width = "Width is calculated from the tilemap, so is unnecessary here.",
		height = "Height is calculated from the tilemap, so is unnecessary here."
	}

	-- replace defaults if user prepared their own
	for k,v in pairs(t) do
		if invalid_opts[k] then
			if invalid_opts[k] ~= -1 then
				print("new_map: " .. invalid_opts[k])
			end
		else
			obj[k] = v
			print("new_map: '" .. k .. "' set to '" .. v .. "'")
		end
	end

	local instance = setmetatable(obj, rmap_mt)

	-- generate merged collision shapes on creation
	-- love me some optimization
	instance:generate_merged_collisions()
	return instance
end

function rmap:generate_merged_collisions()
	self:generate_merged_solids()
	self:generate_merged_oneways()
end

function rmap:generate_merged_solids()
	self.merged_solids = {}
	local visited = {}
	
	for y = 1, self.height do
		visited[y] = {}
		for x = 1, self.width do
			visited[y][x] = false
		end
	end
	
	for y = 1, self.height do
		for x = 1, self.width do
			if self.tilemap[y][x] == 1 and not visited[y][x] then
				local rect = self:find_largest_solid_rect(x, y, visited)
				if rect then
					table.insert(self.merged_solids, rect)
				end
			end
		end
	end
end

function rmap:find_largest_solid_rect(start_x, start_y, visited)
	local max_width = 0
	for x = start_x, self.width do
		if self.tilemap[start_y][x] == 1 and not visited[start_y][x] then
			max_width = max_width + 1
		else
			break
		end
	end
	
	if max_width == 0 then return nil end
	
	local height = 0
	for y = start_y, self.height do
		local can_extend = true

		for x = start_x, start_x + max_width - 1 do
			if self.tilemap[y][x] ~= 1 or visited[y][x] then
				can_extend = false
				break
			end
		end
		
		if can_extend then
			height = height + 1
		else
			break
		end
	end
	
	for y = start_y, start_y + height - 1 do
		for x = start_x, start_x + max_width - 1 do
			visited[y][x] = true
		end
	end
	
	return {
		x = (start_x - 1) * self.tile_size,
		y = (start_y - 1) * self.tile_size,
		width = max_width * self.tile_size,
		height = height * self.tile_size
	}
end

function rmap:generate_merged_oneways()
	self.merged_oneways = {}
	local visited = {}
	
	for y = 1, self.height do
		visited[y] = {}
		for x = 1, self.width do
			visited[y][x] = false
		end
	end
	
	for y = 1, self.height do
		for x = 1, self.width do
			if self.tilemap[y][x] == 8 and not visited[y][x] then
				local line = self:find_oneway_line(x, y, visited)
				if line then
					table.insert(self.merged_oneways, line)
				end
			end
		end
	end
end

function rmap:find_oneway_line(start_x, start_y, visited)
	local length = 0
	
	for x = start_x, self.width do
		if self.tilemap[start_y][x] == 8 and not visited[start_y][x] then
			visited[start_y][x] = true
			length = length + 1
		else
			break
		end
	end
	
	if length == 0 then return nil end
	
	return {
		x1 = (start_x - 1) * self.tile_size,
		y1 = (start_y - 1) * self.tile_size,
		x2 = (start_x - 1 + length) * self.tile_size,
		y2 = (start_y - 1) * self.tile_size
	}
end

function rmap:is_solid(ent, new_x, new_y)
	for _, rect in ipairs(self.merged_solids) do
		if self:aabb_check(new_x, new_y, ent.width, ent.height,
		                   rect.x, rect.y, rect.width, rect.height) then
			return true
		end
	end
	
	if new_x < 0 or new_y < 0 or 
	   new_x + ent.width > self.width * self.tile_size or 
	   new_y + ent.height > self.height * self.tile_size then
		return true
	end
	
	return false
end

function rmap:check_oneway_platform(ent, new_y)
	if ent.vy <= 0 then return nil end
	
	local ent_bottom = new_y + ent.height
	local ent_prev_bottom = ent.y + ent.height
	local ent_left = ent.x
	local ent_right = ent.x + ent.width
	
	for _, line in ipairs(self.merged_oneways) do
		if ent_right > line.x1 and ent_left < line.x2 then
			local platform_y = line.y1
			if ent_prev_bottom <= platform_y + 1 and ent_bottom >= platform_y then
				return platform_y - ent.height
			end
		end
	end
	
	return nil
end

function rmap:draw_merged_collisions()
	love.graphics.setColor(1, 0, 0, 0.3)
	for _, rect in ipairs(self.merged_solids) do
		love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height)
	end
	
	love.graphics.setColor(0, 1, 0, 0.8)
	love.graphics.setLineWidth(2)
	for _, line in ipairs(self.merged_oneways) do
		love.graphics.line(line.x1, line.y1, line.x2, line.y2)
	end
	love.graphics.setLineWidth(1)
end

function rmap:draw_debug()
	love.graphics.setColor(1, 1, 1, 0.2)
	self:draw_map()
	self:draw_merged_collisions()
	
	love.graphics.setColor(1, 1, 1, 1)
end

function rmap:create_ent(ent, x, y, w, h)
	if not h then
		error("create_ent: object requires ent, x, y, width, height properties")
	end

	local fields = {
		x = x,
		y = y,
		width = w,
		height = h,
		vx = 0,
		vy = 0,
		speed = self.default_speed,
		jump_force = self.default_jump_force,
		grounded = false,
		solid = true,
		static = false,
		filter = nil,
		sub_x = 0,
		sub_y = 0
	}

	for k,v in pairs(fields) do
		if not ent[k] then
			ent[k] = v
		end
	end
	
	table.insert(self.entities, ent)
	return ent
end

function rmap:remove_ent(ent)
	for i=#self.entities, 1, -1 do
		local e = self.entities[i]
		if e == ent then
			table.remove(self.entities, i)
			return
		end
	end
end

function rmap:hash_key(x, y)
	return math.floor(x / self.cell_size) .. "," .. math.floor(y / self.cell_size)
end

function rmap:update_spatial_hash()
	self.spatial_hash = {}
	for _, ent in ipairs(self.entities) do
		if ent.solid then
			local x1 = math.floor(ent.x / self.cell_size)
			local y1 = math.floor(ent.y / self.cell_size)
			local x2 = math.floor((ent.x + ent.width) / self.cell_size)
			local y2 = math.floor((ent.y + ent.height) / self.cell_size)
			
			for y = y1, y2 do
				for x = x1, x2 do
					local key = x .. "," .. y
					if not self.spatial_hash[key] then
						self.spatial_hash[key] = {}
					end
					table.insert(self.spatial_hash[key], ent)
				end
			end
		end
	end
end

function rmap:get_nearby_entities(x, y, w, h)
	local nearby = {}
	local seen = {}
	
	local x1 = math.floor(x / self.cell_size)
	local y1 = math.floor(y / self.cell_size)
	local x2 = math.floor((x + w) / self.cell_size)
	local y2 = math.floor((y + h) / self.cell_size)
	
	for cy = y1, y2 do
		for cx = x1, x2 do
			local key = cx .. "," .. cy
			if self.spatial_hash[key] then
				for _, ent in ipairs(self.spatial_hash[key]) do
					if not seen[ent] then
						seen[ent] = true
						table.insert(nearby, ent)
					end
				end
			end
		end
	end
	
	return nearby
end

function rmap:aabb_check(x1, y1, w1, h1, x2, y2, w2, h2)
	return x1 < x2 + w2 and
	       x1 + w1 > x2 and
	       y1 < y2 + h2 and
	       y1 + h1 > y2
end

function rmap:default_filter(ent, other)
	if other.type == "collectable" then
		return "cross"
	end

	return "slide"
end

function rmap:check_entity_collisions(ent, new_x, new_y)
	local collisions = {}
	local nearby = self:get_nearby_entities(new_x, new_y, ent.width, ent.height)
	
	for _, other in ipairs(nearby) do
		if other ~= ent then
			if self:aabb_check(new_x, new_y, ent.width, ent.height,
			                   other.x, other.y, other.width, other.height) then
				local filter = ent.filter or self.default_filter
				local response = filter(self, ent, other)
				
				if response then
					local nx, ny = 0, 0
					local ent_cx = new_x + ent.width / 2
					local ent_cy = new_y + ent.height / 2
					local other_cx = other.x + other.width / 2
					local other_cy = other.y + other.height / 2
					
					local left = (new_x + ent.width) - other.x
					local right = (other.x + other.width) - new_x
					local top = (new_y + ent.height) - other.y
					local bottom = (other.y + other.height) - new_y
					
					local min_x = left < right and left or right
					local min_y = top < bottom and top or bottom
					
					if min_x < min_y then
						if ent_cx < other_cx then
							nx = -1
						else
							nx = 1
						end
					else
						if ent_cy < other_cy then
							ny = -1
						else
							ny = 1
						end
					end
					
					table.insert(collisions, {
						other = other,
						type = response,
						normal = { x = nx, y = ny },
						overlap_x = min_x,
						overlap_y = min_y
					})

					--[[if ent.collides then
			        	print("has collides")
			        	ent:collides({ x = nx, y = ny }, other, response, min_x, min_y)
			        end]]
				end
			end
		end
	end
	
	return collisions
end

function rmap:resolve_slide(ent, col, dx, dy)
	local other = col.other
	local nx, ny = col.normal.x, col.normal.y
	
	if nx ~= 0 then
		if nx > 0 then
			return other.x - ent.width, ent.y + dy, 0, ent.vy
		else
			return other.x + other.width, ent.y + dy, 0, ent.vy
		end
	else
		if ny > 0 then
			return ent.x + dx, other.y - ent.height, ent.vx, 0
		else
			return ent.x + dx, other.y + other.height, ent.vx, 0
		end
	end
end

local slope_tiles = { [2] = 1, [3] = 1, [4] = 1, [5] = 1, [6] = 1, [7] = 1 }

function rmap:calculate_slope_height(tile_type, tile_x, tile_y, ent_center_x)
    local rel_x = ent_center_x - tile_x
    if rel_x < 0 then rel_x = 0 end
    if rel_x > self.tile_size then rel_x = self.tile_size end
    
    if tile_type == 2 then
    	return tile_y + self.tile_size - rel_x
	elseif tile_type == 3 then
    	return tile_y + rel_x
    elseif tile_type == 4 then
        return tile_y + self.tile_size - (rel_x * 0.5)
    elseif tile_type == 5 then
        return tile_y + self.tile_size * 0.5 - (rel_x * 0.5)
    elseif tile_type == 6 then
        return tile_y + (rel_x * 0.5)
    elseif tile_type == 7 then
        return tile_y + self.tile_size * 0.5 + (rel_x * 0.5)
    end
    
    return nil
end

function rmap:get_slope_collision_y(x, y, width, height)
    local ent_bottom = y + height
    local ent_center_x = x + width / 2
    local left_tile = math.floor(x / self.tile_size) + 1
    local right_tile = math.floor((x + width - 1) / self.tile_size) + 1
    local bottom_tile = math.floor((ent_bottom - 1) / self.tile_size) + 1
    
    local best_y = nil
    local best_distance = math.huge
    
    for col = left_tile, right_tile do
        if col >= 1 and col <= self.width and bottom_tile >= 1 and bottom_tile <= self.height then
            local tile = self.tilemap[bottom_tile][col]
            if slope_tiles[tile] then
                local tile_x = (col - 1) * self.tile_size

                local tile_y = (bottom_tile - 1) * self.tile_size
                local slope_height = self:calculate_slope_height(tile, tile_x, tile_y, ent_center_x)
                
                if slope_height and ent_bottom >= slope_height - 2 then
                    local ent_top_y = slope_height - height
                    
                    local tile_center_x = tile_x + self.tile_size / 2
                    local distance_from_center = math.abs(ent_center_x - tile_center_x)
                    
                    if distance_from_center < best_distance then
                        best_distance = distance_from_center
                        best_y = ent_top_y
                    end
                end
            end
        end
    end
    
    if bottom_tile > 1 then
        for col = left_tile, right_tile do
            if col >= 1 and col <= self.width then
                local tile = self.tilemap[bottom_tile - 1][col]
                if slope_tiles[tile] then
                    local tile_x = (col - 1) * self.tile_size
                    local tile_y = (bottom_tile - 2) * self.tile_size
                    local slope_height = self:calculate_slope_height(tile, tile_x, tile_y, ent_center_x)
                    
                    if slope_height and math.abs(ent_bottom - slope_height) < 4 then
                        local ent_top_y = slope_height - height
                        
                        local tile_center_x = tile_x + self.tile_size / 2
                        local distance_from_center = math.abs(ent_center_x - tile_center_x)
                        
                        if distance_from_center < best_distance then
                            best_distance = distance_from_center
                            best_y = ent_top_y
                        end
                    end
                end
            end
        end
    end
    
    return best_y
end

function rmap:check_for_nearby_slope(x, y, width, height, max_drop)
    max_drop = max_drop or self.tile_size
    local ent_center_x = x + width / 2
    local left_tile = math.floor(x / self.tile_size) + 1
    local right_tile = math.floor((x + width - 1) / self.tile_size) + 1
    
    for drop = 0, max_drop, 4 do
        local check_y = y + drop
        local check_bottom = check_y + height
        local bottom_tile = math.floor(check_bottom / self.tile_size) + 1
        
        if bottom_tile >= 1 and bottom_tile <= self.height then
            for col = left_tile, right_tile do
                if col >= 1 and col <= self.width then
                    local tile = self.tilemap[bottom_tile][col]
                    if slope_tiles[tile] then
                        local tile_x = (col - 1) * self.tile_size
                        local tile_y = (bottom_tile - 1) * self.tile_size
                        local slope_height = self:calculate_slope_height(tile, tile_x, tile_y, ent_center_x)
                        
                        if slope_height and check_bottom <= slope_height + 4 then
                            return slope_height - height
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

function rmap:apply_physics(ent, dt)
	if ent.static then return end
	if ent.remove then
		self:remove_ent(ent)
		return
	end
	
	dt = dt or (1 / self.target_fps)
	
	ent.vy = ent.vy + self.gravity * dt
    if ent.vy > self.max_fall_speed then
        ent.vy = self.max_fall_speed
    end
    
    ent.collisions = {}
    
    local dx = ent.vx * dt
    local dy = ent.vy * dt
    
    ent.sub_x = ent.sub_x + dx
    ent.sub_y = ent.sub_y + dy
    
    local move_x = math.floor(ent.sub_x)
    local move_y = math.floor(ent.sub_y)
    
    ent.sub_x = ent.sub_x - move_x
    ent.sub_y = ent.sub_y - move_y
    
    if move_x ~= 0 then
	    local new_x = ent.x + move_x
	    local new_y = ent.y
	    
	    local collisions = self:check_entity_collisions(ent, new_x, new_y)
	    
	    for _, col in ipairs(collisions) do
	        if col.type == "slide" then
	            new_x, new_y, ent.vx, ent.vy = self:resolve_slide(ent, col, move_x, 0)
	            ent.sub_x = 0
	        elseif col.type == "cross" then
	            table.insert(ent.collisions, col)
	        end
	    end
	    
	    if not self:is_solid(ent, new_x, ent.y) then
	        ent.x = new_x
	        
	        if ent.grounded then
	            local slopeY = self:get_slope_collision_y(ent.x, ent.y, ent.width, ent.height)
	            if slopeY then
	                ent.y = slopeY
	            else
	                local slope_below = self:check_for_nearby_slope(ent.x, ent.y, ent.width, ent.height, self.tile_size - 4)
	                if slope_below then

	                    ent.y = ent.y + 2
	                    if ent.y > slope_below then
	                        ent.y = slope_below
	                    end
	                end
	            end
	        end
	    else
	        ent.vx = 0
	        ent.sub_x = 0
	    end
	end
    
    if move_y ~= 0 then
        local new_y = ent.y + move_y
        local new_x = ent.x
        ent.grounded = false
        
        local platform_y = self:check_oneway_platform(ent, new_y)
        if platform_y then
            ent.y = platform_y
            ent.vy = 0
            ent.sub_y = 0
            ent.grounded = true
            return
        end
        
        if ent.vy >= 0 then
            local slopeY = self:get_slope_collision_y(ent.x, new_y, ent.width, ent.height)
            if slopeY then
                ent.y = slopeY
                ent.vy = 0
                ent.sub_y = 0
                ent.grounded = true
                return
            end
        end
        
        local collisions = self:check_entity_collisions(ent, new_x, new_y)
        
        for _, col in ipairs(collisions) do
        	if col.type == "slide" then
        		new_x, new_y, ent.vx, ent.vy = self:resolve_slide(ent, col, 0, move_y)
        		ent.sub_y = 0
        		if col.normal.y == -1 then
        			ent.grounded = true
        		end
        	elseif col.type == "cross" then
        		table.insert(ent.collisions, col)
        	end
        end
        
        if not self:is_solid(ent, ent.x, new_y) then
            ent.y = new_y
        else
            if ent.vy > 0 then
                ent.grounded = true
                ent.vy = 0
                ent.sub_y = 0
            else
                local tile_row = math.ceil(ent.y / self.tile_size)
                ent.y = tile_row * self.tile_size
                ent.vy = 0
                ent.sub_y = 0
            end
        end
    end
end

function rmap:update_all(dt)
	self:update_spatial_hash()
	
	for _, ent in ipairs(self.entities) do
		self:apply_physics(ent, dt)
		if ent.update then ent:update(dt) end
	end
end

function rmap:draw_rect(ent)
	love.graphics.rectangle("line", ent.x, ent.y, ent.width, ent.height)
end

function rmap:draw_rect_tile(x, y)
	if not self.tilemap[y] and not self.tilemap[y][x] then
		error("Attempted to draw rect of invalid co-ordinates: " .. x .. ", " .. y)
	end

	local tile = self.tilemap[y][x]
    local world_x = (x - 1) * self.tile_size
    local world_y = (y - 1) * self.tile_size
    
    love.graphics.setColor(1, 1, 1, 1)

    if tile == 1 then
        love.graphics.rectangle("line", world_x, world_y, self.tile_size, self.tile_size)

    elseif tile == 2 then
        love.graphics.polygon("line", 
            world_x, world_y + self.tile_size,
            world_x + self.tile_size, world_y + self.tile_size,
            world_x + self.tile_size, world_y)

    elseif tile == 3 then
        love.graphics.polygon("line", 
            world_x, world_y + self.tile_size,
            world_x + self.tile_size, world_y + self.tile_size,
            world_x, world_y)

    elseif tile == 4 then
        love.graphics.polygon("line", 
            world_x, world_y + self.tile_size,
            world_x + self.tile_size, world_y + self.tile_size,
            world_x + self.tile_size, world_y + self.tile_size * 0.5,
            world_x, world_y + self.tile_size)

    elseif tile == 5 then
        love.graphics.polygon("line", 
            world_x, world_y + self.tile_size,
            world_x + self.tile_size, world_y + self.tile_size,
            world_x + self.tile_size, world_y,
            world_x, world_y + self.tile_size * 0.5)

    elseif tile == 6 then
        love.graphics.polygon("line", 
            world_x, world_y + self.tile_size,
            world_x + self.tile_size, world_y + self.tile_size,
            world_x + self.tile_size, world_y + self.tile_size * 0.5,
            world_x, world_y)

    elseif tile == 7 then
        love.graphics.polygon("line", 
            world_x, world_y + self.tile_size,
            world_x + self.tile_size, world_y + self.tile_size,
            world_x + self.tile_size, world_y + self.tile_size,
            world_x, world_y + self.tile_size * 0.5)
    
    elseif tile == 8 then
        love.graphics.line(world_x, world_y, world_x + self.tile_size, world_y)
    end
end

function rmap:draw_map()
	for y = 1, self.height do
        for x = 1, self.width do
            self:draw_rect_tile(x, y)
        end
    end
end

function rmap:draw_entities()
	for _, ent in ipairs(self.entities) do
		self:draw_rect(ent)
	end
end

return rmap
