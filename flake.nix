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

    # Private repo — cloned over SSH with the user's key at evaluation time,
    # so rebuild remote without `sudo` in front (see CLAUDE.md)
    factory = {
      url = "git+ssh://git@github.com/LeVraiBaptiste/factory";
      inputs.nixpkgs.follows = "nixpkgs";
    };

};

  outputs = inputs@{ self, nixpkgs, home-manager, disko, sops-nix, zen-browser, claude-foreman, factory, ... }:
    let
      system = "x86_64-linux";

      pkgs-unstable = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          # (import ./overlays/claude-code.nix)
          (import ./overlays/orca-ide.nix)
        ];
      };

      sharedSpecialArgs = {
        inherit pkgs-unstable inputs;
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
          home-manager.nixosModules.home-manager
          {
            home-manager.useUserPackages = true;
            home-manager.useGlobalPkgs = true;
          }
        ];
      };

      nixosConfigurations.server = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/server
          sops-nix.nixosModules.sops
        ];
      };

      nixosConfigurations.remote = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/remote
          disko.nixosModules.disko
          factory.nixosModules.default
        ];
      };
    };
}
