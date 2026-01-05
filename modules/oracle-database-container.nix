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
        default = null;
        type = types.nullOr types.path;
        description = "Path to file containing the Oracle Database SYS, SYSTEM and PDB_ADMIN password.";
      };

      openFirewall = mkOption {
        default = false;
        description = "Open ports in the firewall";
        type = types.bool;
      };

      initScript = mkOption {
        default = null;
        description = "Path to file containing initialization commands";
        type = types.nullOr types.path;
      };

      appUser = mkOption {
        default = "some_user";
        description = "Name of database user";
        type = types.str;
      };

      appUserPasswordFile = mkOption {
        default = null;
        type = types.nullOr types.path;
        description = "Path to file containing the Oracle Database password for the appUser";
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
              APP_USER = cfg.appUser;
              APP_USER_PASSWORD_FILE = lib.mkIf (cfg.appUserPasswordFile != null) (toString cfg.appUserPasswordFile);
            };
            ports = ["${cfg.listenAddress}:${toString cfg.port}:1521"];
            volumes = [
              "oracle-volume:/opt/oracle/oradata"
              "${toString cfg.passwordFile}:${toString cfg.passwordFile}"
            ];
          }// {
            volumes = lib.mkIf (cfg.initScript != null) [
              "${toString cfg.initScript}:/container-entrypoint-initdb.d/01_create.sql"
            ];
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
