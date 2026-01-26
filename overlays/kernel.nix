final: prev: {
  linux_6_18 = prev.linux_6_18.override {
    kernelPatches = [
      {
        name = "xe-mtl-sriov";
        patch = ../mtl-sriov.patch;
      }
    ];
  };
  
  linuxPackages_6_18 = prev.linuxPackagesFor final.linux_6_18;
}
