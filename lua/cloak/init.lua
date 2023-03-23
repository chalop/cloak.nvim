local group = vim.api.nvim_create_augroup('cloak', {})
local namespace = vim.api.nvim_create_namespace('cloak')

-- In case cmp is lazy loaded, we check :CmpStatus instead of a pcall to require
-- so we maintain the lazy load.
local has_cmp = function()
  return vim.fn.exists(':CmpStatus') > 0
end

local M = {}

M.opts = {
  enabled = true,
  cloak_character = '*',
  cloak_length = nil,
  highlight_group = 'Comment',
  patterns = { { file_pattern = '.env*', cloak_pattern = '=.+' } },
}

M.setup = function(opts)
  M.opts = vim.tbl_deep_extend('force', M.opts, opts or {})

  for _, pattern in ipairs(M.opts.patterns) do
    vim.api.nvim_create_autocmd(
      { 'BufRead', 'TextChanged', 'TextChangedI', 'TextChangedP' }, {
        pattern = pattern.file_pattern,
        callback = function()
          if M.opts.enabled then
            M.cloak(pattern.cloak_pattern)
          end
        end,
        group = group,
      }
    )
  end

  vim.api.nvim_create_user_command('CloakEnable', M.enable, {})
  vim.api.nvim_create_user_command('CloakDisable', M.disable, {})
  vim.api.nvim_create_user_command('CloakToggle', M.toggle, {})
end

M.uncloak = function()
  vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
end

M.cloak = function(cloak_pattern)
  M.uncloak()

  if type(cloak_pattern) == 'string' then
    cloak_pattern = { cloak_pattern }
  end

  if has_cmp() then
    require('cmp').setup.buffer({ enabled = false })
  end

  local function determine_pattern(first_line, last_line)
    if tonumber(M.opts.cloak_length) ~= nil then
      return string.rep(M.opts.cloak_character, M.opts.cloak_length)..string.rep(' ', last_line - first_line)
    else
      return string.rep(M.opts.cloak_character, last_line - first_line)
    end
  end

  local found_pattern = false
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    for _, pattern in ipairs(cloak_pattern) do
      local first, last = line:find(pattern)

      if first ~= nil then
        found_pattern = true
        vim.api.nvim_buf_set_extmark(
          0, namespace, i - 1, first, {
            hl_mode = 'combine',
            virt_text = {
              {
                determine_pattern(first, last),
                M.opts.highlight_group,
              },
            },
            virt_text_pos = 'overlay',
          }
        )
      end
    end
  end
  if found_pattern then
    vim.opt_local.wrap = false
  end
end

M.disable = function()
  M.uncloak()
  M.opts.enabled = false
end

M.enable = function()
  M.opts.enabled = true
  vim.cmd('doautocmd TextChanged')
end

M.toggle = function()
  if M.opts.enabled then
    M.disable()
  else
    M.enable()
  end
end

return M
