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

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-foreman = {
      url = "github:LeVraiBaptiste/claude-foreman";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    paseo = {
      url = "github:getpaseo/paseo";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, disko, zen-browser, claude-foreman, paseo, ... }:
    let
      system = "x86_64-linux";

      pkgs-unstable = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (import ./overlays/claude-code.nix)
        ];
      };

      sharedSpecialArgs = {
        inherit pkgs-unstable inputs;
      };
    in
    {
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = sharedSpecialArgs;
        modules = [
          ./hosts/desktop
          paseo.nixosModules.default
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
          paseo.nixosModules.default
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
        ];
      };

      nixosConfigurations.remote = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          ./hosts/remote
        ];
      };
    };
}
