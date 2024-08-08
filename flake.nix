{
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/staging-next";

		flake-compat = {
			url = "github:nix-community/flake-compat";
			flake = false;
		};
	};

	outputs = { self, nixpkgs, ... }: let
		forAllSystems = nixpkgs.lib.genAttrs [
			"x86_64-linux" "aarch64-linux"
			"x86_64-darwin" "aarch64-darwin"
			"riscv64-linux" "riscv32-linux"
			"x86_64-freebsd" "riscv64-freebsd"
		];
	in {
		lib = {
			packagesFor = pkgs: import ./pkgs {
				inherit pkgs;
			};
		};

		packages = forAllSystems (system: self.lib.packagesFor nixpkgs.legacyPackages.${system});

		overlays = {
			default = final: prev: import ./pkgs {
				inherit final prev;
			};
		};

		nixosModules = {
			default = import ./nixos { cosmicOverlay = self.overlays.default; };
		};

		legacyPackages = forAllSystems (system: let lib = nixpkgs.lib; pkgs = nixpkgs.legacyPackages.${system}; in {
			update = pkgs.writeShellApplication {
				name = "cosmic-unstable-update";

				text = lib.concatStringsSep "\n" (lib.mapAttrsToList (attr: drv:
					if drv ? updateScript && (lib.isList drv.updateScript) && (lib.length drv.updateScript) > 0
						then lib.escapeShellArgs (drv.updateScript ++ lib.optionals (lib.match "nix-update|.*/nix-update" (lib.head drv.updateScript) != null) [ "--version" "branch=HEAD" "--commit" attr ])
						else builtins.toString drv.updateScript or "") self.packages.${system});
			};
		});
	};
}
