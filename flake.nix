{
  description = "Universal Resolver implementation and drivers";

  inputs = {
    utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs";
    universal-resolver-src = {
      url = "github:decentralized-identity/universal-resolver/v0.4.0";
      flake = false;
    };
    driver-sov-src = {
      url = "github:decentralized-identity/uni-resolver-driver-did-sov/0.2.0";
      flake = false;
    };
    driver-btcr-src = {
      url = "github:decentralized-identity/uni-resolver-driver-did-btcr/0.1.0";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, utils, universal-resolver-src, driver-sov-src, driver-btcr-src }:
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
          driver-sov-repository = generic-repository.overrideAttrs (
            oldAttrs: {
              name = "driver-sov-repository";
              src = driver-sov-src;
              buildPhase = ''
                mvn package -P war -Dmaven.repo.local=$out
              '';
              outputHash = "sha256-Ah5G/eaiXcOfAklodrtf0F5S8+2QaQgtVWPKFlF4Dcg=";
            }
          );
          driver-btcr-repository = generic-repository.overrideAttrs (
            oldAttrs: {
              name = "driver-btcr-repository";
              src = driver-btcr-src;
              buildPhase = ''
                mvn package -Dmaven.repo.local=$out
              '';
              outputHash = pkgs.lib.fakeHash; #"";
            }
          );
        in
          rec {
            # `nix build`
            packages.uni-resolver-web = pkgs.stdenv.mkDerivation rec {
              pname = "uni-resolver-web";
              version = "0.4.0";

              src = universal-resolver-src;

              buildInputs = with pkgs; [ maven ];

              buildPhase = ''
                echo "using repository ${universal-resolver-repository}"
                mvn --offline -Dmaven.repo.local=${universal-resolver-repository} package
              '';

              installPhase = ''
                mkdir -p $out/webapps
                cp config.json $out/config.json
                cp uni-resolver-web/target/*.war $out/webapps/ROOT.war
                cd $out
                ${pkgs.adoptopenjdk-bin}/bin/java -jar ${modifiedJetty}/start.jar --create-startd
                ${pkgs.adoptopenjdk-bin}/bin/java -jar ${modifiedJetty}/start.jar --add-to-start=http,deploy,websocket,ext,jsp,jstl,resources,server
              '';
            };
            packages.driver-sov = pkgs.stdenv.mkDerivation rec {
              pname = "driver-sov";
              version = "0.2.0";

              src = driver-sov-src;

              nativeBuildInputs = with pkgs; [ maven ];

              buildPhase = ''
                echo "using repository ${driver-sov-repository}"
                mvn --offline -Dmaven.repo.local=${driver-sov-repository} package -P war
              '';

              installPhase = ''
                mkdir -p $out/sovrin
                cp -r sovrin $out/sovrin
                mkdir -p $out/webapps
                ls target/
                cp target/*.war $out/webapps/ROOT.war
                cd $out
                ${pkgs.adoptopenjdk-bin}/bin/java -jar ${modifiedJetty}/start.jar --create-startd
                ${pkgs.adoptopenjdk-bin}/bin/java -jar ${modifiedJetty}/start.jar --add-to-start=http,deploy,websocket,ext,jsp,jstl,resources,server
              '';
            };
            packages.driver-btcr = pkgs.stdenv.mkDerivation rec {
              pname = "driver-btcr";
              version = "0.1.0";

              src = driver-btcr-src;

              nativeBuildInputs = with pkgs; [ maven ];

              buildPhase = ''
                echo "using repository ${driver-btcr-repository}"
                mvn --offline -Dmaven.repo.local=${driver-btcr-repository} package -P war
              '';

              installPhase = ''
                mkdir -p $out/webapps
                ls target/
                cp target/*.war -t $out/webapps/ROOT.war
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
