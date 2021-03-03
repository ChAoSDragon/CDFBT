--[[ TODO
dynamically fill shapes table with minimal editing
 -> ideally, adding a piece should only require making the file in the pieces dir
finesse?
all spins -- what constitues non-t-spins?
refactoring
]]

function copy_table(t)
    local new_table = {}

    for i,v in pairs(t) do
        if type(v) == "table" then
            new_table[i] = copy_table(v)
        else
            new_table[i] = v
        end
    end

    setmetatable(new_table, getmetatable(t))

    return new_table
end

function table_to_string(t)
    local val = ""

    for i,v in pairs(t) do
        if type(v) == "number" or type(v) == "string" then
            val = val..i.." = "..v.."\n"
        elseif type(v) == "table" then
            val = table_to_string(t)
        else
            val = val..i.." = "..type(v).."\n"
        end
    end

    return val.."\n"
end

function make_grid()
    local empty_column = {}
    local wall = {}

    for i=1,options["playfield_size"][2] do
        table.insert(empty_column, "empty")
        table.insert(wall, "wall")
    end

    empty_column[#empty_column + 1] = "wall"
    wall[#wall + 1] = "wall"

    for i=1,options["playfield_size"][1] do
        table.insert(grid, copy_table(empty_column))
    end

    table.insert(grid, 1, copy_table(wall))
    table.insert(grid, #grid + 1, copy_table(wall))
end

function reset_game()
    grid = {}
    make_grid()

    lines_cleared = 0
    quads_cleared = 0
    previous_clear = ""
    firework_delay = 0
    fireworks_left = 0
    firework_x = 0
    firework_y = 0
    gravity_current = 0
    lock_delay_current = 0
    das.pressed = false
    das.charge = 0
    das.arr_charge = 0
    bags = {}
    bags.position = 1
    bags.size = 7
    bags[1] = generate_bag()
    bags[2] = generate_bag()
    hold_piece = nil
    can_hold = true
    changed_grid = {}
    efficiency = {
        i_pieces = 0,
        t_pieces = 0,
        t_spins = 0,
        total_pieces = 0,
        total_time = 0
    }

    new_piece()
end

function love.load()
    require("options")
    grid = {}
    make_grid()

    math.randomseed(os.time())

    require("piece")

    shapes = {}

    -- load music
    local files = love.filesystem.getDirectoryItems("music")
    for i,v in ipairs(files) do
        table.insert(options["music"]["tracks"], love.audio.newSource("music/"..v, "stream"))
    end

    -- load sounds
    sounds = {
        lock = love.audio.newSource("sound/lock.wav", "static"),
        move_right = love.audio.newSource("sound/move_right.wav", "static"),
        move_left = love.audio.newSource("sound/move_left.wav", "static"),
        rotate_right = love.audio.newSource("sound/rotate_right.wav", "static"),
        rotate_left = love.audio.newSource("sound/rotate_left.wav", "static"),
        line_clear = love.audio.newSource("sound/clear.wav", "static"),
        quad = love.audio.newSource("sound/quad.wav", "static"),
        spin = love.audio.newSource("sound/spin.wav", "static"),
        all_clear = love.audio.newSource("sound/all_clear.wav", "static"),
        firework = love.audio.newSource("sound/firework.wav", "static")
    }

    -- load pieces
    local piece_files = love.filesystem.getDirectoryItems("pieces")
    for i,v in ipairs(piece_files) do
        local a, b = string.find(v, ".lua")
        require("pieces."..string.sub(v, 1, a - 1))
    end

    if options["use_skin"] then
        skin_image = love.graphics.newImage(options["skin"])
    end

    next_graphics = {}

    next_piece_canvas = love.graphics.newCanvas(960, 48)

    love.graphics.setCanvas(next_piece_canvas)
    love.graphics.clear()

    local draw_pos = 0
    love.graphics.setBlendMode("alpha")
    for i,piece in pairs(shapes) do
        local p = create_piece(piece)
        p.x = draw_pos
        p.y = 0
        p:draw()
        next_graphics[p.shape] = love.graphics.newQuad((p.x + 3) * 24, 0, 96, 48, next_piece_canvas)
        draw_pos = draw_pos + 4
    end
    love.graphics.setCanvas()
    next_graphics.canvas = next_piece_canvas

    stat_panel_x = (options["playfield_size"][1] * 24) + 272
    stat_panel_y = 0
    lines_cleared = 0
    quads_cleared = 0
    previous_clear = ""
    firework_delay = 0
    fireworks_left = 0
    firework_x = 0
    firework_y = 0
    gravity_limit = 2
    gravity_current = 0
    lock_delay_limit = 2
    lock_delay_current = 0
    pause_gravity = false
    das = {}
    das.pressed = false
    das.charge = 0
    das.delay = options["das"]
    das.arr_charge = 0
    das.arr_rate = options["arr"]
    bags = {}
    bags.position = 1
    bags.size = 7
    bags[1] = generate_bag()
    bags[2] = generate_bag()
    hold_piece = nil
    can_hold = true
    changed_grid = {}
    efficiency = {
        i_pieces = 0,
        t_pieces = 0,
        t_spins = 0,
        total_pieces = 0,
        total_time = 0
    }

    firework = love.graphics.newParticleSystem(love.graphics.newImage("firework.png"), 600)
    firework:setParticleLifetime(0.3, 0.3)
    firework:setSizeVariation(1)
    firework:setSpeed(0)
    firework:setLinearAcceleration(-100, -100, 100, 100)
    firework:setRadialAcceleration(-800, 800)
    new_piece()
end

function get_level()
    local max_level = #options["level_speed_table"]

    return math.min(math.floor((lines_cleared / options["lines_per_level"]) + 1), max_level)
end

function play_sound(s)
    if options["sound_enabled"] then
        local newsound = s:clone()
        love.audio.play(newsound)
    end
end

function play_music()
    if options["music_enabled"] then
        local pick_music = math.min(get_level(), #options["music"]["tracks"])

        if pick_music > 0 then
            if love.audio.getActiveSourceCount() == 0 then
                options["music"]["currently_playing"] = nil
            end

            if options["music"]["currently_playing"] ~= pick_music then
                love.audio.stop()
                options["music"]["currently_playing"] = pick_music
                love.audio.play(options["music"]["tracks"][pick_music])
            end
        end
    end
end

function check_line_clears()
    local col_check = 2
    local con = true
    local lines = 0
    local all_clear = true
    previous_clear = ""

    for i,v in ipairs(grid[2]) do
        if i < options["playfield_size"][2] + 1 then
            row_check = i
            while col_check < options["playfield_size"][1] + 2 do
                if grid[col_check][row_check] == "empty" then
                    con = false
                    break
                end
                col_check = col_check + 1
            end

            if con == true then
                for r=2,options["playfield_size"][1] + 1 do
                    table.remove(grid[r], i)
                    table.insert(grid[r], 1, "empty")
                end
                lines = lines + 1
            end
        end

        con = true
        col_check = 2
    end

    -- check for perfect clear
    for i,v in ipairs(grid) do
        for j,w in ipairs(v) do
            if w ~= "empty" and w ~= "wall" then
                all_clear = false
                break
            end
        end

        if not all_clear then
            break
        end
    end

    if lines == 4 then
        quads_cleared = quads_cleared + 1
    end

    if lines > 0 then
        lines_cleared = lines_cleared + lines

        if all_clear then
            previous_clear = "perfect clear"
        elseif lines == 1 then
            previous_clear = "single"
        elseif lines == 2 then
            previous_clear = "double"
        elseif lines == 3 then
            previous_clear = "triple"
        else
            previous_clear = "quad"
        end
    end
end

function generate_bag()
    local base = {}
    local new_bag = {}

    for i,v in pairs(shapes) do
        table.insert(base, i)
    end

    while #base > 0 do
        pick = math.random(1, #base)
        table.insert(new_bag, base[pick])
        table.remove(base, pick)
    end

    return new_bag
end

function create_piece(piece)
    local p = copy_table(piece)
    setmetatable(p, {__index = Piece})
    return p
end

function new_piece(sp)
    -- TODO: should spawn on row 21
    local p = sp or bags[1][bags.position]

    if not sp then
        bags.position = bags.position + 1
    end

    if bags.position > bags.size then
        bags.position = 1
        table.remove(bags, 1)
        bags[2] = generate_bag()
    end

    if not sp then
        current_piece = create_piece(shapes[p])
    else
        current_piece = create_piece(shapes[sp])
    end

    gravity_current = 0

    if not current_piece:grid_empty(current_piece:get_coords()) then
        -- game over
        love.load()
    end
end

function stat_panel_print(str, y)
    love.graphics.print(str, stat_panel_x, stat_panel_y)

    if y then
        stat_panel_y = stat_panel_y + y
    else
        stat_panel_y = stat_panel_y + 12
    end
end

function move_stat_panel_y(y)
    stat_panel_y = y
    return stat_panel_y
end

function draw_stat_panel()
    stat_panel_y = 0
    love.graphics.setColor({1,1,1})
    -- FPS
    stat_panel_print("FPS: "..love.timer.getFPS(), 24)
    -- gravity and lock delay
    stat_panel_print("gravity: "..string.format("%.3f", gravity_current).."/"..string.format("%.3f", gravity_limit))
    stat_panel_print("lock delay: "..string.format("%.3f", lock_delay_current).."/"..string.format("%.3f", lock_delay_limit))
    -- das
    stat_panel_print("das: "..string.format("%.2f", das.charge).."/"..das.delay.." arr: "..string.format("%.2f", das.arr_charge).."/"..das.arr_rate)
    -- level
    stat_panel_print("level: "..get_level())
    -- pps
    local pps
    if efficiency["total_time"] > 0 then
        pps = efficiency["total_pieces"] / efficiency["total_time"]
    else
        pps = 0
    end
    stat_panel_print("pps: "..string.format("%.2f", pps))
    -- lines + previous clear
    stat_panel_print("lines: "..lines_cleared)
    stat_panel_print("quads: "..quads_cleared)
    stat_panel_print(previous_clear)
    -- TRT, BRN
    local trt
    local brn
    if lines_cleared > 0 then
        trt = (quads_cleared * 4) / lines_cleared
        brn = lines_cleared - (quads_cleared * 4)
        trt = trt * 100
    else
        trt = 0
        brn = 0
    end
    stat_panel_print("TRT: "..string.format("%.2f", trt).."%")
    stat_panel_print("BRN: "..brn)
    -- quad/i, spin/t
    local qpi
    local spt
    if efficiency["i_pieces"] > 0 then
        qpi = quads_cleared / efficiency["i_pieces"]
    else
        qpi = 0
    end
    if efficiency["t_pieces"] > 0 then
        spt = efficiency["t_spins"] / efficiency["t_pieces"]
    else
        spt = 0
    end
    qpi = qpi * 100
    spt = spt * 100
    stat_panel_print("quad/I: "..quads_cleared.."/"..efficiency["i_pieces"].." ("..string.format("%.2f", qpi).."%)")
    stat_panel_print("spin/T: "..efficiency["t_spins"].."/"..efficiency["t_pieces"].." ("..string.format("%.2f", spt).."%)", 300)
end

function love.draw()
    -- draw grid lines
    for x = 4, options["playfield_size"][1] + 4 do
        love.graphics.setColor({1, 0, 0, 0.5})
        love.graphics.line((x + 1) * 24, 24, (x + 1) * 24, 96)
        love.graphics.setColor({1, 1, 1, 0.5})
        love.graphics.line((x + 1) * 24, 96, (x + 1) * 24, (options["playfield_size"][2] + 1) * 24)
    end
    for y = 1, options["playfield_size"][2] + 1 do
        if y < 5 then
            love.graphics.setColor({1, 0, 0, 0.5})
            love.graphics.line(96, y * 24, (options["playfield_size"][1]) * 24 + 120, y * 24)
        else
            love.graphics.setColor({1, 1, 1, 0.5})
            love.graphics.line(96, y * 24, (options["playfield_size"][1]) * 24 + 120, y * 24)
        end
    end

    -- draw placed pieces
    for x,col in ipairs(grid) do
        for y,row in ipairs(col) do
            if options["invisible_mode"] and row ~= "wall" then
                love.graphics.setColor({0, 0, 0, 0})
            elseif row == "empty" or not options["monotone"] then
                if options["colors"][row] then
                    love.graphics.setColor(options["colors"][row])
                else
                    love.graphics.setColor(options["colors"]["garbage"])
                end
            else
                love.graphics.setColor(options["monotone_color"])
            end

            if options["use_skin"] then
                love.graphics.draw(skin_image, (x + 3) * 24, y * 24)
            else
                love.graphics.rectangle("fill", (x + 3) * 24, y * 24, 24, 24)
            end
        end
    end

    -- draw current piece
    current_piece:draw()

    -- ghost piece
    if options["ghost_piece"] then
        local ghost_pos = current_piece:get_coords({0, 0})
        local ghost_y = 0
        local current_color
        if not options["monotone"] then
            if options["colors"][current_piece.shape] then
                current_color = options["colors"][current_piece.shape]
            else
                current_color = options["colors"]["garbage"]
            end
        else
            current_color = options["monotone_color"]
        end
        ghost_color = {current_color[1], current_color[2], current_color[3], 0.5}
        while true do
            if not current_piece:grid_empty(ghost_pos) then
                ghost_pos = current_piece:get_coords({0, ghost_y - 1})
                for i,v in ipairs(ghost_pos) do
                    love.graphics.setColor(ghost_color)
                    if options["use_skin"] then
                        love.graphics.draw(skin_image, (v[1] + 3) * 24, v[2] * 24)
                    else
                        love.graphics.rectangle("fill", (v[1] + 3) * 24, v[2] * 24, 24, 24)
                    end
                end
                break
            elseif ghost_y > 20 then
                break
            end

            ghost_y = ghost_y + 1
            ghost_pos = current_piece:get_coords({0, ghost_y})
        end
    end

    -- draw next pieces
    love.graphics.setColor({1,1,1,1})
    local next_pos = bags.position
    local bag_sel = 1
    local drawn = 0
    while drawn < math.min(math.max(options["next_pieces"], 0), 6) do
        if next_pos >= 8 then
            next_pos = next_pos - 7
            bag_sel = 2
            love.graphics.line(400, 51 * (drawn + 1), 496, 51 * (drawn + 1))
        end

        nextp = bags[bag_sel][next_pos]
        love.graphics.print(nextp, 400, 52 * (drawn + 1))
        love.graphics.draw(next_graphics.canvas, next_graphics[nextp], 412, 52 * (drawn + 1))

        next_pos = next_pos + 1
        drawn = drawn + 1
    end

    -- hold piece
    love.graphics.setColor({1, 1, 1})
    love.graphics.print("Hold", 0, 24)
    if hold_piece then
        --love.graphics.setBlendMode("alpha", "premultiplied")
        if not can_hold then
            love.graphics.setColor({0.3, 0.3, 0.3})
        end
        love.graphics.draw(next_graphics.canvas, next_graphics[hold_piece], 0, 36)
        --love.graphics.setBlendMode("alpha")
        love.graphics.setColor({1, 1, 1})
    end

    -- stat panel
    draw_stat_panel()

    -- cursor
    love.graphics.setColor({0,1,0})
    local mouse_x = love.mouse.getX()
    local mouse_y = love.mouse.getY()
    if mouse_x > 120 and mouse_x < (options["playfield_size"][1] * 24) + 120 and mouse_y > 24 and mouse_y < 576 then
        love.graphics.rectangle("line", math.floor(love.mouse.getX() / 24) * 24, math.floor(love.mouse.getY() / 24) * 24, 24, 24)
    end

    -- fireworks
    love.graphics.setColor({1,1,1})
    love.graphics.draw(firework, firework_x, firework_y)
end

function love.update(dt)
    firework:update(dt)

    play_music()
    efficiency["total_time"] = efficiency["total_time"] + dt

    -- das
    local das_dir
    local left_right_down = false
    local moved = false

    if love.keyboard.isDown(options["keys"]["move_left"]) then
        das_dir = {-1, 0}
        left_right_down = true
    elseif love.keyboard.isDown(options["keys"]["move_right"]) then
        das_dir = {1, 0}
        left_right_down = true
    end

    -- arr
    if left_right_down then
        if das.pressed == false then
            if current_piece:move(das_dir) then
                if das_dir[1] > 0 then
                    play_sound(sounds["move_right"])
                else
                    play_sound(sounds["move_left"])
                end
            end
            das.pressed = true
        else
            if das.charge < das.delay then
                das.charge = das.charge + dt
            else
                das.arr_charge = das.arr_charge + dt
                if das.arr_rate > 0 then
                    while das.arr_charge >= das.arr_rate do
                        das.arr_charge = das.arr_charge - das.arr_rate
                        current_piece:move(das_dir)
                    end
                else
                    ax = current_piece.x
                    while true do
                        current_piece:move(das_dir)
                        if current_piece.x == ax then
                            break
                        end
                        ax = current_piece.x
                    end
                end
            end
        end
    end

    -- level
    gravity_limit = options["level_speed_table"][get_level()][1]

    -- soft drop
    if love.keyboard.isDown(options["keys"]["soft_drop"]) then
        --gravity_current = gravity_limit
        if options["soft_drop_factor"] > 0 then
            gravity_current = gravity_current + (gravity_limit * options["soft_drop_factor"])
        else
            gravity_current = gravity_limit * 30
        end
    else
        if not pause_gravity then
            gravity_current = gravity_current + dt
        end
    end

    -- gravity
    if gravity_current < 0 then
        gravity_current = 0
    end

    if gravity_limit > 0 then
        while gravity_current >= gravity_limit do
            current_piece:move({0,1})
            gravity_current = gravity_current - gravity_limit
        end
    else
        local gy = current_piece.y
        gravity_current = 0
        while true do
            current_piece:move({0,1})
            if current_piece.y == gy then
                break
            end
            gy = current_piece.y
        end
    end

    -- lock delay
    lock_delay_limit = options["level_speed_table"][get_level()][2]
    if not current_piece:grid_empty(current_piece:get_coords({0, 1})) then
        if not pause_gravity then
            lock_delay_current = lock_delay_current + dt
        end
    end

    if lock_delay_current >= lock_delay_limit then
        current_piece:lock()
    end

    -- mouse
    if options["draw_garbage_enabled"] then
        local mouse_x = love.mouse.getX()
        local mouse_y = love.mouse.getY()
        local mouse_button = love.mouse.isDown(1)
        local change = true
        if mouse_button then
            if mouse_x > 120 and mouse_x < (options["playfield_size"][1] * 24) + 120 and mouse_y > 24 and mouse_y < 576 then
                grid_x = math.floor(mouse_x / 24) - 3
                grid_y = math.floor(mouse_y / 24)
                for i,v in ipairs(changed_grid) do
                    if v[1] == grid_x and v[2] == grid_y then
                        change = false
                        break
                    end
                end
                if change then
                    if grid[grid_x][grid_y] == "empty" then
                        grid[grid_x][grid_y] = "garbage"
                    else
                        grid[grid_x][grid_y] = "empty"
                    end
                table.insert(changed_grid, {grid_x, grid_y})
                end
            end
        end
    end

    -- fireworks
    if fireworks_left > 0 then
        if firework_delay <= 0 then
            firework_x = math.random(72, 312)
            firework_y = math.random(72, 216)
            firework:setColors({math.random(50, 100) / 100, math.random(50, 100) / 100, math.random(50, 100) / 100})
            play_sound(sounds["firework"])
            firework:emit(200)
            fireworks_left = fireworks_left - 1
            if fireworks_left > 0 then
                firework_delay = 0.4
            end
        end
        firework_delay = firework_delay - dt
    end
end

function love.keypressed(key)
    current_piece:keypressed(key)

    if key == options["keys"]["quit_game"] then
        love.event.quit(0)
    elseif key == options["keys"]["restart_game"] then
        reset_game()
    elseif key == options["keys"]["pause_gravity"] and options["pause_gravity_enabled"] then
        pause_gravity = not pause_gravity
    end
end

function love.mousereleased(x, y, button)
    changed_grid = {}
end

function love.keyreleased(key)
    if not love.keyboard.isDown(options["keys"]["move_left"]) and not love.keyboard.isDown(options["keys"]["move_right"]) and not love.keyboard.isDown(options["keys"]["soft_drop"]) then
        das.pressed = false
        das.charge = 0
        das.arr_charge = 0
    end
end
