{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.oracle-database;
in {
  options = {
    services.oracle-database = {
      enable = lib.mkEnableOption (lib.mdDoc "Oracle Database");
      package = lib.mkPackageOption pkgs "oracle-database" {};
      port = lib.mkOption {
        default = 1521;
        description = "The TCP port database will listen on.";
        type = lib.types.port;
      };
      openFirewall = lib.mkOption {
        default = false;
        description = "Open ports in the firewall";
        type = lib.types.bool;
      };
      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        description = "Path to file containing the Oracle Database SYS, SYSTEM and PDB_ADMIN password.";
      };

      charset = lib.mkOption {
        default = "AL32UTF8";
        description = "The character set to use when creating the database";
        type = lib.types.str;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."oratab" = {
      mode = "0755";
      text = ''
        free:/var/lib/oracle-database/oradata/free:N
      '';
    };

    environment.etc."sysconfig/oracle-free-26ai.conf".text = ''
      # LISTENER PORT used Database listener, Leave empty for automatic port assignment
      LISTENER_PORT=${toString cfg.port}

      # Character set of the database
      CHARSET=${cfg.charset}

      # Database file directory
      # If not specified, database files are stored under Oracle base/oradata
      DBFILE_DEST=/var/lib/oracle-database/oradata

      # DB Domain name
      DB_DOMAIN=

      # SKIP Validations, memory, space
      SKIP_VALIDATIONS=false
    '';

    systemd.services.oracle-database = {
      description = "Oracle Database";
      wantedBy = ["oracle-database.target"];
      after = ["network.target"];
      preStart = ''
        mkdir -p $STATE_DIRECTORY/oradata
        cat /etc/oratab
        cat /etc/sysconfig/oracle-free-26ai.conf
      '';
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/dbstart /var/lib/oracle-database/oradata";
        StateDirectory = "oracle-database";
        DynamicUser = true;
        PrivateTmp = "yes";
        Restart = "on-failure";
        Environment = [];
      };
    };

    systemd.targets."oracle-database" = {
      description = "Oracle Database Target";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
    };
  };
}
