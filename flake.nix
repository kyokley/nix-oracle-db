{
  description = "Oracle Database";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      imports = [ inputs.flake-parts.flakeModules.easyOverlay ];

      perSystem =
        {
          self',
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = import self.inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.self.overlays.default ];
            config = {
              allowUnfree = true;
            };
          };

          formatter = pkgs.nixfmt-rfc-style;

          packages.oracle-database = pkgs.callPackage ./packages/oracle-database.nix { };
          packages.oracle-database-test = pkgs.testers.runNixOSTest ./tests/integration/oracle-database.nix;
          packages.oracle-database-container-test = pkgs.testers.runNixOSTest ./tests/integration/oracle-database-container.nix;

          checks = {
            # oracle-database = pkgs.testers.runNixOSTest ./tests/integration/oracle-database.nix;
            # oracle-database-container = pkgs.testers.runNixOSTest ./tests/integration/oracle-database-container.nix;

            containerModuleTest = pkgs.testers.runNixOSTest {
              name = "containerModuleTest";
              nodes = {
                db = {
                  imports = [
                    ./modules/oracle-database-container.nix
                  ];

                  services.oracle-database-container = {
                    enable = true;
                    passwordFile = toString (builtins.toFile "password.txt" ''
                    password
                    '');
                    # Explicitly use the package from the nix-oracle-db flake,
                    # avoiding reliance on pkgs having an overlay.
                    # package = self'.packages.oracle-database;
                    openFirewall = true;
                    initScriptDir = null;
                  };
                };
              };
              testScript = ''
                start_all()
              '';
            };

            # moduleTest = pkgs.testers.runNixOSTest {
            #   name = "moduleTest";
            #   nodes = {
            #     db = {
            #       imports = [
            #         ./modules/oracle-database.nix
            #       ];
            #       environment.systemPackages = [
            #         pkgs.vim
            #       ];

            #       services.oracle-database = {
            #         enable = true;
            #         passwordFile = ./password.txt;
            #         # Explicitly use the package from the nix-oracle-db flake,
            #         # avoiding reliance on pkgs having an overlay.
            #         # package = self'.packages.oracle-database;
            #         openFirewall = true;
            #       };
            #     };
            #   };
            #   testScript = ''
            #     start_all()
            #   '';
            # };
          };

          overlayAttrs = {
            oracle-database = self'.packages.oracle-database;
          };
        };

      flake = {
        nixosModules.oracle-database = import ./modules/oracle-database.nix;
        nixosModules.oracle-database-container = import ./modules/oracle-database-container.nix;

        # New: expose the overlay and module via flake outputs
        overlays.oracle-database = import ./overlays/oracle-database.nix;
        nixosModules.oracle-database-overlay = import ./modules/oracle-database-overlay.nix;
      };
    };
}
