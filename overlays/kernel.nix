final: prev: {
  linux_6_18_rc4 = (prev.linuxPackages_6_12.kernel.override {
    argsOverride = {
      version = "6.18.0-rc4";
      modDirVersion = "6.18.0-rc4";
      src = prev.fetchurl {
        url = "https://git.kernel.org/torvalds/t/linux-6.18-rc4.tar.gz";
        hash = "sha256-DtR8sFwexWyzondmRXXaSbHZ7W/QK2dMwp/zfg+TsKE=";
      };
      kernelPatches = [
        {
          name = "xe-mtl-sriov";
          patch = prev.writeText "mtl-sriov.patch" ''
            diff --git a/drivers/gpu/drm/xe/xe_pci.c b/drivers/gpu/drm/xe/xe_pci.c
            index 37e024c..d7af176 100644
            --- a/drivers/gpu/drm/xe/xe_pci.c
            +++ b/drivers/gpu/drm/xe/xe_pci.c
            @@ -313,6 +313,7 @@ static const struct xe_device_desc mtl_desc = {
             	.dma_mask_size = 46,
             	.has_display = true,
             	.has_pxp = true,
            +	.has_sriov = true,
             	.max_gt_per_tile = 2,
             };
          '';
        }
      ];
    };
  });
  
  linuxPackages_6_18_rc4 = prev.linuxPackagesFor final.linux_6_18_rc4;
}
