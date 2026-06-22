local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- Nightly compatibility for plugins that have not caught up with recent API churn.
vim.tbl_islist = vim.tbl_islist or vim.islist

vim.F = vim.F or {}
vim.F.if_nil = function(value, fallback)
	if value == nil then
		return fallback
	end
	return value
end

vim.tbl_flatten = function(value)
	local flattened = {}
	local function flatten(item)
		if type(item) == "table" then
			for _, child in ipairs(item) do
				flatten(child)
			end
		else
			table.insert(flattened, item)
		end
	end
	flatten(value)
	return flattened
end

local validate = vim.validate
local validate_type_aliases = {
	b = "boolean",
	f = "function",
	n = "number",
	s = "string",
	t = "table",
}
local function normalize_validate_type(validator)
	if type(validator) == "string" then
		return validate_type_aliases[validator] or validator
	end

	if type(validator) == "table" then
		local normalized = {}
		for index, item in ipairs(validator) do
			normalized[index] = normalize_validate_type(item)
		end
		return normalized
	end

	return validator
end

vim.validate = function(name, value, validator, optional_or_msg, message)
	if type(name) == "table" and value == nil then
		for arg_name, spec in pairs(name) do
			validate(arg_name, spec[1], normalize_validate_type(spec[2]), spec[3], spec[4])
		end
		return
	end

	return validate(name, value, normalize_validate_type(validator), optional_or_msg, message)
end

require("vim-options")
require("lazy").setup("plugins")

--require("nordic.nvim").setup()
