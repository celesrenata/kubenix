#!/usr/bin/env bash
set -e

SITE_PACKAGES="/home/celes/.local/lib/python3.12/site-packages"
TMPDIR="/tmp/intel-wheels-$$"
mkdir -p "$TMPDIR"
cd "$TMPDIR"

PACKAGES=(
  "oneccl-2021.16.1"
  "intel_pti-0.13.1"
  "intel_sycl_rt-2025.2.1"
  "onemkl_sycl_blas-2025.2.0"
  "onemkl_sycl_dft-2025.2.0"
  "onemkl_sycl_lapack-2025.2.0"
  "onemkl_sycl_rng-2025.2.0"
  "onemkl_sycl_sparse-2025.2.0"
  "dpcpp_cpp_rt-2025.2.1"
  "intel_opencl_rt-2025.2.1"
  "mkl-2025.2.0"
  "intel_openmp-2025.2.1"
  "tbb-2022.2.0"
  "tcmlib-1.4.0"
  "umf-0.11.0"
)

for pkg in "${PACKAGES[@]}"; do
  wget -q "https://download.pytorch.org/whl/nightly/${pkg}-py2.py3-none-manylinux_2_28_x86_64.whl" -O "${pkg}.whl" || continue
  unzip -q "${pkg}.whl" || continue
  find . -name "*.so*" -type f -exec cp {} "$SITE_PACKAGES/" \; 2>/dev/null || true
  rm -rf "${pkg}"*
done

cd /
rm -rf "$TMPDIR"
