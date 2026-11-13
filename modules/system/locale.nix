{
  flake.modules.nixos.base = {
    time.timeZone = "America/Sao_Paulo";
    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocaleSettings = {
        LC_TIME = "pt_BR.UTF-8";
        LC_NUMERIC = "pt_BR.UTF-8";
        LC_MONETARY = "pt_BR.UTF-8";
        LC_MEASUREMENT = "pt_BR.UTF-8";
        LC_PAPER = "pt_BR.UTF-8";
      };
    };
    services.xserver.xkb = {
      layout = "us";
      variant = "intl";
    };
    console.useXkbConfig = true;
  };
}
