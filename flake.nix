{
	inputs = {
		nixpkgs.url = "github:tinted-software/nixpkgs/tinted-staging";

		systems.url = "github:nix-systems/default";
	};

	outputs = { self, systems, nixpkgs, ... }: let
		eachSystem = nixpkgs.lib.genAttrs (import systems);
	in {
		lib = {
			packagesFor = pkgs: import ./pkgs {
				inherit pkgs;
			};
		};

		packages = eachSystem (system: self.lib.packagesFor nixpkgs.legacyPackages.${system});

		overlays = {
			default = final: prev: import ./pkgs {
				inherit final prev;
			};
		};

		nixosModules = {
			default = import ./nixos { cosmicOverlay = self.overlays.default; };
		};

		legacyPackages = eachSystem (system: let lib = nixpkgs.lib; pkgs = nixpkgs.legacyPackages.${system}; in {
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
