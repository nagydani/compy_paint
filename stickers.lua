-- stickers.lua

-- Sticker manifest and placeholder art (spec: Stickers).
-- Each draw renders centered at the origin into a square
-- footprint of d px using gfx primitives. Swapping in real
-- art later means carrying an image instead of draw, with
-- no change to the object model or the tool.

function drawCircleSticker(d)
  gfx.setColor(Color[Color.red])
  gfx.circle("fill", 0, 0, d * 0.42)
  gfx.setColor(Color[Color.black])
  gfx.circle("line", 0, 0, d * 0.42)
end

function drawSquareSticker(d)
  local h = d * 0.35
  gfx.setColor(Color[Color.blue + Color.bright])
  gfx.rectangle("fill", -h, -h, h * 2, h * 2)
  gfx.setColor(Color[Color.black])
  gfx.rectangle("line", -h, -h, h * 2, h * 2)
end

function starPoints()
  local pts = { }
  for i = 0, 9 do
    local r = 1
    if i % 2 == 1 then
      r = 0.4
    end
    local a = (i * math.pi / 5) - (math.pi / 2)
    pts[#pts + 1] = math.cos(a) * r
    pts[#pts + 1] = math.sin(a) * r
  end
  return pts
end

STAR_PTS = starPoints()
STAR_TRIS = love.math.triangulate(STAR_PTS)

function drawStarSticker(d)
  local s = d * 0.45
  gfx.push()
  gfx.scale(s, s)
  gfx.setColor(Color[Color.yellow + Color.bright])
  for i = 1, #STAR_TRIS do
    gfx.polygon("fill", STAR_TRIS[i])
  end
  gfx.setColor(Color[Color.black])
  gfx.setLineWidth(1 / s)
  gfx.polygon("line", STAR_PTS)
  gfx.setLineWidth(1)
  gfx.pop()
end

function drawTreeSticker(d)
  gfx.setColor(Color[Color.red])
  gfx.rectangle("fill", -d * 0.06, d * 0.15, d * 0.12, d * 0.3)
  gfx.setColor(Color[Color.green])
  gfx.polygon(
    "fill",
    0,
    -d * 0.45,
    -d * 0.35,
    d * 0.2,
    d * 0.35,
    d * 0.2
  )
end

function drawHouseSticker(d)
  local h = d * 0.3
  local w = d * 0.4
  local r = d * 0.05
  gfx.setColor(Color[Color.yellow])
  gfx.rectangle("fill", -h, -r, h * 2, d * 0.4)
  gfx.setColor(Color[Color.red])
  gfx.polygon("fill", -w, -r, 0, -d * 0.45, w, -r)
  gfx.setColor(Color[Color.black])
  gfx.rectangle("fill", -d * 0.07, d * 0.13, d * 0.14, d * 0.22)
end

function drawSunSticker(d)
  gfx.setColor(Color[Color.yellow + Color.bright])
  gfx.circle("fill", 0, 0, d * 0.25)
  for i = 0, 7 do
    local a = i * math.pi / 4
    gfx.line(
      math.cos(a) * d * 0.32,
      math.sin(a) * d * 0.32,
      math.cos(a) * d * 0.45,
      math.sin(a) * d * 0.45
    )
  end
end

function drawFlowerSticker(d)
  gfx.setColor(Color[Color.green])
  gfx.line(0, d * 0.1, 0, d * 0.45)
  gfx.setColor(Color[Color.magenta + Color.bright])
  for i = 0, 4 do
    local a = (i * 2 * math.pi / 5) - (math.pi / 2)
    local px = math.cos(a) * d * 0.18
    local py = math.sin(a) * d * 0.18 - d * 0.08
    gfx.circle("fill", px, py, d * 0.13)
  end
  gfx.setColor(Color[Color.yellow + Color.bright])
  gfx.circle("fill", 0, -d * 0.08, d * 0.1)
end

function drawCloudSticker(d)
  gfx.setColor(Color[BRIGHT_WHITE])
  gfx.circle("fill", -d * 0.18, d * 0.05, d * 0.16)
  gfx.circle("fill", 0, -d * 0.08, d * 0.2)
  gfx.circle("fill", d * 0.18, d * 0.05, d * 0.16)
  gfx.rectangle("fill", -d * 0.18, 0, d * 0.36, d * 0.2)
  gfx.setColor(Color[Color.cyan])
  gfx.circle("line", -d * 0.18, d * 0.05, d * 0.16)
  gfx.circle("line", 0, -d * 0.08, d * 0.2)
  gfx.circle("line", d * 0.18, d * 0.05, d * 0.16)
end

STICKER_SIZE = 96

STICKERS = {
  { id = "circle", draw = drawCircleSticker },
  { id = "square", draw = drawSquareSticker },
  { id = "star", draw = drawStarSticker },
  { id = "tree", draw = drawTreeSticker },
  { id = "house", draw = drawHouseSticker },
  { id = "sun", draw = drawSunSticker },
  { id = "flower", draw = drawFlowerSticker },
  { id = "cloud", draw = drawCloudSticker }
}

-- id -> index, built once so lookups are direct, not a scan

STICKER_INDEX = { }
for i = 1, #STICKERS do
  STICKER_INDEX[STICKERS[i].id] = i
end
