{ ... }:
{
  # Networking
  networking.hostName = "kubenix";
  # Enable NetworkManager.

  networking.networkmanager.enable = true;
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  networking.nameservers = [ "192.168.42.1" ];
  networking.firewall.enable = false;
}
