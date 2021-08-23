{ pkgs ? import <nixpkgs> { } }:
let
  inherit (pkgs) lib stdenv maven;
in
stdenv.mkDerivation {
  name = "maven-repository";
  buildInputs = with pkgs; [ maven ];
  src = pkgs.fetchFromGitHub {
    owner = "decentralized-identity";
    repo = "universal-resolver";
    rev = "5c2147f7992dd2c622aaf659309131e4cb881c05";
    sha256 = "0y1jg5aybnkw450k14wpy92mgmnnvr1ayym98a70nx3fbjgad4md";
  };

  buildPhase = ''
    mvn package -Dmaven.repo.local=$out
  '';

  # keep only *.{pom,jar,sha1,nbm} and delete all ephemeral files with lastModified timestamps inside
  installPhase = ''
    find $out -type f \
      -name \*.lastUpdated -or \
      -name resolver-status.properties -or \
      -name _remote.repositories \
      -delete
  '';

  # don't do any fixup
  dontFixup = true;
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  # replace this with the correct SHA256
  outputHash = "sha256-M3VDlwQM6cnkJKy3i22YTzs1cPKJ0Dr4ypJpimQ+tmM=";
}
