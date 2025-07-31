{
  description = "A NATS-based file puller service.";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }@inputs:

    (flake-utils.lib.eachDefaultSystem (
      system:

      let
        pkgs = nixpkgs.legacyPackages.${system};
        # The current default sdk for macOS fails to compile go projects, so we use a newer one for now.
        # This has no effect on other platforms.
      in
      {

        # import nixpkgs {
        #   inherit system;
        #   # overlays = [ self.overlays.default ];
        # };

        packages.default = pkgs.callPackage ./package.nix { };

        devShells.default = pkgs.callPackage ./shell.nix { };
      }
    ))
    // {
      nixosModules.default = import ./services.nix inputs;
    };
}
