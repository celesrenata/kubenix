final: prev: {
  # Use kernel 6.18 directly - SR-IOV patch will be added separately if needed
  linux_6_18 = prev.linux_6_18;
  linuxPackages_6_18 = prev.linuxPackagesFor final.linux_6_18;
}
