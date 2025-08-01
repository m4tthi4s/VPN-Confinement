{ lib, ... }:
let
  inherit (lib) mkOption mkRenamedOptionModule mkIf;
  inherit (lib.types) attrsOf submodule bool str;
in {
  options.systemd.services = mkOption {
    type = attrsOf (submodule ({ name, config, ... }: {
      options.vpnConfinement = {
        enable = mkOption {
          type = bool;
          default = false;
          description = ''
            Whether to confine the systemd service in a
            networking namespace which routes traffic through a
            VPN tunnel and forces a specified DNS.
          '';
        };
        vpnNamespace = mkOption {
          type = str;
          default = null;
          example = "wg";
          description = ''
            Name of the VPN networking namespace to
            use for the systemd service.
          '';
        };
      };

      imports = [
        (mkRenamedOptionModule
          [ "vpnconfinement" "enable" ]
          [ "vpnConfinement" "enable" ]
        )
        (mkRenamedOptionModule
          [ "vpnconfinement" "vpnnamespace" ]
          [ "vpnConfinement" "vpnNamespace" ]
        )
      ];

      config = let
        vpn = config.vpnConfinement.vpnNamespace;
      in mkIf config.vpnConfinement.enable {
        bindsTo = [ "${vpn}.service" ];
        after = [ "${vpn}.service" ];

        serviceConfig = {
          NetworkNamespacePath = "/run/netns/${vpn}";

          InaccessiblePaths = [
            "/run/nscd"
            "/var/run/nscd"
            "/run/resolvconf"
            "/var/run/resolvconf"
          ];

          TemporaryFileSystem = [
              "/run/nscd:ro"
              "/var/run/nscd:ro"
              "/run/resolvconf:ro"
              "/var/run/resolvconf:ro"
          ];

          BindReadOnlyPaths = [
            "/etc/netns/${vpn}/resolv.conf:/etc/resolv.conf:norbind"
            "/etc/netns/${vpn}/nsswitch.conf:/etc/nsswitch.conf:norbind"
          ];

          NoNewPrivileges = true;
          RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
        };
      };
    }));
  };
}
