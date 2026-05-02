{ lib, rustPlatform, pkg-config, hidapi, libusb1, stdenv }:

rustPlatform.buildRustPackage {
  pname = "cogcast-q0";
  version = "0.1.0";

  src = lib.cleanSource ./..;
  cargoLock.lockFile = ../Cargo.lock;

  nativeBuildInputs = [ pkg-config ];

  # hidapi is the only non-Rust dep. On Linux it pulls in libusb; on macOS
  # the IOKit/AppKit framework links come from the SDK automatically (the
  # legacy `darwin.apple_sdk.frameworks.*` shim was removed in nixpkgs and
  # isn't needed any more — see <https://nixos.org/manual/nixpkgs/stable/#sec-darwin-legacy-frameworks>).
  buildInputs = [ hidapi ]
    ++ lib.optionals stdenv.isLinux [ libusb1 ];

  meta = {
    description = "RAW HID bridge between cogworkd and a Keychron Q0 Max running cogcast firmware";
    license = lib.licenses.mit;
    mainProgram = "cogcast-q0";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
