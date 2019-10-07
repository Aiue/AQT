local _,st = ...

local AQT = LibStub("AceAddon-3.0"):GetAddon("AQT")

local ACD = LibStub("AceConfigDialog-3.0")
local Prism = LibStub("LibPrism-1.0")

local L = st.L
local tinsert,tremove,tsort = table.insert,table.remove,table.sort

local sortcfg = {}

local defaultSortFields = { -- Because AceDB will kind of screw things up for us otherwise.
   Header = {{field = "IsCurrentZone"}, {field = "name"}},
   Objective = {{field = "index"}},
   Quest = {{field = "complete", descending = true}, {field = "level"},{field = "tag"}, {field = "title"}},
}

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
   barBackdrop = {
      background = {
	 name = "Blizzard Tooltip",
	 r = 1,
	 g = 1,
	 b = 1,
	 a = 1,
      },
      border = {
	 name = "Blizzard Tooltip",
	 r = .4,
	 g = .4,
	 b = .4,
	 a = 1,
      },
      tile = false,
      tileSize = 0,
      edgeSize = 12,
      insets = 3,
   },
   barFont = {
      name = "Friz Quadrata TT",
      outline = "OUTLINE",
      spacing = 1,
      size = 12,
      r = 1,
      g = 1,
      b = 1,
      a = 1,
      wrap = false,
   },
   barTexture = "Blizzard",
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
   hideQuestTimerFrame = true,
   hideQuestWatch = true,
   indent = 0,
   LDBIcon = -1,
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
   showTimers = true,
   suppressErrorFrame = true,
   timerType = 1, -- 1 = StatusBar, 2 = FontString (uses counter). Using number instead of tristate boolean in case we want to add more later.
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
   bars = {
      backdrop = { -- Yeah, I'm just doing copypasta at this point, meaning I _really_ need to look over this. Look, now I'm even copypasting this comment.
	 get = function(info)
	    if info.type == "color" then
	       local key = info[#info]
	       key = key:sub(1, key:find("Color")-1)
	       return st.cfg.barBackdrop[key].r, st.cfg.barBackdrop[key].g, st.cfg.barBackdrop[key].b, st.cfg.barBackdrop[key].a
	    else
	       return type(st.cfg.barBackdrop[info[#info]]) == "table"  and st.cfg.barBackdrop[info[#info]].name or st.cfg.barBackdrop[info[#info]]
	    end
	 end,
	 set = function(info, v1, v2, v3, v4)
	    if info.type == "color" then
	       local key = info[#info]
	       key = key:sub(1, key:find("Color")-1)
	       st.cfg.barBackdrop[key].r = v1
	       st.cfg.barBackdrop[key].g = v2
	       st.cfg.barBackdrop[key].b = v3
	       st.cfg.barBackdrop[key].a = v4
	    else
	       if type(st.cfg.backdrop[info[#info]]) == "table" then
		  st.cfg.barBackdrop[info[#info]].name = v1
	       else
		  st.cfg.barBackdrop[info[#info]] = v1
	       end
	    end
	    st.gui:UpdateTimers()
	 end,
      },
      font = { -- Yeah, I'm just doing copypasta at this point, meaning I _really_ need to look over this.
	 get = function(info)
	    if info.type == "color" then
	       return st.cfg.barFont.r, st.cfg.barFont.g, st.cfg.barFont.b, st.cfg.barFont.a
	    else
	       return st.cfg.barFont[info[#info]]
	    end
	 end,
	 set = function(info, v1, v2, v3, v4)
	    if info.type == "color" then
	       st.cfg.barFont.r = v1
	       st.cfg.barFont.g = v2
	       st.cfg.barFont.b = v3
	       st.cfg.barFont.a = v4
	    else
	       st.cfg.barFont[info[#info]] = v1
	    end
	    st.gui:Redraw() -- only needed for some settings, return to this
	 end,
      },
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
	 elseif info[#info] == "hideQuestTimerFrame" then
	    if val then QuestTimerFrame:Hide() elseif GetQuestTimers() then QuestTimerFrame:Show() end
	 elseif info[#info] == "suppressErrorFrame" then
	    AQT:SuppressionCheck()
	 elseif info[#info] == "showTimers" or info[#info] == "timerType" or info[#info] == "barTexture" then
	    st.gui:UpdateTimers()
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
   sorting = {
      AddSortValuesOrNot = function(objType, returnastable)
	 local values = {}
	 local sfCache = {}
	 for k,v in pairs(st.types[objType].sortFields) do tinsert(sfCache, k) end
	 for k,v in ipairs(st.cfg.sortFields[objType]) do
	    for i = #sfCache, 1, -1 do
	       if v.field == sfCache[i] then tremove(sfCache, i) end
	    end
	 end
	 for k,v in ipairs(sfCache) do values[v] = st.types[objType].sortFields[v] end
	 if sortcfg.field and not st.types[objType].sortFields[sortcfg.field] then
	    sortcfg.field = nil
	    sortcfg.descending = nil
	 end
	 return returnastable and values or (#sfCache == 0)
      end,

      edit = function(info)
	 local obj = info[#info-2]
	 local index = info.options.args.sorting.args[obj].args[info[#info-1]].order
	 if info[#info] == "ascdesc" then
	    st.cfg.sortFields[obj][index].descending = not st.cfg.sortFields[obj][index].descending

	 elseif info[#info] == "moveup" or info[#info] == "movedown" then
	    local newindex = (info[#info] == "moveup" and (index - 1) or (index + 1))
	    for k,v in pairs(info.options.args.sorting.args[obj].args) do
	       if v.order == newindex then v.order = index end
	    end
	    info.options.args.sorting.args[obj].args[info[#info-1]].order = newindex
	    local sf = tremove(st.cfg.sortFields[obj], index)
	    tinsert(st.cfg.sortFields[obj], newindex, sf)

	 elseif info[#info] == "remove" then
	    info.options.args.sorting.args[obj].args[info[#info-1]] = nil
	    tremove(st.cfg.sortFields[obj], index)
	 end
	 st.gui:RecurseResort()
      end,
   
      get = function(info) -- only for new stuff
	 return sortcfg[info[#info]]
      end,
   
      set = function(info, val) -- only for new stuff
	 sortcfg[info[#info]] = val
      end,
   
      addValidate = function(info)
	 if not st.types[info[#info-2]].sortFields[info[#info-1]] then return "Unknown sort field." end
      end,
   
      addDisabled = function(info)
	 if not sortcfg.field then return true end
      end,
   },
}

-- Need to set these here, as they refer back to CFGHandler.
CFGHandler.sorting.AddHasSortValues = function(info)
   return CFGHandler.sorting.AddSortValuesOrNot(info[#info-2], false)
end

CFGHandler.sorting.AddSortValues = function(info)
   return CFGHandler.sorting.AddSortValuesOrNot(info[#info-2], true)
end
   
CFGHandler.sorting.newDisabled = function(info)
   local objType
   if info[#info-1] == "_specialAddNew" then objType = info[#info-2] else objType = info[#info-1] end
   return CFGHandler.sorting.AddSortValuesOrNot(objType, false)
end

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
	 childGroups = "tab",
	 args = {
	    general = {
	       type = "group",
	       name = L.General, -- Most of this is to be moved elsewhere eventually.
	       order = 0,
	       args = {
		  uncategorized = {
		     type = "group",
		     name = L.Uncategorized,
		     order = 0,
		     inline = true,
		     args = {
			descr = {
			   type="description",
			   name = "Sorry about the mess. Some of these are currently disabled as they are awaiting proper implementation. Further, most of these configuration options ended up here because I couldn't quite figure out where to place them. Meaning, I may well move them elsewhere eventually.",
			   order = 0,
			},
			showHeaders = {
			   type = "toggle",
			   name = L["Show Headers"],
			   order = 1,
			   disabled = true, -- Doesn't work properly yet.
			},
			showHeaderCount = {
			   type = "toggle",
			   name = L["Show Header Count"],
			   order = 2,
			},
			trackAll = {
			   type = "toggle",
			   name = L["Track All Quests"] .. " (recommended for now, no way of manually tracking things yet)",
			   width = "full",
			   order = 3,
			   disabled = true, --disabled until I've create my own questlog
			},
			showTags = {
			   type = "toggle",
			   name = L["Show Quest Tags"],
			   order = 4,
			},
			indent = {
			   type = "range",
			   name = L.Indentation,
			   order = 8,
			   min = 0,
			   max = 5,
			   step = .1,
			   disabled = true, -- lacks proper update handling at the moment
			},
		     },
		  },
		  hideDefaults = {
		     type = "group",
		     name = L["Suppress Default Interface"],
		     order = 1,
		     inline = true,
		     args = {
			hideQuestWatch = {
			   type = "toggle",
			   name = L["Hide Blizzard QuestWatchFrame"],
			   width = "double",
			   order = 5,
			},
			hideQuestTimerFrame = {
			   type = "toggle",
			   name = L["Hide Blizzard Quest Timer Frame"],
			   width = "double",
			   order = 6,
			},
			suppressErrorFrame = {
			   type = "toggle",
			   name = L["Suppress Blizzard Quest Updates"],
			   width = "double",
			   order = 7,
			},
		     },
		  },
		  timers = {
		     type = "group",
		     name = L.Timers,
		     order = 2,
		     inline = true,
		     args = {
			showTimers = {
			   type = "toggle",
			   name = L["Show Quest Timers"],
			   order = 9,
			},
			timerType = {
			   type = "select",
			   name = L["Timer Style"],
			   order = 10,
			   values = {L.Statusbar, L.Counter},
			   style = "radio",
			},
		     },
		  },
	       },
	    },
	    sound = {
	       name = L.Sound,
	       type = "group",
	       order = 1,
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
      sorting = {
	 name = L.Sorting,
	 type = "group",
	 order = 2,
	 childGroups = "tab",
	 get = CFGHandler.sorting.get,
	 set = CFGHandler.sorting.set,
	 args = {},
      },
      style = {
	 name = L.Style,
	 type = "group",
	 order = 3,
	 childGroups = "tab",
	 args = {
	    backdrop = {
	       name = L.Backdrop,
	       type = "group",
	       order = 0,
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
	    bars = {
	       name = L.Bars,
	       type = "group",
	       order = 1,
	       args = {
		  backdrop = {
		     name = L.Backdrop,
		     type = "group",
		     order = 0,
		     get = CFGHandler.bars.backdrop.get,
		     set = CFGHandler.bars.backdrop.set,
		     inline = true,
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
		  font = {
		     name = L.Font,
		     type = "group",
		     order = 1,
		     get = CFGHandler.bars.font.get,
		     set = CFGHandler.bars.font.set,
		     inline = true,
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
		  barTexture = {
		     name = L.Texture,
		     type = "select",
		     order = 2,
		     values = AceGUIWidgetLSMlists.statusbar,
		     dialogControl = "LSM30_Statusbar",
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
	    font = {
	       name = L.Font,
	       type = "group",
	       order = 3,
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
	 },
      },
   },
}

local editSortOptions = {
   ascdesc = {
      name = function(info)
	 for k,v in ipairs(st.cfg.sortFields[info[#info-2]]) do
	    if v.field == info[#info-1] then return v.descending and L.Descending or L.Ascending end
	 end
      end,
      type = "execute",
      order = 0,
   },
   moveup = {
      name = L["Move Up"],
      type = "execute",
      order = 1,
      disabled = function(info)
	 return options.args.sorting.args[info[#info-2]].args[info[#info-1]].order == 1
      end,
    },
   movedown = {
      name = L["Move Down"],
      type = "execute",
      order = 2,
      disabled = function(info)
	 return options.args.sorting.args[info[#info-2]].args[info[#info-1]].order == #st.cfg.sortFields[info[#info-2]]
      end,
   },
   remove = {
      name = L.Remove,
      type = "execute",
      order = 3,
   },
}

local addSortOptions = {
   field = {
      name = L.Field,
      type = "select",
      values = CFGHandler.sorting.AddSortValues,
      disabled = CFGHandler.sorting.AddHasSortValues,
      order = 0,
   },
   descending = {
      name = L.Descending,
      type = "toggle",
      order = 1,
   },
   add = {
      name = L.Add,
      type = "execute",
      order = 2,
      validate = CFGHandler.sorting.addValidate,
      func = CFGHandler.sorting.addExecute,
      disabled = CFGHandler.sorting.addDisabled,
   },
}

local function addSortOption(objType, sortField, index)
   options.args.sorting.args[objType].args[sortField] = {
      name = st.types[objType].sortFields[sortField],
      type = "group",
      order = index,
      args = editSortOptions,
   }
end

-- This needs to be here to be able to call addSortOption()
CFGHandler.sorting.addExecute = function(info)
   tinsert(st.cfg.sortFields[info[#info-2]], {field=sortcfg.field,descending=sortcfg.descending or nil})
   addSortOption(info[#info-2], sortcfg.field, (#st.cfg.sortFields[info[#info-2]]))
   if CFGHandler.sorting.AddSortValuesOrNot(info[#info-2], false) then ACD:SelectGroup("AQT", "sorting", info[#info-2], sortcfg.field) end
   sortcfg.field = nil
   sortcfg.descending = nil
   st.gui:RecurseResort()
end

addSortOptions.add.func = CFGHandler.sorting.addExecute

local function buildSortOptions()
   for k,v in pairs(st.types) do
      if v.sortFields then
	 options.args.sorting.args[v.name] = {
	    name = v.name,
	    type = "group",
	    childGroups = "tree",
	    func = CFGHandler.sorting.edit,
	    args = {
	       _specialAddNew = { -- Hopefully I (or some future someone else?) shouldn't decide THIS should be a sortable field. If so, just reject it as a sortable field, pfft.
		  name = L["Add new..."],
		  type = "group",
		  order = 500, -- If we're using even close to this many sortfields, we got issues, man.
		  args = addSortOptions,
		  hidden = CFGHandler.sorting.newDisabled,
	       },
	    },
	 }

	 for a,b in ipairs(st.cfg.sortFields[v.name]) do addSortOption(v.name, b.field, a) end
      end
   end
end

--[[
local function buildSortOptions()
   local typeList = {} -- To get it sortable.
   for k,v in pairs(st.types) do tinsert(typeList, k) end
   tsort(typeList, function(a,b) return tostring(a)<tostring(b) end)

   for i,v in ipairs(typeList) do
      if st.types[v].sortConfigurable then
	 options.args.sorting.args[v] = {
	    name = L[v],
	    type = "group",
	    order = i,
	    args = {},
	 }

	 options.args.sorting.args[v].args.tmp = {
	    name = "While waiting on proper implementation of sorting configuration, I give the option of at least showing the current configuration settings.",
	    type = "description",
	    order = 0,
	 }

	 for k,f in ipairs(st.cfg.sortFields[v]) do
	    if not st.types[v].sortFields[f.field] then print(v .. " does not have " .. f.field .. " as a sortable field!") end
	    options.args.sorting.args[v].args["moo"..tostring(k)] = {
	       name = "Prio #" .. tostring(k) .. ": " .. tostring(st.types[v].sortFields[f.field]) .. " " .. (f.descending and "(descending)" or "(ascending)"),
	       type = "description",
	       order = k,
	    }
	 end
      end
   end
end
]]--

function st.initConfig()
   if not AQTCFG or type(AQTCFG) ~= "table" then AQTCFG = {} end
   st.db = LibStub("AceDB-3.0"):New("AQTCFG", aceDBdefaults, true) -- Use AceDB for now. Might want to write my own metatable later instead.
   st.cfg = st.db.global
   AQT:SetSinkStorage(st.cfg)
   LibStub("AceConfig-3.0"):RegisterOptionsTable("AQT", options)
   LibStub("AceConsole-3.0"):RegisterChatCommand("aqt", function() AQT:ToggleConfig() end)

   -- Since I made a release with broken configuration, try to fix any sortField configuration corruption.
   if st.cfg.sortFields then
      for oType,sortTable in pairs(st.cfg.sortFields) do
	 local sfCache = {} -- Cache all indexes.
	 for k,v in pairs(sortTable) do -- Using pairs rather than ipairs in case we have gaps.
	    tinsert(sfCache, k)
	 end
	 tsort(sfCache, function(a,b) return a<b end)
	 if #sfCache ~= sfCache[#sfCache] then
	    st.cfg.sortFields[oType] = nil -- We have a gap, consider the entire table corrupt.
	 else
	    sfCache = {} -- This time, cache anything that we want to remove from the table.
	    for k,v in ipairs(sortTable) do -- We can assume there is no gap.
	       if type(v) ~= "table" then tinsert(sfCache, k) end
	    end
	    for i = #sfCache, 1, -1 do
	       tremove(sortTable, sfCache[i]) -- Remove any corruption. Do it backwards to preserve indices.
	    end
	    if #sfCache > 0 and #sortTable == 0 then st.cfg.sortFields[oType] = nil end -- If we end up with an empty table, remove it to allow defaults to be reset, but only if we actually caught something.
	 end
      end
   end

   if not st.cfg.sortFields then st.cfg.sortFields = defaultSortFields
   else
      for k,v in pairs(defaultSortFields) do
	 if not st.cfg.sortFields[k] then
	    st.cfg.sortFields[k] = v
	 end
      end
   end
   buildSortOptions()
end

function AQT:ToggleConfig()
   if ACD.OpenFrames["AQT"] then ACD:Close("AQT") else ACD:Open("AQT") end -- A bit silly, the library should already provide this without me having to dig through the code to find it.
end

