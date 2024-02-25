{
  system ? builtins.currentSystem,
  sources ? import ./nix/sources.nix,
}:

let 
  # Load packages from the source definition
  pkgs = import sources.nixpkgs {
    config = { };
    overlays = [ ];
    inherit system;
  };

  # Import additional setup packages and payloads
  setup = pkgs.callPackage ./setup.nix {};
  example = pkgs.callPackage ./nix/example/hello.nix {};

in rec {
  inherit setup;

  # Define a shell with the setup loaded
  shell = pkgs.mkShellNoCC {
    inputsFrom = [ setup ];
  };
}