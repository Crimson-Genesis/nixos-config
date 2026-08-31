{
  description = "NixOS configuration and multi-target development shells";

  inputs = {
    polymc.url = "github:PolyMC/PolyMC";

    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    zen-browser,
    antigravity-nix,
    home-manager,
    nvf,
    rust-overlay,
    ...
  }: let
    lib = nixpkgs.lib;

    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    hasConfiguration = builtins.pathExists ./configuration.nix;

    mkPkgs = system:
      import nixpkgs {
        inherit system;
        overlays = [
          rust-overlay.overlays.default
        ];
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };

    mkDevShells = system: let
      pkgs = mkPkgs system;
      isLinux = pkgs.stdenv.isLinux;
      isDarwin = pkgs.stdenv.isDarwin;
      hostGoArch =
        if pkgs.stdenv.hostPlatform.isAarch64
        then "arm64"
        else "amd64";
      windowsGoArch = "amd64";
      rustLinuxTarget =
        if pkgs.stdenv.hostPlatform.isAarch64
        then "aarch64-unknown-linux-gnu"
        else "x86_64-unknown-linux-gnu";

      androidPlatformVersion = "35";
      androidBuildToolsVersion = "35.0.0";
      androidNdkVersion = "27.2.12479018";

      mkRustToolchain = targets:
        pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "rust-src"
            "rustfmt"
            "clippy"
          ];
          inherit targets;
        };

      rustLinuxToolchain = mkRustToolchain [
        rustLinuxTarget
      ];

      rustWindowsToolchain = mkRustToolchain [
        "x86_64-pc-windows-gnu"
      ];

      rustMacToolchain = mkRustToolchain [
        "aarch64-apple-darwin"
        "x86_64-apple-darwin"
      ];

      rustLinuxPackages = [
        rustLinuxToolchain
        pkgs.rust-analyzer
      ];

      rustWindowsPackages =
        [
          rustWindowsToolchain
          pkgs.rust-analyzer
        ]
        ++ lib.optionals (pkgs ? pkgsCross && pkgs.pkgsCross ? mingwW64) [
          pkgs.pkgsCross.mingwW64.stdenv.cc
        ];

      rustMacPackages =
        [
          rustMacToolchain
          pkgs.rust-analyzer
        ]
        ++ lib.optionals isDarwin (
          (with pkgs; [
            libiconv
          ])
          ++ (with pkgs.darwin.apple_sdk.frameworks; [
            CoreFoundation
            Security
            SystemConfiguration
          ])
        );

      goBasePackages = with pkgs; [
        go
        gopls
        delve
      ];

      goLinuxPackages = goBasePackages;

      goWindowsPackages =
        goBasePackages
        ++ lib.optionals (pkgs ? pkgsCross && pkgs.pkgsCross ? mingwW64) [
          pkgs.pkgsCross.mingwW64.stdenv.cc
        ];

      goMacPackages =
        goBasePackages
        ++ lib.optionals isDarwin (
          (with pkgs; [
            libiconv
          ])
          ++ (with pkgs.darwin.apple_sdk.frameworks; [
            CoreFoundation
            Security
            SystemConfiguration
          ])
        );

      buildPackages = with pkgs;
        [
          gcc
          clang
          llvm
          lld
          gnumake
          cmake
          ninja
          pkg-config
        ]
        ++ lib.optionals isLinux (with pkgs; [
          aapt
          patchelf
        ]);

      debugPackages = with pkgs;
        [
          lldb
        ]
        ++ lib.optionals isLinux (with pkgs; [
          gdb
          strace
          ltrace
        ]);

      versionControlPackages = with pkgs; [
        git
        git-lfs
      ];

      networkingPackages = with pkgs; [
        curl
        wget
      ];

      compressionPackages = with pkgs; [
        zlib
        xz
        bzip2
        zstd
      ];

      databasePackages = with pkgs; [
        postgresql
      ];

      cryptoPackages = with pkgs; [
        openssl
      ];

      imagePackages = with pkgs; [
        libjpeg
        libpng
        libwebp
      ];

      audioPackages = lib.optionals isLinux (with pkgs; [
        alsa-lib
        pulseaudio
      ]);

      videoPackages = with pkgs; [
        ffmpeg
      ];

      x11Packages = lib.optionals isLinux (with pkgs; [
        libx11
        libxcursor
        libxi
        libxrandr
        libxrender
        libxext
        libxfixes
        libxinerama
        libxcb
        libxscrnsaver
        xdotool
      ]);

      waylandPackages = lib.optionals isLinux (with pkgs; [
        wayland
        wayland-protocols
      ]);

      graphicsPackages =
        lib.optionals isLinux (with pkgs; [
          mesa
          vulkan-loader
          vulkan-headers
          libGL
        ])
        ++ lib.optionals isDarwin (with pkgs; [
          moltenvk
        ]);

      guiPackages =
        lib.optionals isLinux (with pkgs; [
          gtk3
          gtk4
          webkitgtk_4_1
        ])
        ++ lib.optionals isDarwin (
          with pkgs.darwin.apple_sdk.frameworks; [
            AppKit
            Cocoa
            CoreServices
          ]
        );

      systemPackages =
        (with pkgs; [
          glib
          libxkbcommon
        ])
        ++ lib.optionals isLinux (with pkgs; [
          dbus
          udev
        ]);

      androidComposition = pkgs.androidenv.composeAndroidPackages {
        cmdLineToolsVersion = "13.0";
        platformToolsVersion = "35.0.2";
        buildToolsVersions = [
          androidBuildToolsVersion
        ];
        platformVersions = [
          androidPlatformVersion
        ];
        includeNDK = true;
        ndkVersions = [
          androidNdkVersion
        ];
      };

      androidPackages = with pkgs; [
        android-tools
        jdk21
        gradle
        androidComposition.androidsdk
      ];

      pythonBase = pkgs.python3.withPackages (ps:
        with ps; [
          pip
          setuptools
          virtualenv
          wheel
        ]);

      pythonMl = pkgs.python3.withPackages (ps:
        with ps; [
          pip
          setuptools
          virtualenv
          wheel
          numpy
          pandas
          matplotlib
          scikit-learn
          jupyter
          notebook
          scipy
        ]);

      pythonPackages = [
        pythonBase
      ];

      pythonDevPackages = with pkgs; [
        black
        ruff
        pyright
      ];

      pythonMlPackages = [
        pythonMl
      ];

      basePackages =
        buildPackages
        ++ debugPackages
        ++ versionControlPackages
        ++ networkingPackages
        ++ compressionPackages
        ++ databasePackages
        ++ cryptoPackages;

      desktopPackages =
        imagePackages
        ++ audioPackages
        ++ videoPackages
        ++ x11Packages
        ++ waylandPackages
        ++ graphicsPackages
        ++ guiPackages
        ++ systemPackages;

      commonNativePackages =
        basePackages
        ++ desktopPackages;

      commonPythonPackages =
        pythonPackages
        ++ pythonDevPackages;

      commonMlPackages =
        pythonMlPackages
        ++ pythonDevPackages;

      osDevPackages = with pkgs;
        [
          # Debian bootstrap
          debootstrap

          # Debian packaging
          dpkg
          fakeroot
          reprepro
          equivs
          quilt

          # ISO / bootloader
          grub2
          xorriso
          syslinux
          libisoburn
          cdrkit

          # Filesystem tools
          squashfsTools
          e2fsprogs
          dosfstools
          mtools
          parted
          gptfdisk
          cpio

          # Compression
          gzip
          xz
          zstd
          lz4

          # Base utilities
          bash
          coreutils
          findutils
          gnugrep
          gnused
          util-linux
          gawk
          perl
          rsync
          curl
          wget
          jq
          yq

          # Build tools
          gcc
          binutils
          gnumake
          cmake
          ninja
          pkg-config
          bc
          kmod

          # Version control
          git
          git-lfs

          # Debugging
          gdb
          strace
          diffoscope
          file
          tree
          xxd

          # Libraries
          openssl
          libarchive

          # Xen / libvirt utilities
          libvirt
          libguestfs
          virt-viewer
          virt-top
          swtpm
          xmlstarlet
          dmidecode
        ]
        ++ lib.optionals (pkgs ? mmdebstrap) [
          mmdebstrap
        ];

      mkNativePackages = rust: go:
        rust
        ++ go
        ++ commonNativePackages;

      mkAndroidPackages = rust: go:
        mkNativePackages rust go
        ++ androidPackages;

      mkAllPackages = rust: go:
        mkAndroidPackages rust go
        ++ commonMlPackages;

      commonRustHook = ''
        export RUST_BACKTRACE=1
        export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1

        echo "Rust: $(rustc --version)"
      '';

      rustLinuxHook = ''
        echo "Rust Linux target"
      '';

      rustWindowsHook = ''
        export CARGO_BUILD_TARGET=x86_64-pc-windows-gnu

        if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
          export CC_x86_64_pc_windows_gnu=x86_64-w64-mingw32-gcc
          export CXX_x86_64_pc_windows_gnu=x86_64-w64-mingw32-g++
          export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=x86_64-w64-mingw32-gcc
        fi

        echo "Rust Windows target"
      '';

      rustMacHook = ''
        if [[ "$(uname -m)" == "arm64" || "$(uname -m)" == "aarch64" ]]; then
          export CARGO_BUILD_TARGET=aarch64-apple-darwin
        else
          export CARGO_BUILD_TARGET=x86_64-apple-darwin
        fi
        export MACOSX_DEPLOYMENT_TARGET=13.0

        echo "Rust macOS target"
      '';

      commonGoHook = ''
        echo "Go:   $(go version)"
      '';

      goLinuxHook = ''
        export GOOS=linux
        export GOARCH=${hostGoArch}

        echo "Go Linux target"
      '';

      goWindowsHook = ''
        export GOOS=windows
        export GOARCH=${windowsGoArch}
        export CGO_ENABLED=1

        if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
          export CC=x86_64-w64-mingw32-gcc
          export CXX=x86_64-w64-mingw32-g++
        fi

        echo "Go Windows target"
      '';

      goMacHook = ''
        export GOOS=darwin
        if [[ "$(uname -m)" == "arm64" || "$(uname -m)" == "aarch64" ]]; then
          export GOARCH=arm64
        else
          export GOARCH=amd64
        fi
        export MACOSX_DEPLOYMENT_TARGET=13.0

        echo "Go macOS target"
      '';

      commonAndroidHook = ''
        export ANDROID_HOME=${androidComposition.androidsdk}/libexec/android-sdk
        export ANDROID_SDK_ROOT="$ANDROID_HOME"
        export ANDROID_NDK_ROOT="$ANDROID_HOME/ndk/${androidNdkVersion}"
        export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"

        echo "Adb:  $(adb version | head -n 1)"
        echo "Java: $(java -version 2>&1 | head -n 1)"
      '';

      commonPythonHook = ''
        echo "Python: $(python --version)"
        echo "Pip:    $(python -m pip --version)"
      '';

      pythonMlHook = ''
        echo "Python ML Environment"
      '';

      shellHookSuffix = ''
        if [[ -n "''${ROFI_TMUX_CMD:-}" ]]; then
          clear
          eval "$ROFI_TMUX_CMD"
          unset ROFI_TMUX_CMD
        fi
      '';

      osDevHook = ''
        export LANG=C.UTF-8

        echo "=============================="
        echo "Entropy OS Development Shell"
        echo "=============================="
        echo
      '';

      mkShell = packages: hook:
        pkgs.mkShellNoCC {
          inherit packages;
          shellHook = hook + shellHookSuffix;
        };

      rustHook = targetHook: commonRustHook + targetHook;
      goHook = targetHook: targetHook + commonGoHook;
      rustGoHook = rustTargetHook: goTargetHook:
        rustHook rustTargetHook + goHook goTargetHook;
      rustGoAndroidHook = rustTargetHook: goTargetHook:
        rustGoHook rustTargetHook goTargetHook + commonAndroidHook;

      mainShells = rec {
        r-linux = mkShell (rustLinuxPackages ++ commonNativePackages) (rustHook rustLinuxHook);
        r-windows = mkShell (rustWindowsPackages ++ commonNativePackages) (rustHook rustWindowsHook);
        r-macos = mkShell (rustMacPackages ++ commonNativePackages) (rustHook rustMacHook);

        g-linux = mkShell (goLinuxPackages ++ commonNativePackages) (goHook goLinuxHook);
        g-windows = mkShell (goWindowsPackages ++ commonNativePackages) (goHook goWindowsHook);
        g-macos = mkShell (goMacPackages ++ commonNativePackages) (goHook goMacHook);

        rg-linux =
          mkShell
          (mkNativePackages rustLinuxPackages goLinuxPackages)
          (rustGoHook rustLinuxHook goLinuxHook);
        rg-windows =
          mkShell
          (mkNativePackages rustWindowsPackages goWindowsPackages)
          (rustGoHook rustWindowsHook goWindowsHook);
        rg-macos =
          mkShell
          (mkNativePackages rustMacPackages goMacPackages)
          (rustGoHook rustMacHook goMacHook);

        rga-linux =
          mkShell
          (mkAndroidPackages rustLinuxPackages goLinuxPackages)
          (rustGoAndroidHook rustLinuxHook goLinuxHook);
        rga-windows =
          mkShell
          (mkAndroidPackages rustWindowsPackages goWindowsPackages)
          (rustGoAndroidHook rustWindowsHook goWindowsHook);
        rga-macos =
          mkShell
          (mkAndroidPackages rustMacPackages goMacPackages)
          (rustGoAndroidHook rustMacHook goMacHook);

        all-linux = mkShell (mkAllPackages rustLinuxPackages goLinuxPackages) (rustGoAndroidHook rustLinuxHook goLinuxHook + pythonMlHook);
        all-windows = mkShell (mkAllPackages rustWindowsPackages goWindowsPackages) (rustGoAndroidHook rustWindowsHook goWindowsHook + pythonMlHook);
        all-macos = mkShell (mkAllPackages rustMacPackages goMacPackages) (rustGoAndroidHook rustMacHook goMacHook + pythonMlHook);
      };

      linuxPythonShells = lib.optionalAttrs isLinux {
        python = mkShell commonPythonPackages commonPythonHook;

        python-ml =
          mkShell
          (commonPythonPackages ++ pythonMlPackages)
          (commonPythonHook + pythonMlHook);

        python-rust =
          mkShell
          (commonPythonPackages ++ rustLinuxPackages ++ commonNativePackages)
          (commonPythonHook + rustHook rustLinuxHook);

        python-android =
          mkShell
          (commonPythonPackages ++ androidPackages)
          (commonPythonHook + commonAndroidHook);

        python-rust-go =
          mkShell
          (commonPythonPackages ++ mkNativePackages rustLinuxPackages goLinuxPackages)
          (commonPythonHook + rustGoHook rustLinuxHook goLinuxHook);
      };

      shells =
        (mainShells // linuxPythonShells)
        // {
          os-dev = mkShell osDevPackages osDevHook;
        };
    in
      shells
      // {
        default = shells.rg-linux;
      };
  in {
    nixosConfigurations = lib.optionalAttrs hasConfiguration {
      nixos = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};

        modules = [
          ./configuration.nix

          home-manager.nixosModules.home-manager

          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
            home-manager.users.nico =
              import ./users/nico/default.nix;
          }

          ({pkgs, ...}: {
            nixpkgs.overlays = [
              inputs.polymc.overlay
            ];

            environment.systemPackages = [
              pkgs.polymc

              antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
              antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-ide
              antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli
            ];
          })
        ];
      };
    };

    devShells = lib.genAttrs supportedSystems mkDevShells;
  };
}
