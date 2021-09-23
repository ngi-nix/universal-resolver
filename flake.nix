{
  description = "Universal Resolver implementation and drivers";

  inputs = {
    utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs";
    universal-resolver-src = {
      url = "github:decentralized-identity/universal-resolver/v0.4.0";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, utils, universal-resolver-src }:
    utils.lib.eachDefaultSystem (
      system:
        let
          pkgs = nixpkgs.legacyPackages."${system}";

          # TODO remove this once [this](https://github.com/NixOS/nixpkgs/pull/132287#pullrequestreview-736233478) gets merged
          modifiedJetty = pkgs.jetty.overrideAttrs (
            oldAttrs: rec {
              installPhase = ''
                mkdir -p $out
                mv bin etc lib modules start.ini start.jar $out
              '';
            }
          );
          generic-repository = pkgs.stdenv.mkDerivation {
            nativeBuildInputs = with pkgs; [ maven ];

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
          };
          universal-resolver-repository = generic-repository.overrideAttrs (
            oldAttrs: {
              name = "universal-resolver-repository";
              src = universal-resolver-src;
              outputHash = "sha256-lnjizQvaz4gRxqQX76ERDxhEN1QH7D5iUEorljDU/ho=";
            }
          );
        in
          rec {
            # `nix build`
            packages.uni-resolver-web = pkgs.stdenv.mkDerivation rec {
              pname = "uni-resolver-web";
              name = "uni-resolver-web";
              version = "0.4.0";

              src = universal-resolver-src;

              buildInputs = with pkgs; [ maven ];

              buildPhase = ''
                echo "Using repository ${universal-resolver-repository}"
                mvn --offline -Dmaven.repo.local=${universal-resolver-repository} package
              '';

              installPhase = ''
                mkdir -p $out/webapps
                cp config.json $out/config.json
                cp uni-resolver-web/target/${pname}-${version}.war $out/webapps/ROOT.war
                cd $out
                ${pkgs.adoptopenjdk-bin}/bin/java -jar ${modifiedJetty}/start.jar --create-startd
                ${pkgs.adoptopenjdk-bin}/bin/java -jar ${modifiedJetty}/start.jar --add-to-start=http,deploy,websocket,ext,jsp,jstl,resources,server
              '';
            };
            defaultPackage = packages.uni-resolver-web;

            # TODO  `nix run`

            # `nix develop`
            devShell = pkgs.mkShell {
              nativeBuildInputs = with pkgs; [ adoptopenjdk-bin maven modifiedJetty ];
            };
          }
    );
}
