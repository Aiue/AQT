if GetLocale() ~= "itIT" then return end

local _,st = ...

st.loc = {
   colon = ":",
   whurl = "https://it.classic.wowhead.com/quest=",
}

local L = st.L

--@localization(locale="itIT", format="lua_additive_table", handle-unlocalized="ignore")@
