{ lib
, buildGoModule
, fetchFromGitHub
, cmake
, gcc14
, pkg-config
, git
, intel-compute-runtime
, level-zero
, intel-mkl
, opencl-headers
, ocl-icd
}:

buildGoModule rec {
  pname = "ollama-ipex";
  version = "0.5.4";
  
  src = fetchFromGitHub {
    owner = "ollama";
    repo = "ollama";
    rev = "v${version}";
    hash = "sha256-JyP7A1+u9Vs6ynOKDwun1qLBsjN+CVHIv39Hh2TYa2U=";
  };

  vendorHash = "sha256-xz9v91Im6xTLPzmYoVecdF7XiPKBZk3qou1SGokgPXQ=";

  nativeBuildInputs = [ cmake gcc14 pkg-config git ];
  buildInputs = [ intel-compute-runtime level-zero intel-mkl opencl-headers ocl-icd ];

  preBuild = ''
    # Use Intel MKL + OpenCL for GPU acceleration
    export GGML_OPENCL=1
    export GGML_BLAS=1
    export GGML_BLAS_VENDOR=Intel10_64lp
    export CGO_ENABLED=1
    
    # Intel MKL paths
    export MKLROOT="${intel-mkl}"
    export MKL_ROOT="${intel-mkl}"
    export LD_LIBRARY_PATH="${intel-mkl}/lib:${intel-compute-runtime}/lib:${ocl-icd}/lib:$LD_LIBRARY_PATH"
    
    # OpenCL paths
    export OPENCL_INCLUDE_DIR="${opencl-headers}/include"
    export OPENCL_LIB_DIR="${ocl-icd}/lib"
  '';

  buildPhase = ''
    runHook preBuild
    make -j$NIX_BUILD_CORES
    runHook postBuild
  '';

  installPhase = ''
    install -D ollama $out/bin/ollama
    mkdir -p $out/lib/ollama
    cp -r llama/build/linux-*/runners/* $out/lib/ollama/ 2>/dev/null || true
  '';

  meta = {
    description = "Ollama with Intel MKL + OpenCL acceleration";
    homepage = "https://github.com/ollama/ollama";
    license = lib.licenses.mit;
    mainProgram = "ollama";
  };
}
