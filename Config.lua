local _,st = ...

local AQT = LibStub("AceAddon-3.0"):GetAddon("AQT")

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local Prism = LibStub("LibPrism-1.0")

local L = st.L

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
      outline = "OUTLINE",
      spacing = 1,
      size = 12,
      r = .9,
      g = .9,
      b = .9,
      a = 1,
      wrap = true,
   },
   hideQuestWatch = true,
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
      header = {{field = "IsCurrentZone"}, {field = "name"}},
      quest = {{field = "complete", descending = true}, {field = "level"},{field = "tag"}, {field = "title"}},
   },
   suppressErrorFrame = true,
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
	 st.gui:Redraw()
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
	 st.gui.title:UpdateText(true)
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
	 if info[#info] == "showHeaders" then
	    print("Not showing headers is currently buggy, also, this will not immediately apply just yet.")
	 elseif info[#info] == "showHeaderCount" or info[#info] == "showTags" then
	    st.gui.title:UpdateText(true)
	 elseif info[#info] == "hideQuestWatch" then
	    if val then QuestWatchFrame:Hide() else QuestWatchFrame:Show() end
	 elseif info[#info] == "suppressErrorFrame" then
	    AQT:SuppressionCheck()
	 end
      end,
   },
   font = {
      get = function(info)
	 if info.type == "color" then
	    return st.cfg.font.r, st.cfg.font.g, st.cfg.font.b, st.cfg.font.a
	 else
	    return st.cfg.font[info[#info]]
	 end
      end,
      set = function(info, v1, v2, v3, v4)
	 if info.type == "color" then
	    st.cfg.font.r = v1
	    st.cfg.font.g = v2
	    st.cfg.font.b = v3
	    st.cfg.font.a = v4
	 else
	    st.cfg.font[info[#info]] = v1
	 end
	 st.gui:Redraw() -- only needed for some settings, return to this
--	 st.gui.title:UpdateText(true)
      end,
   },
   layout = {
      get = function(info)
	 return st.cfg[info[#info]]
      end,
      set = function(info, val)
	 st.cfg[info[#info]] = val
	 st.gui:Redraw()
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
	 name = L.General,
	 type = "group",
	 order = 0,
	 args = {
	    uncategorized = {
	       type = "group",
	       name = L.Uncategorized,
	       order = 0,
	       inline = true,
	       args = {
		  showHeaders = {
		     type = "toggle",
		     name = L["Show Headers"],
		     order = 0,
		     disabled = true, -- Doesn't work properly yet.
		  },
		  showHeaderCount = {
		     type = "toggle",
		     name = L["Show Header Count"],
		     order = 1,
		  },
		  trackAll = {
		     type = "toggle",
		     name = L["Track All Quests"] .. " (recommended for now, no way of manually tracking things yet)",
		     width = "full",
		     order = 2,
		     disabled = true, --disabled until I've create my own questlog
		  },
		  showTags = {
		     type = "toggle",
		     name = L["Show Quest Tags"],
		     order = 3,
		  },
		  hideQuestWatch = {
		     type = "toggle",
		     name = L["Hide Blizzard QuestWatchFrame"],
		     order = 4,
		  },
		  indent = {
		     type = "range",
		     name = L.Indentation,
		     order = 5,
		     min = 0,
		     max = 5,
		     step = .1,
		     disabled = true, -- lacks proper update handling at the moment
		  },
		  suppressErrorFrame = {
		     type = "toggle",
		     name = L["Suppress Blizzard Quest Updates"],
		     order = 6,
		  },
	       },
	    },
	    sound = {
	       name = L.Sound,
	       type = "group",
	       order = 1,
	       inline = true,
	       args = {
		  playObjectiveSound = {
		     type = "toggle",
		     name = L["Play Objective Completion Sound"],
		     order = 0,
		  },
		  useFactionObjectiveSound = {
		     type = "toggle",
		     name = L["Use Faction Sound"],
		     order = 1,
		     disabled = function(info) return not st.cfg.playObjectiveSound end,
		  },
		  objectiveSoundName = {
		     type = "select",
		     name = L.Sound,
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
		     name = L["Play Quest Completion Sound"],
		     order = 4,
		  },
		  useFactionCompletionSound = {
		     type = "toggle",
		     name = L["Use Faction Sound"],
		     order = 5,
		     disabled = function(info) return not st.cfg.playCompletionSound end,
		  },
		  completionSoundName = {
		     type = "select",
		     name = L.Sound,
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
	 name = L.Layout,
	 type = "group",
	 order = 1,
	 get = CFGHandler.layout.get,
	 set = CFGHandler.layout.set,
	 args = {
	    anchorFrom = {
	       name = L["Tracker Anchor"],
	       order = 0,
	       type = "select",
	       values = {
		  BOTTOM = L.Bottom,
		  BOTTOMLEFT = L["Bottom Left"],
		  BOTTOMRIGHT = L["Bottom Right"],
		  CENTER = L.Center,
		  LEFT = L.Left,
		  RIGHT = L.Right,
		  TOP = L.Top,
		  TOPLEFT = L["Top Left"],
		  TOPRIGHT = L["Top Right"],
	       },
	    },
	    anchorTo = {
	       name = L["UIParent Anchor"],
	       order = 1,
	       type = "select",
	       values = {
		  BOTTOM = L.Bottom,
		  BOTTOMLEFT = L["Bottom Left"],
		  BOTTOMRIGHT = L["Bottom Right"],
		  CENTER = L.Center,
		  LEFT = L.Left,
		  RIGHT = L.Right,
		  TOP = L.Top,
		  TOPLEFT = L["Top Left"],
		  TOPRIGHT = L["Top Right"],
	       },
	    },
	    posX = {
	       name = L["X Offset"],
	       type = "range",
	       min = -4000,
	       max = 4000,
	       step = 1,
	       order = 2,
	    },
	    posY = {
	       name = L["Y Offset"],
	       type = "range",
	       min = -2200,
	       max = 2200,
	       step = 1,
	       order = 3,
	    },
	    minWidth = {
	       name = L["Minimum Width"],
	       type = "range",
	       min = 50,
	       max = 1000,
	       step = .5,
	       validate = function(info, val) if st.cfg.maxWidth > val then return "Minimum width cannot exceed maximum." end end,
	       order = 4,
	    },
	    maxWidth = {
	       name = L["Maximum Width"],
	       type = "range",
	       min = 50,
	       max = 1000,
	       step = .5,
	       validate = function(info, val) if st.cfg.minWidth < val then return "Maximum width cannot be lower than minimum." end end,
	       order = 5,
	    },
	    maxHeight = {
	       name = L["Maximum Height"],
	       type = "range",
	       min = 50,
	       max = 2000,
	       step = 1,
	       order = 6,
	    },
	    padding = {
	       name = L.Padding,
	       type = "range",
	       min = 0,
	       max = 50,
	       step = 1,
	       order = 7,
	    },
	 },
      },
      style = {
	 name = L.Style,
	 type = "group",
	 order = 2,
	 childGroups = "tab",
	 args = {
	    font = {
	       name = L.Font,
	       type = "group",
	       order = 0,
	       get = CFGHandler.font.get,
	       set = CFGHandler.font.set,
	       args = {
		  name = {
		     name = L.Font,
		     type = "select",
		     order = 0,
		     values = AceGUIWidgetLSMlists.font,
		     dialogControl = "LSM30_Font",
		     width = "double",
		  },
		  color = {
		     type = "color",
		     name = L["Font Color"],
		     order = 1,
		  },
		  outline = {
		     type = "select",
		     name = L.Outline,
		     order = 2,
		     values = {[""] = "None",OUTLINE = "Thin Outline", THICKOUTLINE = "Thick Outline"},
		  },
		  size = {
		     name = L.Size,
		     type = "range",
		     min = 4,
		     max = 32,
		     step = 1,
		     order = 3,
		  },
		  spacing = {
		     name = L.Spacing,
		     type = "range",
		     min = 0,
		     max = 120,
		     step = 1,
		     order = 4,
		     disabled = true,
		  },
		  wrap = {
		     name = L["Wrap Long Lines"],
		     type = "toggle",
		     order = 5,
		     disabled = true,
		  },
	       },
	    },
	    backdrop = {
	       name = L.Backdrop,
	       type = "group",
	       order = 1,
	       get = CFGHandler.backdrop.get,
	       set = CFGHandler.backdrop.set,
	       args = {
		  background = {
		     name = L["Background Texture"],
		     type = "select",
		     order = 0,
		     values = AceGUIWidgetLSMlists.background,
		     dialogControl = "LSM30_Background",
		     width = "double",
		  },
		  backgroundColor = {
		     name = L["Background Color"],
		     type = "color",
		     order = 1,
		     hasAlpha = true,
		  },
		  tile = {
		     name = L.Tile,
		     order = 2,
		     type = "toggle",
		  },
		  tileSize = {
		     name = L["Tile Size"],
		     order = 3,
		     type = "range",
		     min = 0,
		     max = 64,
		     step = .5,
		  },
		  border = {
		     name = L["Border Texture"],
		     type = "select",
		     order = 4,
		     values = AceGUIWidgetLSMlists.border,
		     dialogControl = "LSM30_Border",
		     width = "double",
		  },
		  borderColor = {
		     name = L["Border Color"],
		     type = "color",
		     order = 5,
		     hasAlpha = true,
		  },
		  edgeSize = {
		     name = L["Border Size"],
		     order = 6,
		     type = "range",
		     min = 1,
		     max = 64,
		     step = .5,
		  },
		  insets = {
		     name = L.Insets,
		     order = 7,
		     type = "range",
		     min = 0,
		     max = 32,
		     step = .5,
		  },
	       },
	    },
	    coloring = {
	       name = L.Coloring,
	       type = "group",
	       order = 2,
	       set = CFGHandler.coloring.set,
	       args = {
		  useDifficultyColor = {
		     name = L["Quest Difficulty Coloring"],
		     type = "toggle",
		     order = 0,
		     width = double,
		  },
		  useProgressColor = {
		     name = L["Progress-based Objective Coloring"],
		     type = "toggle",
		     order = 1,
		     width = double,
		  },
		  progressColor = {
		     name = L["Progress Color"],
		     type = "group",
		     inline = true,
		     order = 2,
		     disabled = function() return not st.cfg.useProgressColor end,
		     args = {
			progressColorMin = {
			   name = L.Incomplete,
			   type = "color",
			   hasAlpha = false,
			   order = 0,
			},
			progressColorMax = {
			   name = L.Complete,
			   type = "color",
			   hasAlpha = false,
			   order = 1,
			},
			useHSVGradient = {
			   name = L["Use HSV Gradient"],
			   type = "toggle",
			   order = 2,
			},
			progressionSample = {
			   name = function()
			      local output = L.Sample .. ": "
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
