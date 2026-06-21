-- MoomDeck startup entry point for CC:Tweaked computers
-- Place the entire moomdeck folder and this file on your computer.

local loader = dofile("moomdeck/init.lua")
local require = loader.require

local boot = require("boot")
boot.start()
