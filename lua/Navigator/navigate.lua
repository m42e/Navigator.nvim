local A = vim.api
local cmd = A.nvim_command

---State and defaults
---@class Nav
---@field last_pane boolean
---@field config? Config
local N = {
    last_pane = false,
    config = nil,
}

---Detect and load correct mux
---@return Vi
local function load_mux()
    local ok_tmux, tmux = pcall(function()
        return require('Navigator.mux.tmux'):new()
    end)
    if ok_tmux then
        return tmux
    end
    local ok_wezterm, wezterm = pcall(function()
        return require('Navigator.mux.wezterm'):new()
    end)
    if ok_wezterm then
        return wezterm
    end
    return require('Navigator.mux.vi'):new()
end

---For setting up the plugin with the user provided options
---@param opts Config
function N.setup(opts)
    ---@type Config
    local config = {
        disable_on_zoom = false,
        auto_save = nil,
        mux = 'auto',
        circular_movement = false,
    }

    if opts ~= nil then
        N.config = vim.tbl_extend('keep', opts, config)
    else
        N.config = config
    end

    if N.config.mux == 'auto' then
        N.config.mux = load_mux()
    end

    A.nvim_create_autocmd('WinEnter', {
        group = A.nvim_create_augroup('NAVIGATOR', { clear = true }),
        callback = function()
            N.last_pane = false
        end,
    })
end

---Checks whether we need to move to the nearby mux pane
---@param at_edge boolean
---@return boolean
local function back_to_mux(at_edge)
    if N.config.disable_on_zoom and N.config.mux:zoomed() then
        return false
    end
    return N.last_pane or at_edge
end

---For smoothly navigating through neovim splits and mux panes
---@param direction string
function N.navigate(direction)
    -- window id before navigation
    local cur_win = A.nvim_get_current_win()

    local mux_last_pane = direction == 'p' and N.last_pane
    if not mux_last_pane then
        cmd('wincmd ' .. direction)
    end

    -- Check if the old window and new window match after navigation
    local at_edge = cur_win == A.nvim_get_current_win()
    local window_changed = cur_win ~= A.nvim_get_current_win()

    -- If only one tmux pane exists, perform
    -- 'circular movement' if on an edge
    if N.config.circular_movement and at_edge and (N.config.mux:single_pane(direction, N.config.disable_on_zoom)) then
        local alt_directions = { h = 'l', j = 'k', k = 'j', l = 'h' }

        local at_alt_edge = false

        while not at_alt_edge do
            local new_cur_win = A.nvim_get_current_win()
            cmd('wincmd ' .. alt_directions[direction])
            at_alt_edge = new_cur_win == A.nvim_get_current_win()
        end

        -- If the window has changed, don't change tmux pane
        window_changed = cur_win ~= A.nvim_get_current_win()
    end

    -- If the old window and new window match
    -- then we can assume that we hit the edge
    -- there is tmux pane besided the edge
    -- So we can navigate to the tmux pane
    if back_to_mux(at_edge) and not window_changed then
        N.config.mux:navigate(direction)

        local save = N.config.auto_save
        if save == 'current' then
            cmd('update')
        elseif save == 'all' then
            cmd('wall')
        end

        N.last_pane = true
    else
        N.last_pane = false
    end
end

return N
