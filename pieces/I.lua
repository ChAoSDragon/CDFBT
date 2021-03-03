--[[
I rotations
I piece needs to be in a 4x4 box, offset from top left
o
####

o #
  #
  #
  #

o

####

o#
 #
 #
 #

]]

local I = {
    shape = "I",
    rotation_coords = {
        {
            {0, 1},
            {1, 1},
            {2, 1},
            {3, 1}
        },
        {
            {2, 0},
            {2, 1},
            {2, 2},
            {2, 3}
        },
        {
            {0, 2},
            {1, 2},
            {2, 2},
            {3, 2}
        },
        {
            {1, 0},
            {1, 1},
            {1, 2},
            {1, 3}
        }
    },
    kick_table = {
        {
            {0, 0},
            {-2, 0},
            {1, 0},
            {-2, 1},
            {1, -2}
        },
        {
            {0, 0},
            {2, 0},
            {-1, 0},
            {2, -1},
            {-1, 2}
        },
        {
            {0, 0},
            {-1, 0},
            {2, 0},
            {-1, -2},
            {2, -1}
        },
        {
            {0, 0},
            {1, 0},
            {-2, 0},
            {1, 2},
            {-2, -1}
        }
    }
}

shapes["I"] = I
