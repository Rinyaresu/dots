{
  flake.modules.nixos.pihole =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.pihole-ftl;
      nativeSetup =
        import (pkgs.path + "/nixos/modules/services/networking/pihole-ftl-setup-script.nix")
          {
            inherit
              cfg
              config
              lib
              pkgs
              ;
          };
    in
    {
      key = "${__curPos.file}#nixos.pihole";

      assertions = [
        {
          assertion =
            !cfg.settings.dhcp.active
            && !cfg.settings.ntp.ipv4.active
            && !cfg.settings.ntp.ipv6.active
            && !cfg.settings.ntp.sync.active;
          message = "Pi-hole must not provide DHCP or NTP or synchronize the host clock.";
        }
        {
          assertion =
            config.systemd.services.pihole-ftl.serviceConfig.LoadCredential
            == [ "admin-hash:/var/lib/pihole-secrets/admin-hash" ];
          message = "Pi-hole must load its administrative hash from the external credential file.";
        }
        {
          assertion =
            cfg.settings.misc.readOnly
            &&
              config.systemd.services.pihole-ftl.serviceConfig.AmbientCapabilities == [ "CAP_NET_BIND_SERVICE" ]
            &&
              config.systemd.services.pihole-ftl.serviceConfig.CapabilityBoundingSet
              == [ "CAP_NET_BIND_SERVICE" ];
          message = "Pi-hole FTL needs read-only settings and only CAP_NET_BIND_SERVICE.";
        }
      ];

      environment.systemPackages = [
        (pkgs.writeScriptBin "pihole-admin-hash" (
          builtins.replaceStrings
            [ "@python@" "@ftl@" ]
            [ "${pkgs.python3}/bin/python3" (lib.getExe config.services.pihole-ftl.package) ]
            (builtins.readFile ./admin-hash.py)
        ))
      ];

      services.pihole-ftl = {
        enable = true;
        # Upstream api.sh puts its CLI token and session SID in curl argv.
        # Pass these through anonymous pipes instead, without changing the API.
        piholePackage = pkgs.pihole.overrideAttrs (old: {
          # The outer installPhase copies $src, not the unpacked tree.
          # Patch the installed tree before the original resholve preFixup.
          preFixup = ''
            (cd "$out"; ${pkgs.patch}/bin/patch -p1 < ${./api-no-argv-secrets.patch})
            ${pkgs.patch}/bin/patch -d "$out/share/pihole/advanced/Scripts" -p1 < ${./gravity-safe-update.patch}
            substituteInPlace "$out/share/pihole/advanced/Scripts/gravity.sh" \
              --replace-fail '@awk@' '${lib.getExe pkgs.gawk}' \
              --replace-fail '@flock@' '${lib.getExe' pkgs.util-linux "flock"}'
          ''
          + old.preFixup;
        });
        privacyLevel = 3;
        # No global firewall openings: each consumer selects its trusted network.
        settings = {
          dns = {
            upstreams = [
              "1.1.1.1"
              "1.0.0.1"
            ];
            listeningMode = "LOCAL";
            blocking.mode = "NULL";
          };
          dhcp.active = false;
          ntp = {
            ipv4.active = false;
            ipv6.active = false;
            sync.active = false;
          };
          resolver = {
            resolveIPv4 = false;
            resolveIPv6 = false;
          };
          database.maxDBdays = 7;
          misc.nice = 0;
          webserver.api.cli_pw = true;
          webserver.session.restore = false;
        };
      };
      services.pihole-web = {
        enable = true;
        ports = [ "127.0.0.1:8080" ];
      };

      # Load only a password HASH, never a password, from outside the Nix store.
      # Missing credentials prevent startup rather than expose an unauthenticated API.
      # Core's reload commands use this hard-coded path; FTL needs a writable PID.
      systemd.tmpfiles.rules = [
        "L+ /run/pihole-FTL.pid - - - - /run/pihole-cli/FTL.pid"
      ];
      systemd.services.pihole-ftl-setup = {
        requires = [ "pihole-ftl.service" ];
        after = [ "pihole-ftl.service" ];
        serviceConfig = {
          LimitCORE = 0;
          MemorySwapMax = 0;
        };
        # The pinned module POSTs existing lists again and reports duplicate errors.
        # Retain upstream bootstrap, but skip already registered URLs and explicitly
        # reload the current FTL after the atomic gravity DB swap (also after crashes).
        script = lib.mkForce (
          ''
            ftlPID() {
              local pid
              pid=$(systemctl show --property MainPID --value pihole-ftl.service)
              if ! [[ "$pid" =~ ^[0-9]+$ ]] || (( pid <= 1 )); then
                echo 'FTL has no valid MainPID; refusing to signal' >&2
                return 1
              fi
              printf '%s' "$pid"
            }
          ''
          +
            builtins.replaceStrings
              [
                ''type=$($jq -r '.type' <<< "$payload")''
                "exit $any_failed"
                ''"$(systemctl show --property MainPID --value pihole-ftl.service)"''
              ]
              [
                ''
                  type=$($jq -r '.type' <<< "$payload")
                  local address existing
                  address=$($jq -r '.address' <<< "$payload")
                  existing=$(GetFTLData "lists?type=$type")
                  if ! $jq -e 'type == "object" and (.lists | type == "array")' <<< "$existing" >/dev/null; then
                    echo 'Invalid list API response; refusing to mutate gravity' >&2
                    return 1
                  fi
                  if [[ "$address" == "''${PIHOLE_MANAGED_HOSTS_URL:-}" ]]; then
                    local legacy
                    legacy=$($jq -r '
                      .lists[] | select(.comment == "StevenBlack unified hosts snapshot (35c74714)")
                      | .address | select(test("^file:///nix/store/[a-z0-9]{32}-hosts$"))
                    ' <<< "$existing")
                    if [[ -n "$legacy" ]] && [ "$($jq '.lists | length' <<< "$existing")" = 1 ]; then
                      # Keep the id, group assignments and active domains even if the new source fails.
                      ${lib.getExe pkgs.sqlite} -bail -cmd '.timeout 5000' '${cfg.settings.files.gravity}' \
                        "UPDATE adlist SET address='$address', comment='StevenBlack Unified Hosts' WHERE address='$legacy';"
                      return
                    fi
                    if ! $jq -e --arg url "$address" 'all(.lists[]; .address == $url and .enabled == true)' <<< "$existing" >/dev/null; then
                      echo 'Unexpected blocklist configuration; refusing to replace existing lists' >&2
                      return 1
                    fi
                  fi
                  if $jq -e --arg address "$address" 'any(.lists[]?; .address == $address)' <<< "$existing" >/dev/null; then
                    echo "List already registered: $address"
                    return
                  fi
                ''
                ''
                  ${pkgs.procps}/bin/kill -s RTMIN "$(ftlPID)"
                  exit $any_failed
                ''
                ''"$(ftlPID)"''
              ]
              nativeSetup
        );
      };
      systemd.services.pihole-ftl = {
        serviceConfig = {
          LoadCredential = [ "admin-hash:/var/lib/pihole-secrets/admin-hash" ];
          RuntimeDirectory = "pihole-cli";
          RuntimeDirectoryMode = "0700";
          # Type=simple orders setup after fork, not after FTL installs its
          # reload signal handler. Wait for its loopback API before setup can
          # bootstrap gravity and deliver SIGRTMIN to the main process.
          ExecStartPost = [
            (pkgs.writeShellScript "pihole-ftl-await-api" ''
              for _ in {1..30}; do
                if status=$(${lib.getExe pkgs.curl} --noproxy '*' --silent \
                  --connect-timeout 0.5 --max-time 0.5 --output /dev/null \
                  --write-out '%{http_code}' http://127.0.0.1:8080/api/auth); then
                  case "$status" in 200|401) exit 0 ;; esac
                fi
                ${pkgs.coreutils}/bin/sleep 0.5
              done
              echo 'FTL loopback API did not become ready; refusing to start setup' >&2
              exit 1
            '')
          ];
          ExecStartPre = [
            (pkgs.writeShellScript "pihole-ftl-validate-credential" ''
              set -euo pipefail
              hash=$(< "$CREDENTIALS_DIRECTORY/admin-hash")
              pattern='^\$BALLOON-SHA256\$v=1\$s=1024,t=32\$[A-Za-z0-9+/]{21}[AQgw]==\$[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=$'
              if ! [[ "$hash" =~ $pattern ]]; then
                echo 'Missing or invalid Pi-hole password hash' >&2
                exit 1
              fi
            '')
          ];
          ExecStart = lib.mkForce (
            pkgs.writeShellScript "pihole-ftl-start" ''
              set -euo pipefail
              hash=$(< "$CREDENTIALS_DIRECTORY/admin-hash")
              # The upstream CLI needs an ephemeral token. Keep it in tmpfs only.
              ${pkgs.coreutils}/bin/ln -sfn /run/pihole-cli/cli_pw /etc/pihole/cli_pw
              export FTLCONF_webserver_api_pwhash="$hash"
              if [[ -n "''${PIHOLE_TLS_NAME:-}" ]]; then
                openssl=${lib.getExe pkgs.openssl}
                cert_key=$("$openssl" x509 -in "$PIHOLE_TLS_PEM" -pubkey -noout 2>/dev/null || true)
                pem_key=$("$openssl" pkey -in "$PIHOLE_TLS_PEM" -passin pass: -pubout 2>/dev/null || true)
                if [[ -z "$cert_key" || "$cert_key" != "$pem_key" ]] ||
                   ! "$openssl" verify -purpose sslserver -verify_hostname "$PIHOLE_TLS_NAME" \
                     -CAfile "${cfg.stateDirectory}/ordis-ca.crt" "$PIHOLE_TLS_PEM" >/dev/null 2>&1; then
                  echo 'Ordis TLS credential not usable; keeping the loopback recovery listener' >&2
                  export FTLCONF_webserver_port=127.0.0.1:8080
                fi
              fi
              exec ${lib.getExe config.services.pihole-ftl.package} no-daemon
            ''
          );
          AmbientCapabilities = lib.mkForce [ "CAP_NET_BIND_SERVICE" ];
          CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
          UMask = "0077";
          LimitCORE = 0;
          MemorySwapMax = 0;
          ProtectHome = lib.mkForce true;
        };
      };
    };
}
