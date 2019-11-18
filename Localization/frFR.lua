if GetLocale() ~= "frFR" then return end

local _,st = ...

st.loc = {
   colon = ": ",
   whurl = "https://fr.classic.wowhead.com/quest=",
}

local L = st.L

--@localization(locale="frFR", format="lua_additive_table", handle-unlocalized="ignore")@
