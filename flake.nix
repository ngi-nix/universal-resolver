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
        repository = pkgs.callPackage ./build-maven-repository.nix { };
      in
      rec {
        # `nix build`
        packages.uni-resolver-web = pkgs.stdenv.mkDerivation rec {
          pname = "uni-resolver-web";
          name = "uni-resolver-web";
          version = "0.3-SNAPSHOT";

          src = pkgs.fetchFromGitHub {
            owner = "decentralized-identity";
            repo = "universal-resolver";
            rev = "5c2147f7992dd2c622aaf659309131e4cb881c05";
            sha256 = "0y1jg5aybnkw450k14wpy92mgmnnvr1ayym98a70nx3fbjgad4md";
          };


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

        # `nix run`
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
