{
  configurations.nixos.ordis.modules.tso-experiment = {
    # Preserve the existing generated connection identity and IP defaults.
    # Unlike ensureProfiles, /etc keyfiles exist before NetworkManager starts.
    environment.etc."NetworkManager/system-connections/Wired connection 1.nmconnection" = {
      mode = "0600";
      text = ''
        [connection]
        id=Wired connection 1
        uuid=cf876e7b-7aa7-392a-86f9-c73513a87b57
        type=ethernet
        autoconnect=true
        autoconnect-priority=-999
        interface-name=eno1

        [ethernet]

        [ethtool]
        feature-tso=false

        [ipv4]
        method=auto

        [ipv6]
        addr-gen-mode=default
        method=auto

        [proxy]
      '';
    };
  };
}
