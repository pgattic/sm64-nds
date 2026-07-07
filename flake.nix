{
  description = "SM64 Nintendo DS port build";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devkitNix.url = "github:bandithedoge/devkitNix";

    baserom-us = {
      url = "path:./baserom.us.z64";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      devkitNix,
      baserom-us,
      ...
    } @ inputs:
    let
      buildSystem = "x86_64-linux";

      pkgs = import nixpkgs {
        system = buildSystem;
        overlays = [ devkitNix.overlays.default ];
      };

      devkitARM = pkgs.devkitNix.devkitARM.overrideAttrs (_: {
        name = "devkitARM-20240511";
        src = pkgs.dockerTools.pullImage (pkgs.lib.importJSON ./nix/devkitarm-20240511.json);
        buildPhase = ''
          tar -xf $src

          for archive in $(find *.tar)
          do
            tar -xf $archive
          done

          find opt -name '.wh.*' -delete

          mkdir -p $out
          cp -r opt $out/opt
          ln -sf $out/opt/devkitpro/tools/bin $out/bin
          rm -f $out/opt/devkitpro/pacman/share/pacman/keyrings
        '';
      });

      sm64-nds = pkgs.stdenv.mkDerivation {
        pname = "sm64-nds";
        version = "us";

        src = ./.;

        nativeBuildInputs = with pkgs; [
          armips
          devkitARM
          gnumake
          python3
          sox
          which
        ];

        env = rec {
          DEVKITPRO = "${devkitARM}/opt/devkitpro";
          DEVKITARM = "${DEVKITPRO}/devkitARM";
        };

        dontConfigure = true;
        enableParallelBuilding = true;

        buildPhase = ''
          runHook preBuild

          cp ${baserom-us} baserom.us.z64
          make VERSION=us COMPARE=0 -j$NIX_BUILD_CORES

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p $out
          cp build/us_nds/sm64.us.nds $out/

          runHook postInstall
        '';
      };

    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem = {
        packages = {
          default = sm64-nds;
          sm64-nds = sm64-nds;
        };
      };
    };
}
