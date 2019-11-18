if GetLocale() ~= "koKR" then return end

local _,st = ...

st.loc = {
   colon = ": ",
   whurl = "http://wow.inven.co.kr/dataninfo/wdb/edb_quest/detail.php?id=",
}

local L = st.L

--@localization(locale="koKR", format="lua_additive_table", handle-unlocalized="ignore")@
