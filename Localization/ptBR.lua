if GetLocale() ~= "ptBR" then return end

local _,st = ...

st.loc = {
   colon = ":",
   whurl = "https://pt.classic.wowhead.com/quest=",
}

local L = st.L

--@localization(locale="ptBR", format="lua_additive_table", handle-unlocalized="ignore")@
