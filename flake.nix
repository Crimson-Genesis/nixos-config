{
  description = "A very basic flake";

  inputs = {
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
  };
  outputs = inputs @ {
    self,
    nixpkgs,
    zen-browser,
    antigravity-nix,
    home-manager,
    nvf,
    ...
  }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
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
          environment.systemPackages = [
            antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
            antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-ide
            antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli
          ];
        })
      ];
    };

    devShells.x86_64-linux = let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
      rustGoPackages = with pkgs; [
        # Rust
        rustc
        cargo
        rustfmt
        clippy
        rust-analyzer

        # Go
        go
        gopls
        delve

        # Build tools
        gcc
        clang
        llvm
        lld
        gnumake
        cmake
        ninja
        pkg-config
        patchelf

        # Debugging
        gdb
        lldb
        strace
        ltrace

        # Version control
        git
        git-lfs

        # Networking
        curl
        wget

        # Compression
        zlib
        xz
        bzip2
        zstd

        # Databases
        postgresql

        # Crypto / TLS
        openssl

        # Image libraries
        libjpeg
        libpng
        libwebp

        # Audio
        alsa-lib
        pulseaudio

        # Video
        ffmpeg

        # X11
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

        # Wayland
        wayland
        wayland-protocols

        # Graphics
        mesa
        vulkan-loader
        vulkan-headers

        # Common GUI deps
        gtk3
        gtk4

        # Misc
        webkitgtk_4_1
        glib
        dbus
        libxkbcommon
        udev
        libGL
      ];

      pythonPackages = with pkgs; [
        python3

        python3Packages.virtualenv
        python3Packages.setuptools
        python3Packages.wheel
        python313Packages.pip

        black
        ruff
        pyright

        gcc
        openssl
        zlib
      ];
      shellHookSuffix = ''
        if [[ -n "''${ROFI_TMUX_CMD:-}" ]]; then
          clear
          eval "$ROFI_TMUX_CMD"
          unset ROFI_TMUX_CMD
        fi
      '';
    in {
      rust-go = pkgs.mkShellNoCC {
        packages = rustGoPackages;

        shellHook =
          ''
            export RUST_BACKTRACE=1
            export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1

            echo "Rust: $(rustc --version)"
            echo "Go:   $(go version)"
          ''
          + shellHookSuffix;
      };
      rust-go-android = pkgs.mkShellNoCC {
        packages =
          rustGoPackages
          ++ (with pkgs; [
            android-tools
            jdk21
            gradle
          ]);

        shellHook =
          ''
            export RUST_BACKTRACE=1
            export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1

            echo "Rust: $(rustc --version)"
            echo "Go:   $(go version)"
            echo "Adb:   $(adb version)"
          ''
          + shellHookSuffix;
      };
      python = pkgs.mkShellNoCC {
        packages = pythonPackages;
        shellHook =
          ''
            echo "Python: $(python --version)"
            echo "Pip:    $(python -m pip --version)"
          ''
          + shellHookSuffix;
      };
      python-ml = pkgs.mkShellNoCC {
        packages =
          pythonPackages
          ++ (with pkgs; [
            (python3.withPackages (ps:
              with ps; [
                numpy
                pandas
                matplotlib
                scikit-learn
                jupyter
                notebook
                scipy
              ]))
          ]);

        shellHook =
          ''
            echo "Python ML Environment"
            echo "Python: $(python --version)"
          ''
          + shellHookSuffix;
      };
    };
  };
}
