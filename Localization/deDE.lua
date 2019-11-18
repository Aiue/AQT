if GetLocale() ~= "deDE" then return end

local _,st = ...

st.loc = {
   colon = ": ",
   whurl = "https://de.classic.wowhead.com/quest=",
}

local L = st.L
--@localization(locale="deDE", format="lua_additive_table", handle-unlocalized="ignore")@
