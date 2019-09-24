local _,st = ...

local AQT = LibStub("AceAddon-3.0"):GetAddon("AQT")

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local Prism = LibStub("LibPrism-1.0")

local defaults = {
   anchorFrom = "TOPRIGHT",
   anchorTo = "TOPRIGHT",
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
      tile = false,
      tileSize = 0,
      edgeSize = 12,
      insets = 3,
   },
   completionSoundName = "Peon: Work Complete",
   font = {
      name = "Friz Quadrata TT",
      outline = OUTLINE,
      spacing = 1,
      size = 12,
      r = 1,
      g = 1,
      b = 1,
      a = 1,
   },
   maxHeight = 650,
   minWidth = 100,
   maxWidth = 250,
   objectiveSoundName = "Peon: Ready to Work",
   padding = 10,
   playCompletionSound = true,
   playObjectiveSound = true,
   posX = -5,
   posY = -200,
   progressColorMin = {
      r = 1,
      g = 0,
      b = 0,
   },
   progressColorMax = {
      r = 0,
      g = 1,
      b = 0,
   },
   showHeaderCount = true,
   showHeaders = true,
   showTags = true,
   sortFields = {
      header = {},
      quest = {},
   },
   trackAll = true,
   useDifficultyColor = true,
   useFactionCompletionSound = true,
   useFactionObjectiveSound = true,
   useProgressColor = true,
   useHSVGradient = true,
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
   backdrop = {
      get = function(info)
	 if info.type == "color" then
	    local key = info[#info]
	    key = key:sub(1, key:find("Color")-1)
	    return st.cfg.backdrop[key].r, st.cfg.backdrop[key].g, st.cfg.backdrop[key].b, st.cfg.backdrop[key].a
	 else
	    return type(st.cfg.backdrop[info[#info]]) == "table"  and st.cfg.backdrop[info[#info]].name or st.cfg.backdrop[info[#info]]
	 end
      end,
      set = function(info, v1, v2, v3, v4)
	 if info.type == "color" then
	    local key = info[#info]
	    key = key:sub(1, key:find("Color")-1)
	    st.cfg.backdrop[key].r = v1
	    st.cfg.backdrop[key].g = v2
	    st.cfg.backdrop[key].b = v3
	    st.cfg.backdrop[key].a = v4
	 else
	    if type(st.cfg.backdrop[info[#info]]) == "table" then
	       st.cfg.backdrop[info[#info]].name = v1
	    else
	       st.cfg.backdrop[info[#info]] = v1
	    end
	 end
	 st.gui:Redraw(false)
      end,
   },
   coloring = {
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
   default = {
      get = function(info)
	 if info.type == "color" then
	    return st.cfg[info[#info]].r, st.cfg[info[#info]].g, st.cfg[info[#info]].b
	 else
	    return st.cfg[info[#info]]
	 end
      end,
      set = function(info, val)
	 st.cfg[info[#info]] = val
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
   layout = {
      get = function(info)
	 return st.cfg[info[#info]]
      end,
      set = function(info, val)
	 st.cfg[info[#info]] = val
	 st.gui:Redraw(false)
      end,
   },
}

local options = {
   type = "group",
   name = "AQT",
   handler = CFGHandler, -- Possibly redundant, since I'll be using direct function references.
   childGroups = "tree",
   get = CFGHandler.default.get,
   set = CFGHandler.default.set,
   args = {
      general = {
	 name = "General",
	 type = "group",
	 order = 0,
	 args = {
	    uncategorized = {
	       type = "group",
	       name = "Uncategorized",
	       order = 0,
	       inline = true,
	       args = {
		  showHeaders = {
		     type = "toggle",
		     name = "Show Headers",
		     order = 0,
		  },
		  showHeaderCount = {
		     type = "toggle",
		     name = "Show Header Count",
		     order = 1,
		  },
		  trackAll = {
		     type = "toggle",
		     name = "Track All Quests (recommended for now, no way of manually tracking things yet)",
		     width = "full",
		     order = 2,
		  },
		  showTags = {
		     type = "toggle",
		     name = "Show Quest Tags",
		     order = 3,
		  },
	       },
	    },
	    sound = {
	       name = "Sound",
	       type = "group",
	       order = 1,
	       inline = true,
	       args = {
		  playObjectiveSound = {
		     type = "toggle",
		     name = "Play Objective Completion Sound",
		     order = 0,
		  },
		  useFactionObjectiveSound = {
		     type = "toggle",
		     name = "Use Faction Sound",
		     order = 1,
		     disabled = function(info) return not st.cfg.playObjectiveSound end,
		  },
		  objectiveSoundName = {
		     type = "select",
		     name = "Sound",
		     order = 2,
		     disabled = function(info) return (not st.cfg.playObjectiveSound or not st.cfg.useFactionObjectiveSound) end,
		     values = AceGUIWidgetLSMlists.sound,
		     dialogControl = "LSM30_Sound",
		  },
		  soundBreak = {
		     type = "header",
		     order = 3,
		     name = "",
		  },
		  playCompletionSound = {
		     type = "toggle",
		     name = "Play Quest Completion Sound",
		     order = 4,
		  },
		  useFactionCompletionSound = {
		     type = "toggle",
		     name = "Use Faction Sound",
		     order = 5,
		     disabled = function(info) return not st.cfg.playCompletionSound end,
		  },
		  completionSoundName = {
		     type = "select",
		     name = "Sound",
		     order = 6,
		     disabled = function(info) return (not st.cfg.playCompletionSound or not st.cfg.useFactionCompletionSound) end,
		     values = AceGUIWidgetLSMlists.sound,
		     dialogControl = "LSM30_Sound",
		  },
	       },
	    },
	    sink = AQT:GetSinkAce3OptionsDataTable(),
	 },
      },
      layout = {
	 name = "Layout",
	 type = "group",
	 order = 1,
	 get = CFGHandler.layout.get,
	 set = CFGHandler.layout.set,
	 args = {
	    anchorFrom = {
	       name = "Tracker Anchor",
	       order = 0,
	       type = "select",
	       values = {
		  BOTTOM = "BOTTOM",
		  BOTTOMLEFT = "BOTTOMLEFT",
		  BOTTOMRIGHT = "BOTTOMRIGHT",
		  CENTER = "CENTER",
		  LEFT = "LEFT",
		  RIGHT = "RIGHT",
		  TOP = "TOP",
		  TOPLEFT = "TOPLEFT",
		  TOPRIGHT = "TOPRIGHT",
	       },
	    },
	    anchorTo = {
	       name = "UIParent Anchor",
	       order = 1,
	       type = "select",
	       values = {
		  BOTTOM = "BOTTOM",
		  BOTTOMLEFT = "BOTTOMLEFT",
		  BOTTOMRIGHT = "BOTTOMRIGHT",
		  CENTER = "CENTER",
		  LEFT = "LEFT",
		  RIGHT = "RIGHT",
		  TOP = "TOP",
		  TOPLEFT = "TOPLEFT",
		  TOPRIGHT = "TOPRIGHT",
	       },
	    },
	    posX = {
	       name = "X Offset",
	       type = "range",
	       min = -4000,
	       max = 4000,
	       step = 1,
	       order = 2,
	    },
	    posY = {
	       name = "Y Offset",
	       type = "range",
	       min = -2200,
	       max = 2200,
	       step = 1,
	       order = 3,
	    },
	    minWidth = {
	       name = "Minimum Width",
	       type = "range",
	       min = 50,
	       max = 1000,
	       step = .5,
	       validate = function(info, val) if st.cfg.maxWidth > val then return "Minimum width cannot exceed maximum." end end,
	       order = 4,
	    },
	    maxWidth = {
	       name = "Maximum Width",
	       type = "range",
	       min = 50,
	       max = 1000,
	       step = .5,
	       validate = function(info, val) if st.cfg.minWidth < val then return "Maximum width cannot be lower than minimum." end end,
	       order = 5,
	    },
	    maxHeight = {
	       name = "Maximum Height",
	       type = "range",
	       min = 50,
	       max = 2000,
	       step = 1,
	       order = 6,
	    },
	    padding = {
	       name = "Padding",
	       type = "range",
	       min = 0,
	       max = 50,
	       step = 1,
	       order = 7,
	    },
	 },
      },
      style = {
	 name = "Style",
	 type = "group",
	 order = 2,
	 childGroups = "tab",
	 args = {
	    font = {
	       name = "Font",
	       type = "group",
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
		     name = "Font Color",
		     order = 1,
		  },
		  outline = {
		     type = "select",
		     name = "Outline",
		     order = 2,
		     values = {[""] = "None",OUTLINE = "Thin Outline", THICKOUTLINE = "Thick Outline"},
		  },
		  size = {
		     name = "Size",
		     type = "range",
		     min = 4,
		     max = 32,
		     step = 1,
		     order = 3,
		  },
		  spacing = {
		     name = "Spacing",
		     type = "range",
		     min = 0,
		     max = 120,
		     step = 1,
		     order = 4,
		     disabled = true,
		  },
	       },
	    },
	    backdrop = {
	       name = "Backdrop",
	       type = "group",
	       order = 1,
	       get = CFGHandler.backdrop.get,
	       set = CFGHandler.backdrop.set,
	       args = {
		  background = {
		     name = "Background Texture",
		     type = "select",
		     order = 0,
		     values = AceGUIWidgetLSMlists.background,
		     dialogControl = "LSM30_Background",
		     width = "double",
		  },
		  backgroundColor = {
		     name = "Background Color",
		     type = "color",
		     order = 1,
		     hasAlpha = true,
		  },
		  tile = {
		     name = "Tile",
		     order = 2,
		     type = "toggle",
		  },
		  tileSize = {
		     name = "Tile Size",
		     order = 3,
		     type = "range",
		     min = 0,
		     max = 64,
		     step = .5,
		  },
		  border = {
		     name = "Border Texture",
		     type = "select",
		     order = 4,
		     values = AceGUIWidgetLSMlists.border,
		     dialogControl = "LSM30_Border",
		     width = "double",
		  },
		  borderColor = {
		     name = "Border Color",
		     type = "color",
		     order = 5,
		     hasAlpha = true,
		  },
		  edgeSize = {
		     name = "Border Size",
		     order = 6,
		     type = "range",
		     min = 1,
		     max = 64,
		     step = .5,
		  },
		  insets = {
		     name = "Insets",
		     order = 7,
		     type = "range",
		     min = 0,
		     max = 32,
		     step = .5,
		  },
	       },
	    },
	    coloring = {
	       name = "Coloring",
	       type = "group",
	       order = 2,
	       set = CFGHandler.coloring.set,
	       args = {
		  useDifficultyColor = {
		     name = "Quest Difficulty Coloring",
		     type = "toggle",
		     order = 0,
		     width = double,
		  },
		  useProgressColor = {
		     name = "Progress-based Objective Coloring",
		     type = "toggle",
		     order = 1,
		     width = double,
		  },
		  progressColor = {
		     name = "Progress Color",
		     type = "group",
		     inline = true,
		     order = 2,
		     disabled = function() return not st.cfg.useProgressColor end,
		     args = {
			progressColorMin = {
			   name = "Incomplete",
			   type = "color",
			   hasAlpha = false,
			   order = 0,
			},
			progressColorMax = {
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
			      if st.cfg.useProgressColor then
				 for i = 0, 10 do
				    output = output .. "|cff" .. Prism:Gradient(st.cfg.useHSVGradient and "hsv" or "rgb", st.cfg.progressColorMin.r, st.cfg.progressColorMax.r, st.cfg.progressColorMin.g, st.cfg.progressColorMax.g, st.cfg.progressColorMin.b, st.cfg.progressColorMax.b, i/10) .. tostring(i*10) .. "%|r" .. (i < 10 and " -> " or "")
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

options.args.general.args.sink.inline = true

function st.initConfig()
   if not AQTCFG or type(AQTCFG) ~= "table" then AQTCFG = {} end
--   clearDefunct(AQTCFG, defaults)
   st.db = LibStub("AceDB-3.0"):New("AQTCFG", aceDBdefaults, true) -- Use AceDB for now. Might want to write my own metatable later instead.
   st.cfg = st.db.global
   AQT:SetSinkStorage(st.cfg)
   LibStub("AceConfig-3.0"):RegisterOptionsTable("AQT", options)
   LibStub("AceConsole-3.0"):RegisterChatCommand("aqt", function() LibStub("AceConfigDialog-3.0"):Open("AQT") end)
end
