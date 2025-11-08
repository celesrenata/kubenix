{
  lib,
  buildPythonPackage,
  python,
  buildSupport,
  pythonCpTag,
  
  # Build dependencies
  autoPatchelfHook,
  
  # Runtime libraries
  zlib,
  level-zero,
  intel-sycl,
}:

buildPythonPackage rec {
  pname = "pytorch_triton_xpu";
  version = "3.3.1";
  format = "wheel";

  src = buildSupport.fetchtorch {
    inherit pname version;
    dist = "whl";
    python = pythonCpTag;
    abi = pythonCpTag;
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # TODO: Get actual hash
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    zlib
    level-zero
    intel-sycl.llvm-bin.lib
  ];

  postFixup = ''
    # Fix Level Zero path
    if [ -f "$out/${python.sitePackages}/triton/backends/intel/driver.py" ]; then
      substituteInPlace $out/${python.sitePackages}/triton/backends/intel/driver.py \
        --replace-fail 'ze_root = os.getenv("ZE_PATH", default="/usr/local")' \
        'ze_root = os.getenv("ZE_PATH", default="${level-zero}")'
    fi

    # Fix Intel compiler path
    if [ -f "$out/${python.sitePackages}/triton/runtime/build.py" ]; then
      substituteInPlace $out/${python.sitePackages}/triton/runtime/build.py \
        --replace-fail 'icpx = None' 'icpx = "${intel-sycl.clang}/bin/icpx"' \
        --replace-fail 'cxx = os.environ.get("CXX")' 'cxx = icpx'
    fi
  '';

  pythonImportsCheck = [ "triton" ];

  meta = with lib; {
    description = "Triton compiler for Intel XPU - GPU kernel compilation";
    homepage = "https://github.com/intel/intel-xpu-backend-for-triton";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
