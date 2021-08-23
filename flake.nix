{
  description = ""; # TODO

  inputs = {
    utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";
        src = pkgs.fetchFromGitHub {
          owner = "decentralized-identity";
          repo = "universal-resolver";
          rev = "5c2147f7992dd2c622aaf659309131e4cb881c05";
          sha256 = "0y1jg5aybnkw450k14wpy92mgmnnvr1ayym98a70nx3fbjgad4md";
        };
        repository = pkgs.stdenv.mkDerivation {
          name = "maven-repository";
          buildInputs = with pkgs; [ maven ];

          inherit src;

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
        };
      in
      rec {
        # `nix build`
        packages.uni-resolver-web = pkgs.stdenv.mkDerivation rec {
          pname = "uni-resolver-web";
          name = "uni-resolver-web";
          version = "0.3-SNAPSHOT";

          inherit src;

          buildInputs = with pkgs; [ maven ];

          buildPhase = ''
            echo "Using repository ${repository}"
            mvn --offline -Dmaven.repo.local=${repository} package
          '';

          installPhase = ''
            mkdir -p $out/webapps
            cp config.json $out/config.json
            cp uni-resolver-web/target/${pname}-${version}.war $out/webapps/ROOT.war
            cd $out
            ${pkgs.adoptopenjdk-bin}/bin/java -jar ${pkgs.jetty}/start.jar --create-startd
            ${pkgs.adoptopenjdk-bin}/bin/java -jar ${pkgs.jetty}/start.jar --add-to-start=http,deploy,websocket,ext,jsp,jstl,resources,server
          '';
        };
        defaultPackage = packages.uni-resolver-web;

        # FIXME `nix run`
        apps.uni-resolver-web = utils.lib.mkApp {
          drv = packages.uni-resolver-web;
        };
        defaultApp = apps.uni-resolver-web;

        # `nix develop`
        devShell = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ adoptopenjdk-bin maven jetty ];
        };
      });
}