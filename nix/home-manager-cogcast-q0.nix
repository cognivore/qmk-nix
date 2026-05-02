# home-manager module: services.cogcast-q0
#
# Long-running bridge daemon between a `cogworkd` instance and a Keychron
# Q0 Max running cogcast firmware. Subscribes to cogworkd's SSE lifecycle
# stream, paints LEDs over raw HID; reads slot keypresses from the
# keyboard, POSTs trigger requests back to cogworkd.
#
# Pairs with `services.cogworkd` from clawed-cogworker — but doesn't
# depend on it; the bridge talks to whatever URL you point it at.

flake: { config, lib, pkgs, ... }:

let
  cfg = config.services.cogcast-q0;
  pkg =
    if cfg.package != null
    then cfg.package
    else flake.packages.${pkgs.stdenv.hostPlatform.system}.cogcast-q0;
  homeDir = config.home.homeDirectory;

  isDarwin = pkgs.stdenv.isDarwin;

  bridgeExec = lib.concatStringsSep " " [
    "${pkg}/bin/cogcast-q0"
    "--daemon"     cfg.daemon
    "--slots-toml" cfg.slotsToml
  ];
in
{
  options.services.cogcast-q0 = {
    enable = lib.mkEnableOption "cogcast-q0 RAW HID bridge for Keychron Q0 Max";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The cogcast-q0 package to use. Defaults to the qmk-nix flake output.";
    };

    daemon = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:7878";
      description = "Base URL of the cogworkd daemon to subscribe to and POST triggers against.";
    };

    slotsToml = lib.mkOption {
      type = lib.types.str;
      default = "${homeDir}/.config/cogworkd/slots.toml";
      description = ''
        Path to the same slots.toml that cogworkd reads. Used by the bridge
        to map slot_id → key_name → LED index.
      '';
    };

    rustLog = lib.mkOption {
      type = lib.types.str;
      default = "info,cogcast_q0=info,warn";
      description = "RUST_LOG environment variable for the bridge.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home.packages = [ pkg ];
    }

    (lib.mkIf isDarwin {
      launchd.agents.cogcast-q0 = {
        enable = true;
        config = {
          Label = "com.cognivore.cogcast-q0";
          ProgramArguments = lib.splitString " " bridgeExec;
          RunAtLoad = true;
          KeepAlive = {
            SuccessfulExit = false;
            Crashed = true;
          };
          ThrottleInterval = 5;
          StandardOutPath = "${homeDir}/Library/Logs/cogcast-q0.stdout.log";
          StandardErrorPath = "${homeDir}/Library/Logs/cogcast-q0.stderr.log";
          EnvironmentVariables = {
            HOME = homeDir;
            RUST_LOG = cfg.rustLog;
            PATH = "${config.home.profileDirectory}/bin:/usr/local/bin:/usr/bin:/bin";
          };
        };
      };
    })

    (lib.mkIf (!isDarwin) {
      systemd.user.services.cogcast-q0 = {
        Unit = {
          Description = "cogcast-q0 — Q0 Max ↔ cogworkd raw-HID bridge";
          After = [ "network-online.target" ];
        };
        Service = {
          ExecStart = bridgeExec;
          Restart = "on-failure";
          RestartSec = "5s";
          Environment = [
            "RUST_LOG=${cfg.rustLog}"
            "PATH=${config.home.profileDirectory}/bin:/usr/local/bin:/usr/bin:/bin"
          ];
        };
        Install.WantedBy = [ "default.target" ];
      };
    })
  ]);
}
