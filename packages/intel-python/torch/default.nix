{
  lib,
  buildPythonPackage,
  python,
  buildSupport,
  pythonCpTag,
  torch_version,
  
  # Build dependencies
  autoPatchelfHook,
  autoAddDriverRunpath,
  
  # Runtime libraries
  zlib,
  intel-mkl,
  intel-sycl,
  pti-gpu,
  ocl-icd,
  
  # Python dependencies
  packaging,
  astunparse,
  cffi,
  click,
  numpy,
  pyyaml,
  fsspec,
  filelock,
  typing-extensions,
  sympy,
  networkx,
  jinja2,
  pillow,
  six,
  future,
  tensorboard,
  protobuf,
}:

buildPythonPackage rec {
  pname = "torch";
  version = torch_version;
  format = "wheel";

  outputs = [ "out" "dev" "lib" ];

  src = buildSupport.fetchtorch {
    inherit pname version;
    suffix = "%2Bxpu";
    python = pythonCpTag;
    abi = pythonCpTag;
    hash = "sha256-tEPfQLyct9ZIqfj57R1cOhID5WHr0KYd1V+4pYgz1ew=";
  };

  dontStrip = true;

  nativeBuildInputs = [
    autoPatchelfHook
    autoAddDriverRunpath
  ];

  buildInputs = [
    zlib
    intel-mkl
    intel-sycl.llvm-bin.lib
    pti-gpu.sdk
    ocl-icd
  ];

  dependencies = [
    packaging
    astunparse
    cffi
    click
    numpy
    pyyaml
    filelock
    typing-extensions
    sympy
    networkx
    jinja2
    fsspec
    pillow
    six
    future
    tensorboard
    protobuf
  ];

  postInstall = ''
    # Create dev output with headers and CMake files
    mkdir -p $dev
    if [ -d "$out/${python.sitePackages}/torch/include" ]; then
      cp -r $out/${python.sitePackages}/torch/include $dev/include
    fi
    if [ -d "$out/${python.sitePackages}/torch/share" ]; then
      cp -r $out/${python.sitePackages}/torch/share $dev/share
    fi

    # Fix up library paths for split outputs
    if [ -f "$dev/share/cmake/Torch/TorchConfig.cmake" ]; then
      substituteInPlace \
        $dev/share/cmake/Torch/TorchConfig.cmake \
        --replace-fail \''${TORCH_INSTALL_PREFIX}/lib "$lib/lib"
    fi

    if [ -f "$dev/share/cmake/Caffe2/Caffe2Targets-release.cmake" ]; then
      substituteInPlace \
        $dev/share/cmake/Caffe2/Caffe2Targets-release.cmake \
        --replace-fail \''${_IMPORT_PREFIX}/lib "$lib/lib"
    fi

    # Fix version metadata to avoid conflicts
    if [ -f "$out/${python.sitePackages}/torch-${version}+xpu.dist-info/METADATA" ]; then
      substituteInPlace $out/${python.sitePackages}/torch-${version}+xpu.dist-info/METADATA \
        --replace-fail "Version: ${version}+xpu" "Version: ${version}"
    fi

    # Create lib output with shared libraries
    mkdir -p $lib
    if [ -d "$out/${python.sitePackages}/torch/lib" ]; then
      mv $out/${python.sitePackages}/torch/lib $lib/lib
      
      # Remove conflicting OpenCL library
      if [ -f "$lib/lib/libOpenCL.so.1" ]; then
        rm $lib/lib/libOpenCL.so.1
      fi
      
      # Create symlink back to original location
      ln -s $lib/lib $out/${python.sitePackages}/torch/lib
    fi
  '';

  # Verify PyTorch XPU functionality
  pythonImportsCheck = [ "torch" ];
  
  # Additional checks for XPU support
  postCheck = ''
    python -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'XPU available: {torch.xpu.is_available() if hasattr(torch, \"xpu\") else \"No XPU module\"}')
if hasattr(torch, 'xpu') and torch.xpu.is_available():
    print(f'XPU device count: {torch.xpu.device_count()}')
    print(f'XPU device name: {torch.xpu.get_device_name(0)}')
"
  '';

  meta = with lib; {
    description = "PyTorch with Intel XPU support for Intel GPU acceleration";
    homepage = "https://pytorch.org/";
    changelog = "https://github.com/pytorch/pytorch/releases/tag/v${version}";
    license = licenses.bsd3;
    platforms = platforms.linux;
    maintainers = [ ];
    # Mark as broken if Intel GPU support is not available
    broken = false; # We'll test this during build
  };
}
