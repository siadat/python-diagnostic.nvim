-- Thanks TJ!
-- This script is heavily borrowed from https://sourcegraph.com/github.com/tjdevries/config_manager@ee11710c4ad09e0b303e5030b37c86ad8674f8b2/-/blob/xdg_config/nvim/scratch/automagic/part3.lua
function P(t)
  print(vim.inspect(t))
end

local ns = vim.api.nvim_create_namespace "live-tests"
local group = vim.api.nvim_create_augroup("python-diagnostic", { clear = true })

local attach_to_buffer = function(bufnr, command)
  local state = {
    bufnr = bufnr,
    tests = {},
  }

  vim.api.nvim_buf_create_user_command(bufnr, "PythonTestLineDiag", function()
    local line = vim.fn.line "." - 1
    for _, test in pairs(state.tests) do
      if test.line == line then
        vim.cmd.new()
        vim.api.nvim_buf_set_lines(vim.api.nvim_get_current_buf(), 0, -1, false, test.output)
      end
    end
  end, {})

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.py",
    callback = function()
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

      state = {
        bufnr = bufnr,
        tests = {},
      }

      vim.fn.jobstart(vim.fn.split(command, " "), {
        stdout_buffered = true,
        on_stdout = function(_, data)
          if not data then
            return
          end

          for _, line in ipairs(data) do
            -- Check if line matches lines like this: File "/home/sina/src/pcass/tests/test_main.py", line 52, in test_encode_and_decode
            print("LINE", line)
            if string.match(line, "File \".+\", line %d+, in .+") then
              local file, errline, test_name = string.match(line, "File \"(.+)\", line (%d+), in (.+)")
              -- convert errline to number:
              errline = tonumber(errline)-1

              -- check if file is in the current directory:
              if string.match(file, vim.fn.getcwd()) then
                print("YES", file, errline, test_name)
                local test = {
                  file = file,
                  line = errline,
                  name = test_name,
                  output = {},
                  success = false,
                }
                local key = file .. ":" .. errline .. ":" .. test_name
                state.tests[key] = test
              end
            end
          end
        end,

        on_exit = function()
          local failed = {}
          for _, test in pairs(state.tests) do
            if test.line then
              if not test.success then
                table.insert(failed, {
                  bufnr = bufnr,
                  lnum = test.line,
                  col = 0,
                  severity = vim.diagnostic.severity.ERROR,
                  source = "python-test-source",
                  message = "Test Failed",
                  user_data = {},
                })
              end
            end
          end

          vim.diagnostic.set(ns, bufnr, failed, {})
        end,
      })
    end,
  })
end

local M = {}

M.setup = function(opts)
  vim.api.nvim_create_user_command("PythonTestOnSave", function()
    attach_to_buffer(vim.api.nvim_get_current_buf(), opts.command)
  end, {})
end

return M
