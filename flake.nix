{
  description = "Universal Resolver implementation and drivers";

  inputs = {
    utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs";
    mvn2nix.url = "github:fzakaria/mvn2nix";
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

  outputs = { self, nixpkgs, utils, mvn2nix, universal-resolver-src, driver-sov-src, driver-btcr-src }:
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
          inherit (mvn2nix.legacyPackages."${system}") buildMavenRepositoryFromLockFile;
          universal-resolver-repository = buildMavenRepositoryFromLockFile { file = ./universal-resolver-mvn2nix-lock.json; };
          driver-sov-repository = buildMavenRepositoryFromLockFile { file = ./driver-sov-mvn2nix-lock.json; };
          driver-btcr-repository = buildMavenRepositoryFromLockFile { file = ./driver-btcr-mvn2nix-lock.json; };
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
                cp -r sovrin/* -t $out/sovrin
                mkdir -p $out/webapps
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
                cp target/*.war $out/webapps/ROOT.war
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
