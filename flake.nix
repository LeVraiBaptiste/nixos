{
  description = "NixOS configuration — desktop, laptop, server, remote";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Encrypted secrets (age), decrypted on the target host at activation
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-foreman = {
      url = "github:LeVraiBaptiste/claude-foreman";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gamepad-desktop = {
      url = "github:LeVraiBaptiste/gamepad-desktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Personal values (domain, public IP, identities). The committed default holds
    # placeholders; scripts/rebuild.sh decrypts private/vars.yaml and overrides it.
    private = {
      url = "path:./private/example";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      disko,
      sops-nix,
      zen-browser,
      claude-foreman,
      private,
      ...
    }:
    let
      system = "x86_64-linux";

      # vars.nix + the personal values on top
      vars = nixpkgs.lib.recursiveUpdate (import ./vars.nix) (
        builtins.fromJSON (builtins.readFile "${private}/vars.json")
      );

      # Refuse to build with the placeholders (would deploy example.com / 203.0.113.10)
      guardPlaceholders = {
        assertions = [
          {
            assertion = !vars.placeholder;
            message = "Built with placeholder personal values: use scripts/rebuild.sh (decrypts private/vars.yaml).";
          }
        ];
      };

      pkgs-unstable = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          # (import ./overlays/claude-code.nix)
          (import ./overlays/orca-ide.nix)
        ];
      };

      sharedSpecialArgs = {
        inherit pkgs-unstable inputs vars;
      };
    in
    {
      # Custom packages exposed so `nix-update --flake <name>` can bump them
      packages.${system}.orca-ide = pkgs-unstable.orca-ide;

      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = sharedSpecialArgs;
        modules = [
          ./hosts/desktop
          guardPlaceholders
          home-manager.nixosModules.home-manager
          {
            home-manager.useUserPackages = true;
            home-manager.useGlobalPkgs = true;
          }
        ];
      };

      nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = sharedSpecialArgs;
        modules = [
          ./hosts/laptop
          guardPlaceholders
          home-manager.nixosModules.home-manager
          {
            home-manager.useUserPackages = true;
            home-manager.useGlobalPkgs = true;
          }
        ];
      };

      nixosConfigurations.server = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit vars; };
        modules = [
          ./hosts/server
          guardPlaceholders
          sops-nix.nixosModules.sops
        ];
      };

      nixosConfigurations.remote = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit vars; };
        modules = [
          ./hosts/remote
          guardPlaceholders
          disko.nixosModules.disko
        ];
      };
    };
}
