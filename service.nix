{ systemd, pkgs }:
let
    package = pkgs.callPackage ./package.nix;
in
{
    systemd.user.services.filepuller = {
        enable = false;
        after = [ "network.target" "nats.service"];
        wantedBy = [ "default.target"];
        description = "A NATS-based file puller";
        serviceConfig = {
            Type = "simple";
            ExecStart = "${package}/bin/filepuller";
        };
    };
}
