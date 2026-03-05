
{ config, pkgs, ... }:
{
    imports = [
        ./locals.nix
        ./home.nix
    ];
    
    environment.systemPackages = with pkgs; [
        discord
        usbimager
    ];
}