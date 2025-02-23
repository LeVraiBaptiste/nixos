{ config, pkgs, ... }:

{
    environment.systemPackages = with pkgs; [
        brave
    ];

    # programs.brave = {
    #     enable = true;
    #     extensions = [
    #         # List your desired extension IDs here
    #         # Example: "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
    #         "fdjamakpfbbddfjaooikfcpapjohcfmg" #dashlane
    #     ];
    # };

}