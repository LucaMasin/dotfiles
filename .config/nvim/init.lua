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

-- Neovim 0.13 removed vim.tbl_islist; some plugins still expect it.
vim.tbl_islist = vim.tbl_islist or vim.islist

require("vim-options")
require("lazy").setup("plugins")

--require("nordic.nvim").setup()
