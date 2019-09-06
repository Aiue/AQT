local _,st = ...

local AQT = LibStub("AceAddon-3.0"):GetAddon("AQT")

st.cfg = {
   backdrop = {
      background = {
	 name = "Blizzard Tooltip",
	 r = 0,
	 g = 0,
	 b = 0,
	 a = 1,
      },
      border = {
	 name = "Blizzard Tooltip",
	 r = .4,
	 g = 0,
	 b = 1,
	 a = 1,
      },
      tile = true,
      tileSize = 0,
      edgeSize = 12,
      insets = {r = 3, l = 3, t = 3, b = 3},
   },
   font = {
      name = nil,
      spacing = 1,
      size = 12,
      r = 1,
      g = 1,
      b = 1,
      a = 1,
      shadow = {
	 r = 1,
	 g = 1,
	 b = 1,
	 a = 0,
	 x = 1,
	 y = 1,
      },
   },
   maxHeight = 650,
   minWidth = 100,
   maxWidth = 250,
   padding = 10,
   posX = -5,
   posY = -200,
}
