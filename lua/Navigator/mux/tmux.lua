---@mod navigator.tmux Tmux navigator
---@brief [[
---This module provides navigation and interaction for Tmux, and uses |navigator.vi|
---as a base class. This is used automatically when tmux is detected on host
---system but can also be used to manually override the mux.
---Read also: https://github.com/numToStr/Navigator.nvim/wiki/Tmux-Integration
---@brief ]]

---@private
---@class Tmux: Vi
---@field private pane string
---@field private direction table<Direction, string>
---@field private execute fun(arg: string): unknown
local Tmux = require('Navigator.mux.vi'):new()

---Creates a new Tmux navigator instance
---@return Tmux
---@usage [[
---local ok, tmux = pcall(function()
---    return require('Navigator.mux.tmux'):new()
---end)
---
---require('Navigator').setup({
---    mux = ok and tmux or 'auto'
---})
---@usage ]]
function Tmux:new()
    local instance = os.getenv('TMUX')
    local pane = os.getenv('TMUX_PANE')

    assert(instance and pane, '[Navigator] Tmux is not running!')

    local socket = string.match(instance, '^(.-),')
    local cmd = instance:find('^.*tmate') and 'tmate' or 'tmux'

    ---@type Tmux
    local state = {
        pane = pane,
        execute = function(arg)
            return require('Navigator.utils').execute(string.format('%s -S %s %s', cmd, socket, arg))
        end,
        direction = { p = 'l', h = 'L', k = 'U', l = 'R', j = 'D' },
    }
    self.__index = self
    return setmetatable(state, self)
end

---Checks if tmux is zoomed in
---@return boolean
function Tmux:zoomed()
    return self.execute("display-message -p '#{window_zoomed_flag}'") == '1'
end

---Switch pane in tmux
---@param direction Direction See |navigator.api.Direction|
---@return Tmux
function Tmux:navigate(direction)
    self.execute(string.format("select-pane -t '%s' -%s", self.pane, self.direction[direction]))
    return self
end

---To check whether only one tmux pane exists in a direction
---@param direction string
---@return boolean
function Tmux:single_pane(direction, disable_on_zoom)
    -- Check if only one tmux pane exists
    if self.execute("display-message -p '#{window_panes}'") == '1' then
        return true
    end

    -- Check if tmux pane is zoomed
    if self:zoomed() and disable_on_zoom then
        return true
    end

    -- Compare dimensions of the tmux pane and tmux window in direction
    if direction == 'h' or direction == 'l' then
        return self.execute("display-message -p '#{pane_width}'") == self.execute("display-message -p '#{window_width}'")
    elseif direction == 'j' or direction == 'k' then
        return self.execute("display-message -p '#{pane_height}'") == self.execute("display-message -p '#{window_height}'")
    end
end

return Tmux
