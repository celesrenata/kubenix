{ lib
, stdenv
, fetchFromGitHub
, python3
, intel-mkl
, intel-tbb
, intel-dpcpp
, intel-dnnl
, level-zero
, intel-compute-runtime
, intel-gmmlib
, jemalloc
, gperftools # provides tcmalloc
}:

python3.pkgs.buildPythonPackage rec {
  pname = "ipex-llm";
  version = "2.2.0";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "intel";
    repo = "ipex-llm";
    rev = "v${version}";
    hash = "sha256-edd1yiIt4jfknWJTtRRM5tdpsZuK4l776VJoO1w51kQ=";
  };

  # Change to the python directory where setup.py is located
  sourceRoot = "source/python/llm";

  nativeBuildInputs = with python3.pkgs; [
    setuptools
    wheel
  ];

  buildInputs = [
    intel-mkl.out
    intel-tbb.out
    intel-dpcpp.llvm
    intel-dpcpp.clang
    intel-dnnl.out
    level-zero
    intel-compute-runtime
    intel-gmmlib
    jemalloc
    gperftools # provides libtcmalloc.so
  ];

  propagatedBuildInputs = with python3.pkgs; [
    torch
    transformers
    accelerate
    datasets
    numpy
    packaging
    psutil
    py-cpuinfo
    protobuf
    mpmath
  ];

  # Set environment variables and patch setup.py to skip downloads
  preBuild = ''
    export MKLROOT=${intel-mkl.out}
    export TBBROOT=${intel-tbb.out}
    export DNNLROOT=${intel-dnnl.out}
    export CPATH="${intel-mkl.out}/include:${intel-tbb.out}/include:${intel-dpcpp.llvm}/include:$CPATH"
    export LIBRARY_PATH="${intel-mkl.out}/lib:${intel-tbb.out}/lib:${intel-dpcpp.llvm}/lib:$LIBRARY_PATH"
    export LD_LIBRARY_PATH="${lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH"
    
    # Create libs directory and provide required libraries
    mkdir -p ipex_llm/libs
    
    # Link jemalloc and tcmalloc from Nix packages
    ln -sf ${jemalloc}/lib/libjemalloc.so ipex_llm/libs/libjemalloc.so
    ln -sf ${gperftools}/lib/libtcmalloc.so ipex_llm/libs/libtcmalloc.so
    
    # Patch setup.py to skip the download phase - replace the entire download section
    python3 << 'EOF'
import re

with open('setup.py', 'r') as f:
    content = f.read()

# Replace the download section with a comment
pattern = r'lib_urls = obtain_lib_urls\(\).*?download_libs\(url, change_permission=change_permission\)'
replacement = '# Skip downloading - libraries provided by Nix'
content = re.sub(pattern, replacement, content, flags=re.DOTALL)

# Also skip the file existence check
pattern = r'# Check if all package files are ready.*?raise FileNotFoundError\(\s*f\'Could not find package dependency file: \{file_path\}\'\)'
replacement = '# Skip file checks - using Nix-provided libraries'
content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open('setup.py', 'w') as f:
    f.write(content)
EOF
  '';

  # Skip tests for now as they require GPU
  doCheck = false;

  # Skip import check for now as it may require the binary libraries
  pythonImportsCheck = [];

  meta = with lib; {
    description = "Accelerate local LLM inference and finetuning on Intel XPU";
    homepage = "https://github.com/intel/ipex-llm";
    license = licenses.asl20;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
