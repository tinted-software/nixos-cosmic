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

			vm = nixpkgs.lib.makeOverridable ({ nixpkgs }: let
				nixosConfig = nixpkgs.lib.nixosSystem {
					modules = [
						({ lib, pkgs, modulesPath, ... }: {
							imports = [
								self.nixosModules.default

								"${builtins.toString modulesPath}/virtualisation/qemu-vm.nix"
							];

							services.desktopManager.cosmic.enable = true;
							services.displayManager.cosmic-greeter.enable = true;

							services.flatpak.enable = true;

							environment.systemPackages = [ pkgs.drm_info pkgs.firefox pkgs.cosmic-emoji-picker pkgs.cosmic-tasks ];

							boot.kernelParams = [ "quiet" "udev.log_level=3"	];
							boot.initrd.kernelModules = [ "bochs" ];

							boot.initrd.verbose = false;

							boot.initrd.systemd.enable = true;

							boot.loader.systemd-boot.enable = true;
							boot.loader.timeout = 0;

							boot.plymouth.enable = true;
							boot.plymouth.theme = "nixos-bgrt";
							boot.plymouth.themePackages = [ pkgs.nixos-bgrt-plymouth ];

							services.openssh = {
								enable = true;
								settings.PermitRootLogin = "yes";
							};

							documentation.nixos.enable = false;

							users.mutableUsers = false;
							users.users.root.password = "meow";
							users.users.user = {
								isNormalUser = true;
								password = "meow";
							};

							virtualisation.useBootLoader = true;
							virtualisation.useEFIBoot = true;
							virtualisation.mountHostNixStore = true;

							virtualisation.memorySize = 4096;
							# TODO: below options can be removed once NixOS/nixpkgs#279009 is merged
							virtualisation.qemu.options = [ "-vga none" "-device virtio-gpu-gl-pci" "-display default,gl=on" ];

							virtualisation.forwardPorts = [
								{ from = "host"; host.port = 2222; guest.port = 22; }
							];

							nixpkgs.hostPlatform = system;

							system.stateVersion = lib.trivial.release;
						})
					];
				};
			in nixosConfig.config.system.build.vm // { closure = nixosConfig.config.system.build.toplevel; inherit (nixosConfig) config pkgs; }) { inherit nixpkgs; };
		});

		checks = forAllSystems (system: {
			vm = self.legacyPackages.${system}.vm.closure;
		});
	};
}
