{
  lib,
  buildPythonPackage,
  buildSupport,
  pythonCpTag,
  
  # Build dependencies
  autoPatchelfHook,
  
  # Runtime libraries
  intel-ccl,
  intel-mpi,
  intel-sycl,
  torch,
}:

buildPythonPackage rec {
  pname = "oneccl_bind_pt";
  version = "2.6.0";
  format = "wheel";

  src = buildSupport.fetchipex {
    inherit pname version;
    suffix = "%2Bxpu";
    python = pythonCpTag;
    abi = pythonCpTag;
    hash = "sha256-Y7kb0OeDO7bbZ4kZD3/GlowZcRsJYlv80WY0w5wBr9U=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    intel-ccl
    intel-sycl.llvm-bin.lib
    intel-mpi
    torch.lib
  ];

  dependencies = [
    torch
  ];

  pythonImportsCheck = [ "oneccl_bindings_for_pytorch" ];

  meta = with lib; {
    description = "OneCCL bindings for PyTorch - Collective communications library";
    homepage = "https://github.com/intel/torch-ccl";
    license = licenses.bsd3;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
