{
  flake.modules.homeManager.development = { pkgs, ... }: {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withNodeJs = false;
      withPerl = false;
      withPython3 = false;
      withRuby = false;
      extraPackages = with pkgs; [
        bash-language-server
        nixd
        typescript-language-server
      ];
      plugins = [ pkgs.vimPlugins.rose-pine ];
      initLua = ''
        vim.opt.termguicolors = true
        vim.opt.background = "light"
        vim.cmd("colorscheme rose-pine-dawn")
        vim.diagnostic.config({
          virtual_text = false,
        })

        vim.lsp.config("ts_ls", {
          cmd = { "typescript-language-server", "--stdio" },
          filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
          root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
          init_options = { disableAutomaticTypingAcquisition = true },
        })
        vim.lsp.config("nixd", {
          cmd = { "nixd" },
          filetypes = { "nix" },
          root_markers = { "flake.nix", ".git" },
        })
        vim.lsp.config("bashls", {
          cmd = { "bash-language-server", "start" },
          filetypes = { "sh", "bash" },
          root_markers = { ".git" },
        })
        vim.lsp.enable("ts_ls")
        vim.lsp.enable("nixd")
        vim.lsp.enable("bashls")

      '';
    };
  };
}
