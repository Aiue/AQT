local _,st = ...

st.loc = {
   colon = ":",
   whurl = "https://classic.wowhead.com/quest=",
}

st.L = {}

setmetatable(st.L, {__index = function(t,k) return k end})
