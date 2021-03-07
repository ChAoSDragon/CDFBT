Piece = {
    x = math.floor(options["playfield_size"][1] / 2),
    y = 2,
    shape = "",
    rotation = 1,
    rotation_coords = {},
    last_action = "move"
}

function Piece:get_coords(offset)
    local offset = offset or {0, 0}
    local coords = self.rotation_coords[self.rotation]
    local p = {}

    for i,v in ipairs(coords) do
        table.insert(p, {self.x + coords[i][1] + offset[1], self.y + coords[i][2] + offset[2]})
    end

    return p
end

function Piece:get_width()
    -- the first rotation should be the widest
    local coords = self.rotation_coords[1]
    local width = 0
    local x_pos = {0, 0} -- lowest, highest x

    for i,v in ipairs(coords) do
        if v[1] < x_pos[1] then
            x_pos[1] = v[1]
        end

        if v[1] > x_pos[2] then
            x_pos[2] = v[1]
        end
    end

    return math.max((x_pos[2] - x_pos[1]) + 1, 1)
end

function Piece:move(direction)
    local old_pos = self:get_coords()
    local new_pos = self:get_coords(direction)

    -- if new area is empty, move
    if self:grid_empty(new_pos) then
        self.x = self.x + direction[1]
        self.y = self.y + direction[2]
        self.last_action = "move"
        -- only reset gravity if the below area is occupied
        if not self:grid_empty(self:get_coords({0, 1})) then
            gravity_current = 0
        end
        lock_delay_current = 0
        return true
    else
        return false
    end
end

function Piece:rotate(direction)
    local invert
    local kick_row = self.rotation

    if direction == "right" then
        self.rotation = self.rotation + 1

        if self.rotation > 4 then
            self.rotation = 1
        end
        invert = 1
    else
        self.rotation = self.rotation - 1

        if self.rotation < 1 then
            self.rotation = 4
        end

        kick_row = self.rotation
        invert = -1
    end

    local coords = self.rotation_coords[self.rotation]
    local kick_attempt = 1
    while true do
        local new_pos = {}

        for i,v in ipairs(coords) do
            table.insert(new_pos,
                {self.x + coords[i][1] + (self.kick_table[kick_row][kick_attempt][1] * invert),
                self.y + coords[i][2] + (self.kick_table[kick_row][kick_attempt][2] * invert)}
            )
        end

        if self:grid_empty(new_pos) then
            local move_x = self.kick_table[kick_row][kick_attempt][1] * invert
            local move_y = self.kick_table[kick_row][kick_attempt][2] * invert
            self.x = self.x + move_x
            self.y = self.y + move_y
            if invert == 1 then
                play_sound(sounds["rotate_right"])
            else
                play_sound(sounds["rotate_left"])
            end
            self.last_action = "rotate"
            lock_delay_current = 0
            break
        end

        if kick_attempt == 5 then
            if direction == "right" then
                self.rotation = self.rotation - 1
                if self.rotation < 1 then
                    self.rotation = 4
                end
            else
                self.rotation = self.rotation + 1
                if self.rotation > 4 then
                    self.rotation = 1
                end
            end
            break
        end

        kick_attempt = kick_attempt + 1
    end
end

function Piece:grid_empty(pos)
    check = true
    -- if a pos is outside the grid, instant false.
    for i,v in ipairs(pos) do
        if (v[1] < 1 or v[1] > 11) or (v[2] < 0 or v[2] > 23) then
            check = false
        end
    end

    if check == true then
        for i,v in ipairs(pos) do
            if grid[v[1]][v[2]] ~= "empty" then
                check = false
                break
            end
        end
        return check
    end

    return check
end

function Piece:lock()
    local spin_count = 0
    local spin_type = ""
    local final_pos = {}
    local over_playfield = 0

    efficiency["total_pieces"] = efficiency["total_pieces"] + 1

    for i,v in pairs(self.rotation_coords[self.rotation]) do
        grid[self.x + v[1]][self.y + v[2]] = self.shape
        final_pos[i] = self.y + v[2]
    end

    for i,v in ipairs(final_pos) do
        if v < 4 then
            over_playfield = over_playfield + 1
        end
    end

    if over_playfield == 4 then
        -- entire piece is above row 20
        reset_game()
    end

    -- TODO other spins
    if self.spin_coords ~= nil and self.last_action == "rotate" then
        for i,v in ipairs(self.spin_coords[self.rotation]) do
            if grid[self.x + v[1]][self.y + v[2]] ~= "empty" then
                spin_count = spin_count + 1
            end
            if spin_count >= 3 then
                spin_type = self.shape.."-spin "
            end
        end
    end

    check_line_clears()
    -- add in spin
    previous_clear = spin_type..previous_clear
    local was_spin, b = string.find(previous_clear, "spin")

    -- update combo
    if previous_clear ~= "" then
        efficiency["combo"] = efficiency["combo"] + 1
    else
        efficiency["combo"] = 0
    end

    -- update finesse
    if self.finesse then
        local x_offset = 99

        for i,v in ipairs(self.rotation_coords[self.rotation]) do
            if v[1] < x_offset then
                x_offset = v[1]
            end
        end

        x_offset = self.x + (x_offset - 1)

        if efficiency["inputs"] > self.finesse[self.rotation][x_offset] then
            efficiency["finesse"] = efficiency["finesse"] + (efficiency["inputs"] - self.finesse[self.rotation][x_offset])
        end
    end

    efficiency["inputs"] = 0

    -- update I and T piece efficiency
    if self.shape == "I" then
        efficiency["i_pieces"] = efficiency["i_pieces"] + 1
    elseif self.shape == "T" then
        efficiency["t_pieces"] = efficiency["t_pieces"] + 1
        if was_spin then
            efficiency["t_spins"] = efficiency["t_spins"] + 1
        end
    end

    -- play sound based on line clear and type
    --[[
    sound priority:
        all clear
        spin
        quad
        clear
        lock
    ]]
    if previous_clear == "perfect clear" then
        play_sound(sounds["all_clear"])
        fireworks_left = 3
        firework_delay = 0.4
    elseif was_spin then
        play_sound(sounds["spin"])
    elseif previous_clear == "quad" then
        play_sound(sounds["quad"])
    elseif previous_clear ~= "" then
        play_sound(sounds["line_clear"])
    else
        play_sound(sounds["lock"])
    end

    new_piece()
    lock_delay_current = 0
    can_hold = true
end

function Piece:harddrop()
    local cur_x = self.x
    local cur_y = self.y

    while true do
        self:move({0,1})
        if self.x == cur_x and self.y == cur_y then
            self:lock()
            break
        end
        cur_x = self.x
        cur_y = self.y
    end
end

function Piece:hold()
    if can_hold then
        if not hold_piece then
            hold_piece = self.shape
            new_piece()
        else
            temp = self.shape
            new_piece(hold_piece)
            hold_piece = temp
        end

        can_hold = false
    end
end

function Piece:keypressed(key)
    if key == options["keys"]["rotate_right"] then
        self:rotate("right")
    elseif key == options["keys"]["rotate_left"] then
        self:rotate("left")
    elseif key == options["keys"]["hard_drop"] then
        self:harddrop()
    elseif key == options["keys"]["hold"] and options["hold_enabled"] then
        self:hold()
    end
end

function Piece:draw()
    if not options["monotone"] then
        if options["colors"][self.shape] then
            love.graphics.setColor(options["colors"][self.shape])
        else
            love.graphics.setColor(options["colors"]["garbage"])
        end
    else
        love.graphics.setColor(options["monotone_color"])
    end
    pos = self:get_coords()

    for i,v in ipairs(pos) do
        if options["use_skin"] then
            love.graphics.draw(skin_image, (v[1] + 3) * 24, v[2] * 24)
        else
            love.graphics.rectangle("fill", (v[1] + 3) * 24, v[2] * 24, 24, 24)
        end
    end
end
