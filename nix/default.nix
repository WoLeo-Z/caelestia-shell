{
  rev,
  lib,
  stdenv,
  makeWrapper,
  makeFontsConf,
  app2unit,
  material-symbols,
  rubik,
  nerd-fonts,
  gcc,
  qt6,
  quickshell,
  wayland,
  wayland-protocols,
  wayland-scanner,
  xkeyboard-config,
  caelestia-cli,
  withCli ? false,
  extraRuntimeDeps ? [],
}: let
  runtimeDeps =
    [
      app2unit
    ]
    ++ extraRuntimeDeps
    ++ lib.optional withCli caelestia-cli;

  fontconfig = makeFontsConf {
    fontDirectories = [material-symbols rubik nerd-fonts.caskaydia-cove];
  };

  idleInhibitor = stdenv.mkDerivation {
    pname = "wayland-idle-inhibitor";
    version = "1.0";

    src = ./..;

    nativeBuildInputs = [gcc wayland-scanner wayland-protocols];
    buildInputs = [wayland];

    buildPhase = ''
      wayland-scanner client-header < ${wayland-protocols}/share/wayland-protocols/unstable/idle-inhibit/idle-inhibit-unstable-v1.xml > idle-inhibitor.h
      wayland-scanner private-code < ${wayland-protocols}/share/wayland-protocols/unstable/idle-inhibit/idle-inhibit-unstable-v1.xml > idle-inhibitor.c
      cp assets/cpp/idle-inhibitor.cpp .

      gcc -o idle-inhibitor.o -c idle-inhibitor.c
      g++ -o inhibit_idle idle-inhibitor.cpp idle-inhibitor.o -lwayland-client
    '';

    installPhase = ''
      mkdir -p $out/bin
      install -Dm755 inhibit_idle $out/bin/inhibit_idle
    '';
  };
in
  stdenv.mkDerivation {
    pname = "caelestia-shell";
    version = "${rev}";
    src = ./..;

    nativeBuildInputs = [gcc makeWrapper qt6.wrapQtAppsHook];
    buildInputs = [quickshell idleInhibitor xkeyboard-config qt6.qtbase];
    propagatedBuildInputs = runtimeDeps;

    patchPhase = ''
      substituteInPlace assets/pam.d/fprint \
        --replace-fail pam_fprintd.so /run/current-system/sw/lib/security/pam_fprintd.so
    '';

    installPhase = ''
      mkdir -p $out/share/caelestia-shell
      cp -r ./* $out/share/caelestia-shell

      makeWrapper ${quickshell}/bin/qs $out/bin/caelestia-shell \
      	--prefix PATH : "${lib.makeBinPath runtimeDeps}" \
      	--set FONTCONFIG_FILE "${fontconfig}" \
      	--set CAELESTIA_II_PATH ${idleInhibitor}/bin/inhibit_idle \
        --set CAELESTIA_XKB_RULES_PATH ${xkeyboard-config}/share/xkeyboard-config-2/rules/base.lst \
      	--add-flags "-p $out/share/caelestia-shell"

      	ln -sf ${idleInhibitor}/bin/inhibit_idle $out/bin
    '';

    meta = {
      description = "A very segsy desktop shell";
      homepage = "https://github.com/caelestia-dots/shell";
      license = lib.licenses.gpl3Only;
      mainProgram = "caelestia-shell";
    };
  }
