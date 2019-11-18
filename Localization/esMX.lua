if GetLocale() ~= "esMX" then return end

local _,st = ...

st.loc = {
   colon = ": ",
   whurl = "https://es.classic.wowhead.com/quest=",
}

local L = st.L

--@localization(locale="esMX", format="lua_additive_table", handle-unlocalized="ignore")@
