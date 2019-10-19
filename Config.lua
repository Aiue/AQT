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
   alpha = .9,
   anchorFrom = "TOPRIGHT",
   anchorTo = "TOPRIGHT",
   artwork = {
      anchor = "BOTTOMRIGHT",
      bottom = 1,
      left = 0,
      LSMTexture = "None",
      offsetX = 0,
      offsetY = 0,
      right = 1,
      scale = 1,
      stretching = 1,
      symmetric = 0,
      symmetricZoom = true,
      texture = nil,
      top = 0,
      useLSMtexture = nil,
      vertexColor = {r=1,g=1,b=1,a=1},
      zoom = false,
   },
   automaticCollapseExpand = false,
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
      indent = 0,
      name = "Friz Quadrata TT",
      outline = "OUTLINE",
      spacing = 1,
      size = 12,
      r = .9,
      g = .9,
      b = .9,
      a = 1,
      wrap = false,
   },
   hideCompletedObjectives = true,
   hideQuestCompletedObjectives = true,
   hideQuestTimerFrame = true,
   hideQuestWatch = true,
   highlightCurrentZoneBackground = false,
   highlightCurrentZoneBackgroundColor = {
      r = .5,
      g = .5,
      b = .5,
      a = 1,
   },
   highlightCurrentZoneText = false,
   highlightCurrentZoneTextColor = {
      r = 0,
      g = 1,
      b = 0,
      a = 1,
   },
   LDBIcon = -1,
   maxHeight = 650,
   minWidth = 100,
   maxWidth = 250,
   mouse = {
      enabled = true,
      Quest = {
	 enabled = true,
	 LeftButton = {
	    func = "ShowInQuestLog",
	 },
	 RightButton = {
	    func = "__menu__",
	 },
      },
   },
   objectivePrefix = "· ",
   objectiveProgressSoundName = "Peon: Work Work",
   objectiveSoundName = "Peon: Ready to Work",
   padding = 10,
   playCompletionSound = true,
   playObjectiveProgressSound = false,
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
   useFactionObjectiveProgressSound = true,
   useFactionObjectiveSound = true,
   useProgressColor = true,
   useHSVGradient = true,
}

-- Doing this in case we wan't to ditch AceDB later.
local aceDBdefaults = {
   global = defaults
}

-- This is a rather messy way of doing things. I may want to consider breaking these out of the table and just having them as local functions instead.
-- Regardless, it requires a rather big overhaul.
local CFGHandler = {
   artwork = {
      get = function(info)
	 if info.type == "color" then
	    return st.cfg.artwork[info[#info]].r, st.cfg.artwork[info[#info]].g, st.cfg.artwork[info[#info]].b, st.cfg.artwork[info[#info]].a
	 elseif info[#info] == "height" then
	    if st.cfg.artwork.height then return st.cfg.artwork.height else return st.gui.artwork:GetHeight() end
	 elseif info[#info] == "width" then
	    if st.cfg.artwork.width then return st.cfg.artwork.width else return st.gui.artwork:GetWidth() end
	 else
	    return st.cfg.artwork[info[#info]]
	 end
      end,
      set = function(info, v1, v2, v3, v4)
	 if info.type == "color" then
	    st.cfg.artwork[info[#info]].r = v1
	    st.cfg.artwork[info[#info]].g = v2
	    st.cfg.artwork[info[#info]].b = v3
	    st.cfg.artwork[info[#info]].a = v4
	 else
	    st.cfg.artwork[info[#info]] = v1
	 end

	 if info[#info] == "LSMTexture" then
	    if v1 == "None" then st.cfg.artwork.useLSMtexture = nil
	    else st.cfg.artwork.useLSMtexture = true end
	    st.cfg.artwork.texture = nil
	    st.cfg.artwork.height = nil
	    st.cfg.artwork.width = nil
	 elseif info[#info] == "texture" then
	    st.cfg.artwork.useLSMtexture = false
	    st.cfg.artwork.LSMTexture = "None"
	    st.cfg.artwork.height = nil
	    st.cfg.artwork.width = nil
	 elseif info[#info] == "stretching" then
	    if v1 == 2 or v1 == 3 then st.cfg.artwork.anchor = "CENTER" end
	 end

	 st.gui:Redraw()
      end,
      stretchValues = function(info)
	 if st.cfg.artwork.stretching == 1 then
	    return {
	       BOTTOM = L.Bottom,
	       BOTTOMLEFT = L["Bottom Left"],
	       BOTTOMRIGHT = L["Bottom Right"],
	       CENTER = L.Center,
	       LEFT = L.Left,
	       RIGHT = L.Right,
	       TOP = L.Top,
	       TOPLEFT = L["Top Left"],
	       TOPRIGHT = L["Top Right"],
	    }
	 elseif st.cfg.artwork.stretching == 2 then
	    return {
	       LEFT = L.Left,
	       CENTER = L.Center,
	       RIGHT = L.Right,
	    }
	 elseif st.cfg.artwork.stretching == 3 then
	    return {
	       BOTTOM = L.Bottom,
	       CENTER = L.Center,
	       TOP = L.Top,
	    }
	 else return {} end
      end,
   },
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
	    if info[#info] == "indent" then st.gui.title:RelinkChildren(true)
	    else st.gui:Redraw() end -- only needed for some settings, return to this
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
	 if info[#info] == "highlightCurrentZoneBackground" or info[#info] == "highlightCurrentZoneBackgroundColor" then st.gui:Redraw() end
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
	    AQT:ToggleHeaders()
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
	 elseif info[#info] == "LDBIcon" then AQT:UpdateLDBIcon()
	 elseif info[#info] == "automaticCollapseExpand" then AQT:ZoneChangedNewArea() -- Tiny bit hacky, but does the job.
	 elseif info[#info] == "hideCompletedObjectives" or info[#info] == "hideQuestCompletedObjectives" then AQT:QuestLogUpdate()
	 elseif info[#info] == "hideConfigButton" then st.gui:UpdateConfigButton()
	 elseif info[#info] == "alpha" then st.gui:Redraw()
	 elseif info[#info] == "unlocked" then st.gui:ToggleLock()
	 elseif info[#info] == "objectivePrefix" then st.gui.title:UpdateText(true) end
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
   mouse = {
      get = function(info)
	 if #info == 2 then
	    return st.cfg.mouse[info[#info]]
	 else
	    if not st.cfg.mouse[info[2]] or not st.cfg.mouse[info[2]][info[3]] then return "__unset__"
	    elseif info[#info] == "enabled" then
	       return st.cfg.mouse[info[2]].enabled
	    else
	       return (st.cfg.mouse[info[2]][info[3]][info[#info]] and st.cfg.mouse[info[2]][info[3]][info[#info]] or "__unset__")
	    end
	 end
      end,
      getFuncList = function(info)
	 local funcList = {__unset__ = "|cffff0000" .. L.Unset .. "|r",__menu__ = L["Show Menu"]}
	 for k,v in pairs(st.types[info[#info-2]].clickScripts) do if v.func then funcList[k] = v.desc end end
	 return funcList
      end,
      set = function(info, val)
	 if val == "__unset__" then val = nil end
	 if #info == 2 then
	    st.cfg.mouse[info[#info]] = val
	 else
	    if not st.cfg.mouse[info[2]] then st.cfg.mouse[info[2]] = {} end
	    if not st.cfg.mouse[info[2]][info[3]] then st.cfg.mouse[info[2]][info[3]] = {} end
	    if info[#info] == "enabled" then
	       st.cfg.mouse[info[2]].enabled = val
	    else
	       st.cfg.mouse[info[2]][info[3]][info[#info]] = val
	    end
	 end
	 st.gui:UpdateScripts()
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
	 if not st.types[info[#info-2]].sortFields[info[#info-1]] then return "Unknown sort field." else return true end
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

--[[
local function getResolution()
   local resolution = select(GetCurrentResolution(), GetScreenResolutions())
   local match = "^(%d+)x(%d+)$"
   local x,y = resolution:match(match)
   return x,y
end

local function getResX()
   local x,y = getResolution()
   return tonumber(x)
end

local function getResY()
   local x,y = getResolution()
   return tonumber(y)
end
]]--

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
			   type = "description",
			   name = "Sorry about the mess. Some of these are currently disabled as they are awaiting proper implementation. Further, most of these configuration options ended up here because I couldn't quite figure out where to place them. Meaning, I may well move them elsewhere eventually.",
			   order = 0,
			},
			unlocked = {
			   type = "toggle",
			   name = L["Unlock Tracker"],
			   order = 1,
			},
			LDBIcon = {
			   type = "select",
			   name = L["LibDataBroker Icon"],
			   values = {}, -- Fill these later.
			   order = 3,
			},
			hideConfigButton = {
			   type = "toggle",
			   name = L["Hide Cogwheel"],
			   order = 4,
			},
		     },
		  },
		  headers = {
		     type = "group",
		     name = L.Headers,
		     inline = true,
		     order = 1,
		     args = {
			showHeaders = {
			   type = "toggle",
			   name = L["Show Headers"],
			   order = 1,
--			   disabled = true, -- Still broken, and I need to push a release that should fix some issues. Can't work on this while having that hanging over me.
			},
			showHeaderCount = {
			   type = "toggle",
			   name = L["Show Header Count"],
			   order = 2,
			},
			automaticCollapseExpand = {
			   type = "toggle",
			   name = L["Automated Collapse/Expand"],
			   desc = L["Automatically collapse/expand headers to match your current zone."],
			   order = 3,
			},
			expandHeaders = {
			   type = "execute",
			   name = L["Expand All Headers"], -- Except the main title one.
			   func = AQT.ExpandHeaders,
			},
		     },
		  },
		  hideDefaults = {
		     type = "group",
		     name = L["Suppress Default Interface"],
		     order = 2,
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
		     },
		  },
		  timers = {
		     type = "group",
		     name = L.Timers,
		     order = 3,
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
	    output = {
	       type = "group",
	       name = L.Output,
	       order = 1,
	       args = {
		  suppressErrorFrame = {
		     type = "toggle",
		     name = L["Suppress Blizzard Quest Updates"],
		     width = "double",
		     order = 0,
		  },
		  sink = AQT:GetSinkAce3OptionsDataTable(),
	       },
	    },
	    quests = {
	       type = "group",
	       name = L.Quests,
	       order = 2,
	       args = {
		  tracking = {
		     type = "group",
		     inline = true,
		     name = L.Tracking,
		     order = 0,
		     args = {
			trackAll = {
			   type = "toggle",
			   name = L["Track All Quests"] .. " (recommended for now, no way of manually tracking things yet)",
			   width = "full",
			   order = 3,
			   disabled = true, --disabled until I've create my own questlog .. or at least hooked into the default one as an intermediary measure
			},
		     },
		  },
		  showTags = {
		     type = "toggle",
		     name = L["Show Quest Tags"],
		     order = 1,
		  },
		  hideCompletedObjectives = {
		     type = "toggle",
		     name = L["Hide Completed Objectives"],
		     order = 2,
		  },
		  hideQuestCompletedObjectives = {
		     type = "toggle",
		     name = L["Hide Objectives for Completed Quests"],
		     order = 3,
		  },
		  apology = {
		     type = "description",
		     name = "Yeah, I know, this section is rather empty right now. So why move stuff here?\nWell. I'm planning to fill it with more stuff soon. :)",
		     order = 50,
		  },
	       },
	    },
	    sound = {
	       name = L.Sound,
	       type = "group",
	       order = 3,
	       args = {
		  quest = {
		     name = L.Quest,
		     type = "group",
		     order = 0,
		     inline = true,
		     args = {
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
		  objective = {
		     name = L["Objective Completion"],
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
		     },
		  },
		  objectiveProgress = {
		     name = L["Objective Progress"],
		     type = "group",
		     order = 2,
		     inline = true,
		     args = {
			playObjectiveProgressSound = {
			   type = "toggle",
			   name = L["Play Objective Progress Sound"],
			   order = 0,
			},
			useFactionObjectiveProgressSound = {
			   type = "toggle",
			   name = L["Use Faction Sound"],
			   order = 1,
			   disabled = function(info) return not st.cfg.playObjectiveProgressSound end,
			},
			objectiveProgressSoundName = {
			   type = "select",
			   name = L.Sound,
			   order = 2,
			   disabled = function(info) return (not st.cfg.playObjectiveProgressSound or not st.cfg.useFactionObjectiveProgressSound) end,
			   values = AceGUIWidgetLSMlists.sound,
			   dialogControl = "LSM30_Sound",
			},
		     },
		  },
	       },
	    },
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
	       --min = -getResX(),
	       --max = getResX(),
	       min = -2000,
	       max = 2000,
	       step = 1,
	       order = 2,
	    },
	    posY = {
	       name = L["Y Offset"],
	       type = "range",
	       --min = -getResY(),
	       --max = getResY(),
	       min = -2000,
	       max = 2000,
	       step = 1,
	       order = 3,
	    },
	    minWidth = {
	       name = L["Minimum Width"],
	       type = "range",
	       min = 50,
	       max = 1000,
	       step = .5,
	       validate = function(info, val) if st.cfg.maxWidth < val then return "Minimum width cannot exceed maximum." else return true end end,
	       order = 4,
	       disabled = true,
	    },
	    maxWidth = {
	       name = L["Maximum Width"],
	       desc = "...current a fixed width, variable width coming soon.",
	       type = "range",
	       min = 50,
	       max = 1000,
	       step = .5,
	       validate = function(info, val) if st.cfg.minWidth > val then return "Maximum width cannot be lower than minimum." else return true end end,
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
      mouse = {
	 name = L["Mouse Interaction"],
	 type = "group",
	 order = 2,
	 childGroups = "tab",
	 get = CFGHandler.mouse.get,
	 set = CFGHandler.mouse.set,
	 args = {
	    enabled = {
	       name = L["Enable Mouse"],
	       type = "toggle",
	       order = 0,
	    },
	 },
      },
      sorting = {
	 name = L.Sorting,
	 type = "group",
	 order = 3,
	 childGroups = "tab",
	 get = CFGHandler.sorting.get,
	 set = CFGHandler.sorting.set,
	 args = {},
      },
      style = {
	 name = L.Style,
	 type = "group",
	 order = 4,
	 childGroups = "tab",
	 args = {
	    general = {
	       type = "group",
	       name = L.General,
	       order = 0,
	       args = {
		  alpha = {
		     name = L.Alpha,
		     type = "range",
		     min = 0,
		     max = 1,
		     isPercent = true,
		     order = 2,
		  },
		  objectivePrefix = {
		     name = L["Objective Prefix"],
		     type = "input",
		     order = 1,
		  },
	       },
	    },
	    background ={
	       name = L.Background,
	       type = "group",
	       order = 1,
	       args = {
		  backdrop = {
		     name = L.Backdrop,
		     type = "group",
		     order = 1,
		     get = CFGHandler.backdrop.get,
		     set = CFGHandler.backdrop.set,
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
		  art = {
		     name = L["Artwork Texture"],
		     type = "group",
		     inline = true,
		     get = CFGHandler.artwork.get,
		     set = CFGHandler.artwork.set,
		     args = {
			LSMTexture = {
			   type = "select",
			   name = L.Texture,
			   values = AceGUIWidgetLSMlists.background,
			   dialogControl = "LSM30_Background",
			   width = "double",
			   order = 0,
			},
			texture = {
			   type = "input",
			   name = L["Other Texture (Path or ID)"],
			   width = "double",
			   order = 1,
			},
			vertexColor = {
			   name = L["Vertex Color"],
			   type = "color",
			   hasAlpha = true,
			   order = 2,
			},
			zoom = {
			   name = L.Zoom,
			   type = "group",
			   inline = true,
			   order = 3,
			   get = CFGHandler.artwork.zoomget,
			   set = CFGHandler.artwork.zoomset,
			   args = {
			      zoom = {
				 name = L.Zoom,
				 type = "toggle",
				 order = 0,
			      },
			      symmetricZoom = {
				 name = L["Symmetric Zoom"],
				 type = "toggle",
				 order = 1,
				 hidden = function(info) return not st.cfg.artwork.zoom end,
			      },
			      zoomRanges = {
				 name = "",
				 type = "group",
				 inline = true,
				 order = 2,
				 hidden = function(info) return not st.cfg.artwork.zoom end,
				 args = {
				    symmetric = {
				       name = L.Zoom,
				       type = "range",
				       min = 0,
				       max = 1,
				       isPercent = true,
				       order = 0,
				       hidden = function(info) 
					  if st.cfg.artwork.symmetricZoom then return false else return true end
				       end,
				    },
				    left = {
				       name = L.Left,
				       type = "range",
				       min = 0,
				       max = 1,
				       isPercent = true,
				       order = 0,
				       hidden = function(info)
					  if st.cfg.artwork.symmetricZoom then return true else return false end
				       end,
				    },
				    right = {
				       name = L.Right,
				       type = "range",
				       min = 0,
				       max = 1,
				       isPercent = true,
				       order = 1,
				       hidden = function(info)
					  if st.cfg.artwork.symmetricZoom then return true else return false end
				       end,
				    },
				    top = {
				       name = L.Top,
				       type = "range",
				       min = 0,
				       max = 1,
				       isPercent = true,
				       order = 2,
				       hidden = function(info)
					  if st.cfg.artwork.symmetricZoom then return true else return false end
				       end,
				    },
				    bottom = {
				       name = L.Bottom,
				       type = "range",
				       min = 0,
				       max = 1,
				       isPercent = true,
				       order = 0,
				       hidden = function(info)
					  if st.cfg.artwork.symmetricZoom then return true else return false end
				       end,
				    },
				 },
			      },
			   },
			},
			stretching = {
			   name = L.Stretching,
			   type = "select",
			   values = {L.None, L.Vertical, L.Horizontal, L.Full},
			   order = 4,
			},
			anchor = {
			   name = L.Anchor,
			   type = "select",
			   values = CFGHandler.artwork.stretchValues,
			   order = 5,
			   hidden = function(info) 
			      if st.cfg.artwork.stretching == 4 then return true else return false end
			   end,
			},
			offsetX = {
			   name = L["X Offset"],
			   type = "range",
			   order = 6,
			   softMin = -500,
			   softMax = 500,
			   step = 1,
			},
			offsetY = {
			   name = L["Y Offset"],
			   type = "range",
			   order = 7,
			   softMin = -500,
			   softMax = 500,
			   step = 1,
			},
			height = {
			   name = L.Height,
			   type = "range",
			   order = 8,
			   softMin = 0,
			   softMax = 500,
			   step = 1,
			   hidden = function(info)
			      if st.cfg.artwork.stretching == 2 or st.cfg.artwork.stretching == 4 then return true else return false end
			   end,
			},
			width = {
			   name = L.Width,
			   type = "range",
			   order = 9,
			   softMin = 0,
			   softMax = 500,
			   step = 1,
			   hidden = function(info)
			      if st.cfg.artwork.stretching == 3 or st.cfg.artwork.stretching == 4 then return true else return false end
			   end,
			},
			scale = {
			   name = L.Scale,
			   type = "range",
			   order = 10,
			   min = 0.01,
			   max = 1,
			   step = .01,
			   isPercent = true,
			},
		     },
		  },
	       },
	    },
	    bars = {
	       name = L.Bars,
	       type = "group",
	       order = 2,
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
			   values = {[""] = L.None,OUTLINE = L["Thin Outline"], THICKOUTLINE = L["Thick Outline"]},
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
	       order = 3,
	       set = CFGHandler.coloring.set,
	       args = {
		  highlight = {
		     type = "group",
		     name = L.Highlighting,
		     order = 0,
		     inline = true,
		     args = {
			highlightCurrentZoneText = {
			   type = "toggle",
			   name = "Highlight Current Zone Text",
			   width = "double",
			   order = 0,
			},
			highlightCurrentZoneTextColor = {
			   type = "color",
			   name = L.Color,
			   order = 1,
			},
			highlightCurrentZoneBackground = {
			   type = "toggle",
			   name = "Highlight Current Zone Background",
			   width = "double",
			   order = 2,
			},
			highlightCurrentZoneBackgroundColor = {
			   type = "color",
			   name = L.Color,
			   order = 3,
			},
		     },
		  },
		  useDifficultyColor = {
		     name = L["Quest Difficulty Coloring"],
		     type = "toggle",
		     order = 1,
		     width = double,
		  },
		  useProgressColor = {
		     name = L["Progress-based Objective Coloring"],
		     type = "toggle",
		     order = 2,
		     width = double,
		  },
		  progressColor = {
		     name = L["Progress Color"],
		     type = "group",
		     inline = true,
		     order = 3,
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
	       order = 4,
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
		     values = {[""] = L.None, OUTLINE = L["Thin Outline"], THICKOUTLINE = L["Thick Outline"]},
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
		  indent = {
		     type = "range",
		     name = L.Indentation,
		     order = 5,
		     min = 0,
		     max = 5,
		     step = .1,
		     disabled = true, -- lacks proper update handling at the moment
		  },
		  wrap = {
		     name = L["Wrap Long Lines"],
		     type = "toggle",
		     order = 6,
		     disabled = true,
		  },
	       },
	    },
	 },
      },
   },
}

options.args.general.args.output.args.sink.order = 1
options.args.general.args.output.args.sink.inline = true

do -- More unexploding emacs.
   local option = options.args.general.args.general.args
   option = option.uncategorized.args.LDBIcon.values
   option[-1] = [[|TInterface\GossipFrame\AvailableQuestIcon:0|t]]
   option[0] = L["Random Book"]
end

for i = 1,15 do
   local fmt = [[|TInterface\ICONS\INV_MISC_Book_%02d:18|t]]
   -- Rewrite, because for some reason, keeping it in one line kept making my emacs explode.
   local option = options.args.general.args.general.args
   option = option.uncategorized.args.LDBIcon.values
   option[i] = fmt:format(i)
end

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

local function getMouseDisabled(info)
   if #info == 2 or #info == 3 then return not st.cfg.mouse.enabled
   else return not st.cfg.mouse[info[2]].enabled end
end

buttonOptions = {
   func = {
      type = "select",
      name = L["Unmodified Click"],
      values = CFGHandler.mouse.getFuncList,
      order = 0,
   },
   Alt = {
      type = "select",
      name = L["Alt Click"],
      values = CFGHandler.mouse.getFuncList,
      order = 1,
   },
   Control = {
      type = "select",
      name = L["Control Click"],
      values = CFGHandler.mouse.getFuncList,
      order = 2,
   },
   Shift = {
      type = "select",
      name = L["Shift Click"],
      values = CFGHandler.mouse.getFuncList,
      order = 3,
   },
}

local mouseOptions = {
   enabled = {
      type = "toggle",
      name = L.Enabled,
      order = 0,
   },
   LeftButton = {
      type = "group",
      name = L["Left Button"],
      order = 1,
      inline = true,
      disabled = getMouseDisabled,
      args = buttonOptions,
   },
   RightButton = {
      type = "group",
      name = L["Right Button"],
      order = 2,
      inline = true,
      disabled = getMouseDisabled,
      args = buttonOptions,
   },
}

-- options.args.mouse.args
local function buildMouseOptions()
   local i = 0
   for k,v in pairs(st.types) do
      if v.clickScripts then
	 i = i + 1
	 options.args.mouse.args[v.name] = {
	    type = "group",
	    name = L[v.name],
	    order = i,
	    disabled = getMouseDisabled,
	    args = mouseOptions,
	 }
      end
   end
end

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
   buildMouseOptions()
   buildSortOptions()
end

function AQT:ToggleConfig()
   if ACD.OpenFrames["AQT"] then ACD:Close("AQT") else ACD:Open("AQT") end -- A bit silly, the library should already provide this without me having to dig through the code to find it.
end
