{ config, lib, pkgs, ... }:
let
  cfg = config.programs.syncshell-dux-shell;
in {
  options.programs.syncshell-dux-shell = {
    enable = lib.mkEnableOption "the Syncshell DMS plugin";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      description = "Self-contained Syncshell DMS plugin package";
    };
  };
  config = lib.mkIf cfg.enable {
    programs.dank-material-shell.plugins.syncshell = {
      enable = true;
      src = cfg.package;
    };
    home.packages = [ pkgs.bash pkgs.coreutils pkgs.findutils ];
  };
}
