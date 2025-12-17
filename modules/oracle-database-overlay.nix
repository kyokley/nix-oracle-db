{ ... }:
{
  nixpkgs.overlays = [
    (import ../overlays/oracle-database.nix)
  ];
}
