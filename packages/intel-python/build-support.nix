{fetchurl}: {
  # Fetch Intel Extension for PyTorch wheels
  fetchipex = {
    pname,
    version,
    suffix ? "",
    dist ? "ipex_stable/xpu",
    python ? "cp312",
    abi ? "cp312", 
    platform ? "linux_x86_64",
    hash,
  }:
    fetchurl {
      inherit hash;
      url = "https://download.pytorch-extension.intel.com/${dist}/${pname}-${version}${suffix}-${python}-${abi}-${platform}.whl";
    };

  # Fetch PyTorch XPU wheels
  fetchtorch = {
    pname,
    version,
    suffix ? "",
    dist ? "whl/xpu",
    python ? "cp312",
    abi ? "cp312",
    platform ? "linux_x86_64",
    hash,
  }:
    fetchurl {
      inherit hash;
      url = "https://download.pytorch.org/${dist}/${pname}-${version}${suffix}-${python}-${abi}-${platform}.whl";
    };

  # Generic Intel wheel fetcher for other packages
  fetchintelwheel = {
    pname,
    version,
    baseurl,
    suffix ? "",
    python ? "cp312",
    abi ? "cp312",
    platform ? "linux_x86_64",
    hash,
  }:
    fetchurl {
      inherit hash;
      url = "${baseurl}/${pname}-${version}${suffix}-${python}-${abi}-${platform}.whl";
    };

  # Version compatibility validation
  validateCompatibility = {
    torch_version,
    ipex_version,
    python_version,
  }: let
    # Define compatibility matrix
    compatibility_matrix = {
      "torch-2.7.1+xpu" = {
        compatible_ipex = ["2.7.10+xpu"];
        compatible_python = ["cp310" "cp311" "cp312"];
      };
    };
    
    torch_key = "torch-${torch_version}";
    matrix_entry = compatibility_matrix.${torch_key} or null;
  in
    if matrix_entry == null then
      throw "Unsupported PyTorch version: ${torch_version}"
    else if !(builtins.elem ipex_version matrix_entry.compatible_ipex) then
      throw "IPEX version ${ipex_version} not compatible with PyTorch ${torch_version}"
    else if !(builtins.elem python_version matrix_entry.compatible_python) then
      throw "Python version ${python_version} not supported"
    else
      true;
}
