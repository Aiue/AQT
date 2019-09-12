local _,st = ...

local AQT = LibStub("AceAddon-3.0"):GetAddon("AQT")

local AceConfigDialog = LibStub("AceConfigDialog-3.0")

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
   font = {
      get = function(info)
	 return st.cfg.font[info[#info-1]]
      end,
      set = function(info, val)
	 print(tostring(info[#info-1]) .. " : " .. tostring(val))
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
	    name = {
	       name = "Font",
	       type = "group",
	       inline = true,
	       order = 0,
	       get = CFGHandler.font.get,
	       set = CFGHandler.font.set,
	       args = {
		  font = {
		     name = "Font",
		     type = "select",
		     order = 0,
		     values = AceGUIWidgetLSMlists.font,
		     dialogControl = "LSM30_Font",
		  },
		  color = {
		     type = "color",
		     name = "Font",
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
	 },
      },
   },
}

function st.initConfig()
   if not AQTCFG or type(AQTCFG) ~= "table" then AQTCFG = {} end
   clearDefunct(AQTCFG, defaults)
   st.cfg = defaults -- Should be removed once I've actually written some of the other stuff properly. Just need it to not break things while I work on other stuff.
   LibStub("AceConfig-3.0"):RegisterOptionsTable("AQT", options)
   LibStub("AceConsole-3.0"):RegisterChatCommand("aqt", function() LibStub("AceConfigDialog-3.0"):Open("AQT") end)
end
