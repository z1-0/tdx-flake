{
  alsa-lib,
  at-spi2-atk,
  atk,
  buildFHSEnv,
  dbus,
  dpkg,
  expat,
  fetchurl,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk2,
  lib,
  libGL,
  libX11,
  libXScrnSaver,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libXrandr,
  libXrender,
  libXtst,
  libpng,
  libxcb,
  libxcb-cursor,
  libxkbcommon,
  nspr,
  nss,
  pango,
  patchelf,
  procps,
  stdenv,
  stdenvNoCC,
  systemdLibs,
  util-linux,
  writeShellScript,
  zenity,
  zlib,
}:

let
  pname = "tdx";
  sources = import ./sources.nix;
  inherit (sources) version;
  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
  src = fetchurl {
    inherit (source) url hash;
  };

  tdx-uos-env = stdenvNoCC.mkDerivation {
    meta.priority = 1;
    name = "tdx-uos-env";
    buildCommand = ''
      mkdir -p $out
      ln -s ${tdx}/opt $out/opt
    '';
    preferLocalBuild = true;
  };

  tdx-runtime = [
    alsa-lib
    at-spi2-atk
    atk
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk2
    libGL
    libX11
    libXScrnSaver
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libXtst
    libpng
    libxcb
    libxcb-cursor
    libxkbcommon
    nspr
    nss
    pango
    systemdLibs
    util-linux
    zlib
  ];

  tdx = stdenvNoCC.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [
      dpkg
      patchelf
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      dpkg-deb --fsys-tarfile $src | tar -x -C $out

      # CEF looks for locales/ next to the executable
      mkdir -p $out/opt/apps/com.tdx.tdxcfv/files/bin/locales
      cp -n $out/opt/apps/com.tdx.tdxcfv/entries/locale/locales/*.pak \
        $out/opt/apps/com.tdx.tdxcfv/files/bin/locales/

      runHook postInstall
    '';

    postFixup = ''
      # libtdxdllbase.so references XShape* symbols (libXext) but lacks the
      # NEEDED entry; the original package relied on other libs pulling it in.
      # Guarded so it also stays safe on aarch64, where the layout of the
      # bundled libs may differ from the x86_64 build.
      libext=$out/opt/apps/com.tdx.tdxcfv/files/lib64/tdx/libtdxdllbase.so

      if [ -e "$libext" ] && ! patchelf --print-needed "$libext" | grep -qx 'libXext.so.6'; then
        patchelf --add-needed libXext.so.6 "$libext"
      fi
    '';

    meta = {
      description = "TDX Financial Terminal";
      homepage = "http://www.tdx.com.cn";
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };

    passthru.updateScript = ./update.sh;
  };
in

buildFHSEnv {
  inherit pname version;
  inherit (tdx) meta;

  runScript = writeShellScript "tdx-launcher" ''
    basepath=${tdx}/opt/apps/com.tdx.tdxcfv/files/bin

    export LD_LIBRARY_PATH=$basepath/../lib64/tdx:$basepath

    export XDG_DATA_HOME=''${XDG_DATA_HOME:-$HOME/.local/share}

    # the wine-prefix-like data dir may be read-only from previous runs in the sandbox
    if [ -d $XDG_DATA_HOME/tdxcfv ]; then
      chmod -R u+w $XDG_DATA_HOME/tdxcfv 2>/dev/null || true
    fi

    exec $basepath/tdxw.sh
  '';

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons

    cp -r ${tdx}/opt/apps/com.tdx.tdxcfv/entries/applications/com.tdx.tdxcfv.desktop \
      $out/share/applications

    cp -r ${tdx}/opt/apps/com.tdx.tdxcfv/entries/icons/* $out/share/icons/

    substituteInPlace $out/share/applications/com.tdx.tdxcfv.desktop \
      --replace-quiet 'Exec=/opt/apps/com.tdx.tdxcfv/files/bin/tdxw.sh' "Exec=$out/bin/tdx"
  '';

  targetPkgs =
    pkgs:
    [
      tdx-uos-env
      zenity
      procps
    ]
    ++ tdx-runtime;
}
