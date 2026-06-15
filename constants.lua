-- constants.lua

-- Configuration and derived layout constants
-- (spec: Data / configuration format, Layout)

-- screen

WIDTH, HEIGHT = gfx.getDimensions()

-- control column: spends the wide axis (spec: Layout)

COL_FRAC = 0.2
COL_W = WIDTH * COL_FRAC
MARGIN = COL_W / 32
M_2 = MARGIN * 2

-- vertical budget: sized from screen height only

TOOLS_FRAC = 0.15
CTRL_FRAC = 0.5
TOOLS_H = HEIGHT * TOOLS_FRAC
CTRL_Y = TOOLS_H
CTRL_H = HEIGHT * CTRL_FRAC
WB_Y = CTRL_Y + CTRL_H

-- bottom action row (the clear button, paint modes only)

ACTION_FRAC = 0.08
ACTION_H = HEIGHT * ACTION_FRAC
ACTION_Y = HEIGHT - ACTION_H
WEIGHT_H = HEIGHT - WB_Y - ACTION_H

-- tools: brush, eraser, sticker (spec)

N_T = 3
SLOT_W = COL_W / N_T
BRUSH = 1
ERASER = 2
STICKER = 3
ICON_D = math.min(SLOT_W - M_2, TOOLS_H - M_2)
ICON_BASE = 100
ICON_ANGLE = math.pi / 4

-- optical centering of the icon art

ART_DX = -ICON_D / 10
ART_DY = ICON_D / 5
ERASER_SCALE = 1.5

-- palette: 8 rows, base beside bright (spec)

PAL_COLS = 8
GRID_COLS = 2
SWATCH_W = COL_W / GRID_COLS
SWATCH_FRAC = 0.2
SEL_H = CTRL_H * SWATCH_FRAC
GRID_H = CTRL_H - SEL_H
ROW_H = GRID_H / PAL_COLS
SEL_Y = CTRL_Y + GRID_H

-- the highlight color used throughout the chrome

BRIGHT_WHITE = Color.white + Color.bright

-- line weight: the default is the third step (spec)

WEIGHTS = {
  1,
  2,
  4,
  5,
  6,
  9,
  11,
  13
}
DEFAULT_WEIGHT = 3

-- weight bar footprint inside the column

WBAR_X = COL_W / 3
WBAR_W = COL_W / 2

-- canvas area: full screen height right of the column

CAN_W = WIDTH - COL_W

-- stroke interpolation

STEP_FRAC = 0.5

-- the pointer is kept one pixel off the screen edges:
-- the Android UI pops up on edge contact (measured)

EDGE_PAD = 1

-- raw mouse deltas have no OS acceleration in relative
-- mode, so they are scaled to a comfortable feel

POINTER_SPEED = 2.5

-- sticker crosshair arm length

CROSS_D = 12

-- named sticker indices (order matches the STICKERS list)

STK_STAR = 3
STK_TREE = 4
STK_HOUSE = 5
STK_SUN = 6

-- sticker scaling by mouse wheel: step per notch and bounds

SCALE_STEP = 0.1
SCALE_MIN = 0.3
SCALE_MAX = 3

-- goose marker color; the marker shape is built in main

GOOSE = {
  0.303,
  0.431,
  0.431
}

COLORKEYS = {
  ["1"] = 0,
  ["2"] = 1,
  ["3"] = 2,
  ["4"] = 3,
  ["5"] = 4,
  ["6"] = 5,
  ["7"] = 6,
  ["8"] = 7
}

-- preset menu layout

MENU_W = WIDTH / 2
MENU_H = HEIGHT / 4
MENU_GAP = HEIGHT / 12
MENU_X = (WIDTH - MENU_W) / 2
MENU_Y = ((HEIGHT - (2 * MENU_H)) - MENU_GAP) / 2
MENU_ICON = MENU_H * 0.6

-- seed stickers for notch -1: tree left third, house
-- center, sun right third upper quarter (the spec leaves
-- the exact coordinates open). canvas-relative coords

SEED_TREE = {
  index = STK_TREE,
  x = CAN_W / 6,
  y = HEIGHT / 2
}
SEED_HOUSE = {
  index = STK_HOUSE,
  x = CAN_W / 2,
  y = HEIGHT / 2
}
SEED_SUN = {
  index = STK_SUN,
  x = CAN_W * 5 / 6,
  y = HEIGHT * 3 / 16
}
SEEDS = {
  SEED_TREE,
  SEED_HOUSE,
  SEED_SUN
}

-- presets: which tools each interface exposes (spec).
-- a preset with a single tool shows no tool strip and the
-- sticker tray takes the whole column

PRESETS = {
  {
    id = "sticker board",
    tools = { STICKER }
  },
  {
    id = "full interface",
    tools = {
      BRUSH,
      ERASER,
      STICKER
    }
  }
}
