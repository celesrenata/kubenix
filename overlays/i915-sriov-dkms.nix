prev: final:
rec {
  intel-gfx-sriov = prev.stdenv.mkDerivation {
    name = "intel-gfx-sriov-${prev.kernelPXP.kernel.modDirVersion}";

    passthru.moduleName = "i915";

    src = prev.fetchFromGitHub {
      owner = "strongtz";
      repo = "i915-sriov-dkms";
      rev = "e26ce8952e465762fc0743731aa377ec0b2889ff";
      sha256 = "sha256-O+7ZehoVOYYdCTboF9XGBR9G6I72987AdbbF1JkrsBc=";
    };

    hardeningDisable = [ "pic" ];

    nativeBuildInputs = prev.kernelPXP.kernel.moduleBuildDependencies;

    makeFlags = [
      "KVERSION=${prev.kernelPXP.kernel.modDirVersion}"
      "KDIR=${prev.kernelPXP.kernel.dev}/lib/modules/${prev.kernelPXP.kernel.modDirVersion}/build"
    ];
    buildFlags = [
      "KERNEL_DIR=${prev.kernelPXP.kernel.dev}/lib/modules/${prev.kernelPXP.kernel.modDirVersion}/build"
    ];
    buildPhase = ''
      make -j8 -C ${prev.pkgs.kernelPXP.kernel.dev}/lib/modules/${prev.kernelPXP.kernel.modDirVersion}/build M=$(pwd) modules
    '';

    installPhase = ''
      install -D i915.ko $out/lib/modules/${prev.kernelPXP.kernel.modDirVersion}/kernel/drivers/gpu/drm/i915/i915.ko
    '';
  };
}
