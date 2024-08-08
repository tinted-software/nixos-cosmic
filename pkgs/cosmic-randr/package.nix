{ lib
, fetchFromGitHub
, rustPlatform
, stdenv
, just
, uutils-coreutils-noprefix
, pkgconf
, wayland
, nix-update-script
}:

rustPlatform.buildRustPackage {
  pname = "cosmic-randr";
  version = "1.0.0-alpha.1-unstable-2024-07-31";

  src = fetchFromGitHub {
    owner = "pop-os";
    repo = "cosmic-randr";
    rev = "71fabbb382fa8cf750f50fb77c4ba014bff80056";
    hash = "sha256-g9zoqjPHRv6Tw/Xn8VtFS3H/66tfHSl/DR2lH3Z2ysA=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "cosmic-protocols-0.1.0" = "sha256-zWuvZrg39REZpviQPfLNyfmWBzMS7A7IBUTi8ZRhxXs=";
    };
  };

  nativeBuildInputs = [ just pkgconf uutils-coreutils-noprefix ];
  buildInputs = [ wayland ];

  dontUseJustBuild = true;

  justFlags = [
    "--set"
    "prefix"
    (placeholder "out")
    "--set"
    "bin-src"
    "target/${stdenv.hostPlatform.rust.cargoShortTarget}/release/cosmic-randr"
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version-regex" "epoch-(.*)" ];
  };

  meta = with lib; {
    homepage = "https://github.com/pop-os/cosmic-randr";
    description = "Library and utility for displaying and configuring Wayland outputs";
    license = licenses.mpl20;
    maintainers = with maintainers; [ nyanbinary /*lilyinstarlight*/ ];
    platforms = platforms.linux;
    mainProgram = "cosmic-randr";
  };
}
