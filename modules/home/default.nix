
{ config, pkgs, ... }:
{
    imports = [
        # ./hyprland.nix
        ./locals.nix
        ./home.nix
        # ./slippi.nix
        # ./dolphin.nix
    ];
    
    environment.systemPackages = with pkgs; [
        discord
    ];
}