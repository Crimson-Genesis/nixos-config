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
  };
}
