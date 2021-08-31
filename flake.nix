{
  description = "A very basic flake";

  outputs = { self, nixpkgs }: {

    packages = {
      x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;
      x86_64-darwin.hello = nixpkgs.legacyPackages.x86_64-darwin.hello;
    };

    defaultPackage = {
      x86_64-linux = self.packages.x86_64-linux.hello;
      x86_64-darwin = self.packages.x86_64-darwin.hello;
    };

  };
}
