local _,st = ...

local AQT = LibStub("AceAddon-3.0"):GetAddon("AQT")

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local Prism = LibStub("LibPrism-1.0")

local defaults = {
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
   useDifficultyColour = true,
   useProgressColour = true,
   useHSVGradient = true,
   progressColourMin = {
      r = 1,
      g = 0,
      b = 0,
   },
   progressColourMax = {
      r = 0,
      g = 1,
      b = 0,
   },
}

-- Doing this in case we wan't to ditch AceDB later.
local aceDBdefaults = {
   global = defaults
}

local function clearDefunct(cfg, def) -- Clear any defunct config values. To be called during initialization. Currently highly experimental.
   for k,v in pairs(cfg) do
      if not def[k] then cfg[k] = nil
      elseif type(v) == "table" then
	 if type(def[k]) == "table" then clearDefunct(v, def[k])
	 else cfg[k] = nil end
      end
   end
end

local CFGHandler = {
   colouring = {
      get = function(info)
	 if info.type == "color" then
	    return st.cfg[info[#info]].r, st.cfg[info[#info]].g, st.cfg[info[#info]].b
	 else
	    return st.cfg[info[#info]]
	 end
      end,
      set = function(info, v1, v2, v3, v4)
	 if info.type == "color" then
	    st.cfg[info[#info]].r = v1
	    st.cfg[info[#info]].g = v2
	    st.cfg[info[#info]].b = v3
	 else
	    st.cfg[info[#info]] = v1
	 end
	 st.gui:RedrawColor(true)
      end,
   },
   font = {
      get = function(info)
	 return st.cfg.font[info[#info]]
      end,
      set = function(info, val)
	 st.cfg.font[info[#info]] = val
	 st.gui:Redraw(true)
      end,
   },
}

local options = {
   type = "group",
   name = "AQT",
   handler = CFGHandler, -- Possibly redundant, since I'll be using direct function references.
   childGroups = "tab",
   args = {
      general = {
	 name = "General",
	 type = "group",
	 order = 0,
	 args = {
	 },
      },
      layout = {
	 name = "Layout",
	 type = "group",
	 order = 1,
	 args = {
	 },
      },
      style = {
	 name = "Style",
	 type = "group",
	 order = 2,
	 args = {
	    font = {
	       name = "Font",
	       type = "group",
	       inline = true,
	       order = 0,
	       get = CFGHandler.font.get,
	       set = CFGHandler.font.set,
	       args = {
		  name = {
		     name = "Font",
		     type = "select",
		     order = 0,
		     values = AceGUIWidgetLSMlists.font,
		     dialogControl = "LSM30_Font",
		     width = "double",
		  },
		  color = {
		     type = "color",
		     name = "Font Colour",
		     order = 1,
		  },
		  outline = {
		     type = "select",
		     name = "Outline",
		     order = 2,
		     values = {[""] = "None",OUTLINE = "Thin Outline", THICKOUTLINE = "Thick Outline"},
		  },
	       },
	    },
	    colouring = {
	       name = "Colouring",
	       type = "group",
	       inline = true,
	       order = 1,
	       get = CFGHandler.colouring.get,
	       set = CFGHandler.colouring.set,
	       args = {
		  useDifficultyColour = {
		     name = "Quest Difficulty Colouring",
		     type = "toggle",
		     order = 0,
		     width = double,
		  },
		  useProgressColour = {
		     name = "Progress-based Objective Colouring",
		     type = "toggle",
		     order = 1,
		     width = double,
		  },
		  progressColour = {
		     name = "Progress Colour",
		     type = "group",
		     inline = true,
		     order = 2,
		     disabled = function() return not st.cfg.useProgressColour end,
		     args = {
			progressColourMin = {
			   name = "Incomplete",
			   type = "color",
			   hasAlpha = false,
			   order = 0,
			},
			progressColourMax = {
			   name = "Complete",
			   type = "color",
			   hasAlpha = false,
			   order = 1,
			},
			useHSVGradient = {
			   name = "Use HSV Gradient",
			   type = "toggle",
			   order = 2,
			},
			progressionSample = {
			   name = function()
			      local output = "Sample: "
			      if st.cfg.usedProgressColour then
				 for i = 0, 10 do
				    output = output .. "|cff" .. Prism:Gradient(st.cfg.useHSVGradient and "hsv" or "rgb", st.cfg.progressColourMin.r, st.cfg.progressColourMax.r, st.cfg.progressColourMin.g, st.cfg.progressColourMax.g, st.cfg.progressColourMin.b, st.cfg.progressColourMax.b, i/10) .. tostring(i*10) .. "%|r" .. (i < 10 and " -> " or "")
				 end
				 else output = output .. "0% -> 10% -> 20% -> 30% -> 40% -> 50% -> 60% -> 70% -> 80% -> 90% -> 100%"
			      end
			      return output
			   end,
			   type = "description",
			},
		     },
		  },
	       },
	    },
	 },
      },
   },
}

function st.initConfig()
   if not AQTCFG or type(AQTCFG) ~= "table" then AQTCFG = {} end
--   clearDefunct(AQTCFG, defaults)
   st.db = LibStub("AceDB-3.0"):New("AQTCFG", aceDBdefaults, true) -- Use AceDB for now. Might want to write my own metatable later instead.
   st.cfg = st.db.global
   LibStub("AceConfig-3.0"):RegisterOptionsTable("AQT", options)
   LibStub("AceConsole-3.0"):RegisterChatCommand("aqt", function() LibStub("AceConfigDialog-3.0"):Open("AQT") end)
end
