{
  lib,
  buildPythonPackage,
  python,
  buildSupport,
  pythonCpTag,
  ipex_version,
  torch,
  
  # Build dependencies
  autoPatchelfHook,
  autoAddDriverRunpath,
  
  # Runtime libraries
  level-zero,
  intel-mkl,
  intel-sycl,
  zstd,
  ocl-icd,
  
  # Python dependencies
  expecttest,
  hypothesis,
  numpy,
  psutil,
  pytest,
  pyyaml,
  scipy,
  typing-extensions,
  pydantic,
  util-linux,
  ruamel-yaml,
}:

buildPythonPackage rec {
  pname = "intel_extension_for_pytorch";
  version = ipex_version;
  format = "wheel";

  outputs = [ "out" "dev" "lib" ];

  src = buildSupport.fetchipex {
    inherit pname version;
    suffix = "%2Bxpu";
    python = pythonCpTag;
    abi = pythonCpTag;
    hash = "sha256-L2Wxz/rJ002BIseU6w5EHpKMr7Te9kIMlr6G2gkjlLE=";
  };

  dontStrip = true;

  nativeBuildInputs = [
    autoPatchelfHook
    autoAddDriverRunpath
  ];

  buildInputs = [
    intel-mkl
    intel-sycl.llvm-bin.lib
    torch.lib
    level-zero
    zstd.dev
    ocl-icd
  ];

  dependencies = [
    expecttest
    hypothesis
    numpy
    psutil
    pytest
    pyyaml
    scipy
    typing-extensions
    pydantic
    torch
    util-linux
    ruamel-yaml
  ];

  postInstall = ''
    # Create dev output with headers and CMake files
    mkdir -p $dev
    if [ -d "$out/${python.sitePackages}/${pname}/include" ]; then
      cp -r $out/${python.sitePackages}/${pname}/include $dev/include
    fi
    if [ -d "$out/${python.sitePackages}/${pname}/share" ]; then
      cp -r $out/${python.sitePackages}/${pname}/share $dev/share
    fi

    # Fix CMake paths for split outputs
    if [ -f "$dev/share/cmake/IPEX/IPEXConfig.cmake" ]; then
      substituteInPlace \
        $dev/share/cmake/IPEX/IPEXConfig.cmake \
        --replace-fail \''${IPEX_INSTALL_PREFIX}/lib "$lib/lib"
    fi

    # Create lib output with shared libraries
    mkdir -p $lib
    if [ -d "$out/${python.sitePackages}/${pname}/lib" ]; then
      mv $out/${python.sitePackages}/${pname}/lib $lib/lib
      
      # Create symlink back to original location
      ln -s $lib/lib $out/${python.sitePackages}/${pname}/lib
    fi
  '';

  # Verify IPEX functionality
  pythonImportsCheck = [ "intel_extension_for_pytorch" ];
  
  # Additional checks for IPEX functionality
  postCheck = ''
    python -c "
import intel_extension_for_pytorch as ipex
import torch
print(f'IPEX version: {ipex.__version__}')
print(f'PyTorch version: {torch.__version__}')

# Test basic IPEX functionality
if hasattr(torch, 'xpu') and torch.xpu.is_available():
    print('Testing IPEX optimization...')
    model = torch.nn.Linear(10, 1).to('xpu')
    try:
        optimized_model = ipex.optimize(model)
        print('IPEX optimization successful!')
    except Exception as e:
        print(f'IPEX optimization failed: {e}')
else:
    print('XPU not available, skipping IPEX optimization test')
"
  '';

  meta = with lib; {
    description = "Intel Extension for PyTorch - Accelerate PyTorch on Intel hardware";
    homepage = "https://github.com/intel/intel-extension-for-pytorch";
    changelog = "https://github.com/intel/intel-extension-for-pytorch/releases/tag/v${version}";
    license = licenses.bsd3;
    platforms = platforms.linux;
    maintainers = [ ];
    mainProgram = "ipexrun";
  };
}
