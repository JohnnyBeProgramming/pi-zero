let
  pkgs = import <nixpkgs> {};
in

pkgs.mkShellNoCC {
  # Check required packages and make sure they are available
  packages = with pkgs; [ 
    # Install core packages
    git

    # Development packages
    nodejs
    python3
    go
    #rust
  ];

  # Global environment variables
  GREETING = pkgs.lib.strings.toUpper "Hello, Nix!";

  # Startup script
  shellHook = ''
    echo $GREETING    
  '';


}