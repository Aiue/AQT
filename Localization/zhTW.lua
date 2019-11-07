if GetLocale() ~= "zhTW" then return end

local _,st = ...

st.loc = {
   comma = "：",
   whurl = "https://cn.classic.wowhead.com/quest=",
}

local L = st.L

--@localization(locale="zhTW", format="lua_additive_table", handle-unlocalized="ignore")@
