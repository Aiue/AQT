-- This file doesn't really do much more than set up the localization metatable.

local _,st = ...

st.L = {}

setmetatable st.L({__index = function(t,k) return k end})
