print("plugin required")

-- Thanks TJ!
function P(t)
  print(vim.inspect(t))
end

local M = {}

M.setup = function(opts)
  P(opts)
  print("Hello World from setup new()!", opts)
end

return M
