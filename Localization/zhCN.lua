if GetLocale() ~= "zhCN" then return end

local _,st = ...

st.loc = {
   colon = "：",
   whurl = "https://cn.classic.wowhead.com/quest=",
}

local L = st.L

--@localization(locale="zhCN", format="lua_additive_table", handle-unlocalized="ignore")@
