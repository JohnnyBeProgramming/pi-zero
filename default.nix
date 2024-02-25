{
  system ? builtins.currentSystem,
  sources ? import ./nix/sources.nix,
}:

# Load packages from the source definition
let pkgs = import sources.nixpkgs {
    config = { };
    overlays = [ ];
    inherit system;
  };
  
# Package and built the setup packages
in pkgs.callPackage ./setup.nix { }
