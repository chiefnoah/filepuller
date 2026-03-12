{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.filepuller;
in
{
  options.services.filepuller = {
    enable = lib.mkEnableOption "filepuller, a NATS-based file downloading service";

    package = lib.mkPackageOption pkgs "filepuller" {
      default = pkgs.callPackage ./package.nix { };
    };

    nats = {
      url = lib.mkOption {
        type = lib.types.str;
        description = "NATS server URL.";
        example = "tls://nats.example.com";
      };

      caFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to the CA certificate file for TLS validation.";
        example = "/run/secrets/nats-ca.pem";
      };

      certFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to the client certificate file for TLS authentication.";
        example = "/run/secrets/nats-cert.pem";
      };

      keyFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to the client private key file for TLS authentication.";
        example = "/run/secrets/nats-key.pem";
      };
    };

    stream = lib.mkOption {
      type = lib.types.str;
      description = "Name of the JetStream stream.";
      example = "torrents";
    };

    topicBase = lib.mkOption {
      type = lib.types.str;
      description = "Base topic/subject for the stream.";
      example = "torrents";
    };

    consumer = lib.mkOption {
      type = lib.types.str;
      description = "Name of the JetStream consumer.";
      example = "uploaded-torrents";
    };

    bucket = lib.mkOption {
      type = lib.types.str;
      description = "Name of the ObjectStore bucket.";
      example = "torrents";
    };

    destination = lib.mkOption {
      type = lib.types.str;
      description = "Local directory path where downloaded files will be saved.";
      example = "/srv/filepuller/downloads";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to an environment file for additional or override variables. Useful for providing secrets outside the Nix store.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "filepuller";
      description = "User account under which filepuller runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "filepuller";
      description = "Group under which filepuller runs.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = lib.mkIf (cfg.user == "filepuller") {
      isSystemUser = true;
      group = cfg.group;
    };

    users.groups.${cfg.group} = lib.mkIf (cfg.group == "filepuller") { };

    systemd.services.filepuller = {
      description = "A NATS-based file puller";
      after = [
        "network-online.target"
        "nats.service"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        NATS_URL = cfg.nats.url;
        NATS_CA = cfg.nats.caFile;
        NATS_CERT = cfg.nats.certFile;
        NATS_KEY = cfg.nats.keyFile;
        PULLER_STREAM = cfg.stream;
        PULLER_TOPICBASE = cfg.topicBase;
        PULLER_CONSUMER = cfg.consumer;
        PULLER_BUCKET = cfg.bucket;
        PULLER_DESTINATION = cfg.destination;
      };

      serviceConfig =
        {
          Type = "simple";
          ExecStart = lib.getExe cfg.package;
          Restart = "on-failure";
          RestartSec = 5;

          User = cfg.user;
          Group = cfg.group;

          # Hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          ReadWritePaths = [ cfg.destination ];
        }
        // lib.optionalAttrs (cfg.environmentFile != null) {
          EnvironmentFile = cfg.environmentFile;
        };
    };
  };
}
