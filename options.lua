options = {
    keys = {
        move_left = "a",
        move_right = "d",
        soft_drop = "s",
        hard_drop = "w",
        rotate_right = "o",
        rotate_left = "j",
        hold = "i",
        pause_gravity = "p",
        restart_game = "r",
        quit_game = "q"
    },
    colors = {
        T = {1, 0, 1},
        I = {0, 1, 1},
        O = {1, 1, 0},
        S = {0, 1, 0},
        Z = {1, 0, 0},
        L = {1, 0.7, 0},
        J = {0, 0, 1},
        garbage = {.5, .5, .5},
        wall = {.3, .3, .3},
        empty = {0, 0, 0, 0}
    },
    monotone = false,
    monotone_color = {0, 1, 1},
    invisible_mode = false,
    ghost_piece = true,
    use_skin = true,
    --[[ a 24x24 greyscale image, will be colored
    with the colors above. ]]
    skin = "example skin.png",
    playfield_size = {10, 23},
    soft_drop_factor = 2,
    das = 0.05,
    arr = 0.05,
    next_pieces = 6,
    hold_enabled = true,
    draw_garbage_enabled = true,
    pause_gravity_enabled = true,
    sound_enabled = true,
    music_enabled = false,
    music = {
        currently_playing = nil,
        tracks = {}
    },
    lines_per_level = 10,
    --[[ rows per second, lock delay
    0.001 or less is 20G ]]
    level_speed_table = {
        {1, 1}
    }
}
