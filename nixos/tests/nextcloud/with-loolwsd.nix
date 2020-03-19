import ../make-test-python.nix ({ pkgs, ...}: let
  adminpass = "hunter2";
  adminuser = "custom-admin-username";
in {
  name = "nextcloud-with-loolwsd";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ mmilata ];
  };

  nodes = {
    # The only thing the client needs to do is download a file.
    client = { ... }: {};

    nextcloud = { config, pkgs, ... }: {
      virtualisation.diskSize = 3072;
      virtualisation.memorySize = 1024;

      networking.firewall.allowedTCPPorts = [ 80 ];

      services.nextcloud = {
        enable = true;
        hostName = "nextcloud";
        nginx.enable = true;
        config = {
          inherit adminuser adminpass;
        };
      };

      services.loolwsd = {
        enable = true;
        proxy.enable = true;
        proxy.hostname = "nextcloud";
      };

      services.nginx.virtualHosts.nextcloud = {
        forceSSL = false;
        enableACME = false;
      };

      services.journald.rateLimitBurst = 20000;
    };
  };

  testScript = let
    configurePlugin = pkgs.writeScript "configure-plugin" ''
      #!${pkgs.stdenv.shell}

      set -euo pipefail

      nextcloud-occ app:install richdocuments
      nextcloud-occ config:app:set richdocuments wopi_url --value 'http://nextcloud'
      nextcloud-occ config:app:set richdocuments public_wopi_url --value 'http://nextcloud'
      nextcloud-occ config:app:set richdocuments disable_certificate_verification --value 'yes'
    '';
  in ''
    start_all()
    nextcloud.wait_for_unit("multi-user.target")
    nextcloud.wait_for_unit("loolwsd")
    nextcloud.succeed("${configurePlugin}")
  '';
})
