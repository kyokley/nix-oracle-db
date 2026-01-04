{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;

  cfg = config.services.oracle-database-container;
in {
  options = {
    services.oracle-database-container = {
      enable = lib.mkEnableOption "the Oracle Database server";

      port = mkOption {
        default = 1521;
        description = "The TCP port database will listen on.";
        type = types.port;
      };

      listenAddress = mkOption {
        default = "127.0.0.1";
        description = "The TCP ip database will listen on.";
        type = types.str;
      };

      version = mkOption {
        default = "latest-faststart";
        description = "The version of the Oracle Database server to use.";
        type = types.str;
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        description = "Path to file containing the Oracle Database SYS, SYSTEM and PDB_ADMIN password.";
      };

      openFirewall = mkOption {
        default = false;
        description = "Open ports in the firewall";
        type = types.bool;
      };

      initScriptDir = mkOption {
        description = "Path to directory containing initialization scripts";
        type = types.nullOr types.path;
      };
    };
  };

  config = let
    image = "gvenzl/oracle-free:${cfg.version}";
  in
    lib.mkIf cfg.enable {
      virtualisation = {
        diskSize = 40240;
        oci-containers.containers = {
          oracledb = {
            inherit image;
            environment = {
              ORACLE_PASSWORD_FILE = lib.mkIf (cfg.passwordFile != null) (toString cfg.passwordFile);
            };
            ports = ["${cfg.listenAddress}:${toString cfg.port}:1521"];
            volumes =
              [
                "oracle-volume:/opt/oracle/oradata"
                "${toString cfg.passwordFile}:${toString cfg.passwordFile}"
              ]
              // lib.mkIf (cfg.initScriptDir != null) ["${toString cfg.initScriptDir}:/container-entrypoint-initdb.d"];
          };
        };
        podman = {
          enable = true;
          autoPrune.enable = true;
          defaultNetwork.settings = {
            dns_enabled = true;
            ipv6_enabled = true;
          };
        };
      };

      networking.firewall = mkIf cfg.openFirewall {
        allowedTCPPorts = [cfg.port];
        allowedUDPPorts = [53];
      };
    };
}
