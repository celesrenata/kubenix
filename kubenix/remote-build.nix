{ ... }:
{
  nix.buildMachines = [
    {
      hostName = "gremlin-2";
      systems = ["x86_64-linux" "i686-linux"];
      protocol = "ssh-ng";
      maxJobs = 4;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "big-parallel" ];
    }
    {
      hostName = "gremlin-3";
      systems = ["x86_64-linux" "i686-linux"];
      protocol = "ssh-ng";
      maxJobs = 4;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "big-parallel" ];
    } 
 ];
  nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
    fallback = true
  '';
}
