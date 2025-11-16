{ stdenv, lib }:
let
  fs = lib.fileset;
  sourceFiles = ./setup;
in

# Include all files in the setup folder
stdenv.mkDerivation {
  name = "setup";
  src = fs.toSource {
    root = ./.;
    fileset = sourceFiles;
  };  
  postInstall = ''
    mkdir $out
    cp -v -rf ./setup $out

    #$out/setup/install.sh
  '';
}