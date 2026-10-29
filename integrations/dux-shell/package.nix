{ lib, stdenvNoCC, nodejs, bash, coreutils, findutils }:
stdenvNoCC.mkDerivation {
  pname = "syncshell-dux-shell";
  version = (builtins.fromJSON (builtins.readFile ./plugin.json)).version;
  src = lib.fileset.toSource {
    root = ../..;
    fileset = lib.fileset.unions [
      ../../shared
      ../../hosts/dux-shell
      ../../integrations/assemble-qml.mjs
      ./assemble.sh
      ./plugin.json
      ./qml-files.txt
      ./import-map.json
      ../../bin
      ../../webui
      ../../packaging/bundled
      ../../core/go.mod
      ../../LICENSE
      ../../CHANGELOG.md
      ../../assets/LICENSE.md
      ../../assets/mono
      ../../assets/status-default.svg
      ../../assets/status-notify.svg
      ../../assets/status-pause.svg
      ../../assets/status-sync.svg
    ];
  };
  nativeBuildInputs = [ nodejs bash coreutils findutils ];
  dontBuild = true;
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    bash integrations/dux-shell/assemble.sh "$out"
    runHook postInstall
  '';
  meta = {
    description = "Syncthing folder and device management for DMS (Dux Shell)";
    license = with lib.licenses; [ mit mpl20 ofl bsd3 ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
