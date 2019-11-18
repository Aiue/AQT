if GetLocale() ~= "ruRU" then return end

local _,st = ...

st.loc = {
   colon = ": ",
   whurl = "https://ru.classic.wowhead.com/quest=",
}

local L = st.L

--@localization(locale="ruRU", format="lua_additive_table", handle-unlocalized="ignore")@
