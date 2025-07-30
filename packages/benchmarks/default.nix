{ lib
, python3Packages
, writeText
, writeShellScript
, intel-xpu
}:

python3Packages.buildPythonApplication rec {
  pname = "ipex-benchmarks";
  version = "1.0.0";
  format = "other";

  # No external source - we create everything
  src = ./.;

  propagatedBuildInputs = with python3Packages; [
    # Intel IPEX stack (when available)
    # intel-xpu.python.pkgs.ipex
    # intel-xpu.python.pkgs.torch
    # intel-xpu.python.pkgs.torchvision
    
    # Benchmarking tools (fallback to standard packages for now)
    matplotlib
    pandas
    psutil
    # gpustat  # May not be available
    # py-cpuinfo  # May not be available
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/bin $out/lib/ipex-benchmarks
    
    # Create comprehensive benchmark script
    cat > $out/lib/ipex-benchmarks/benchmark.py << 'EOF'
#!/usr/bin/env python3
"""
IPEX Comprehensive Benchmark Suite
Tests Intel XPU performance across different workloads
"""

import time
import json
import argparse
import sys
from pathlib import Path
from datetime import datetime
import psutil
import platform

try:
    import torch
    import intel_extension_for_pytorch as ipex
    import torchvision
    import matplotlib.pyplot as plt
    import pandas as pd
    DEPS_AVAILABLE = True
except ImportError as e:
    print(f"Missing dependencies: {e}")
    DEPS_AVAILABLE = False
    sys.exit(1)

class IPEXBenchmark:
    def __init__(self):
        self.results = {}
        self.device = self.detect_device()
        self.system_info = self.get_system_info()
        
    def detect_device(self):
        """Detect best available device"""
        if hasattr(torch, 'xpu') and torch.xpu.is_available():
            device = torch.device('xpu')
            print(f"🚀 Using Intel XPU: {torch.xpu.get_device_name()}")
        elif torch.cuda.is_available():
            device = torch.device('cuda')
            print(f"🚀 Using CUDA: {torch.cuda.get_device_name()}")
        else:
            device = torch.device('cpu')
            print("🚀 Using CPU")
        return device
    
    def get_system_info(self):
        """Collect system information"""
        info = {
            'timestamp': datetime.now().isoformat(),
            'platform': platform.platform(),
            'python_version': platform.python_version(),
            'pytorch_version': torch.__version__,
            'ipex_version': ipex.__version__,
            'cpu_count': psutil.cpu_count(),
            'memory_gb': psutil.virtual_memory().total / (1024**3),
            'device_type': self.device.type,
        }
        
        if self.device.type == 'xpu':
            try:
                info['xpu_device_count'] = torch.xpu.device_count()
                info['xpu_device_name'] = torch.xpu.get_device_name()
            except:
                pass
        elif self.device.type == 'cuda':
            info['cuda_device_count'] = torch.cuda.device_count()
            info['cuda_device_name'] = torch.cuda.get_device_name()
            
        return info
    
    def benchmark_tensor_ops(self, sizes=[512, 1024, 2048, 4096]):
        """Benchmark basic tensor operations"""
        print("\n📊 Tensor Operations Benchmark")
        print("-" * 40)
        
        results = {}
        
        for size in sizes:
            print(f"Testing {size}x{size} matrices...")
            
            # Create test tensors
            a = torch.randn(size, size, device=self.device, dtype=torch.float16)
            b = torch.randn(size, size, device=self.device, dtype=torch.float16)
            
            # Warmup
            for _ in range(5):
                _ = torch.matmul(a, b)
            
            if self.device.type == 'xpu':
                torch.xpu.synchronize()
            elif self.device.type == 'cuda':
                torch.cuda.synchronize()
            
            # Benchmark matrix multiplication
            start_time = time.time()
            for _ in range(10):
                result = torch.matmul(a, b)
                if self.device.type == 'xpu':
                    torch.xpu.synchronize()
                elif self.device.type == 'cuda':
                    torch.cuda.synchronize()
            end_time = time.time()
            
            avg_time = (end_time - start_time) / 10
            gflops = (2 * size**3) / (avg_time * 1e9)  # Approximate GFLOPS
            
            results[f"{size}x{size}"] = {
                'avg_time_ms': avg_time * 1000,
                'gflops': gflops,
                'memory_mb': (2 * size * size * 2) / (1024**2)  # FP16 = 2 bytes
            }
            
            print(f"  Time: {avg_time * 1000:.2f} ms, GFLOPS: {gflops:.2f}")
        
        self.results['tensor_ops'] = results
        return results
    
    def benchmark_conv_ops(self, batch_sizes=[1, 4, 8, 16]):
        """Benchmark convolution operations"""
        print("\n🔄 Convolution Operations Benchmark")
        print("-" * 40)
        
        results = {}
        
        # Create a simple CNN model
        model = torch.nn.Sequential(
            torch.nn.Conv2d(3, 64, 3, padding=1),
            torch.nn.ReLU(),
            torch.nn.Conv2d(64, 128, 3, padding=1),
            torch.nn.ReLU(),
            torch.nn.AdaptiveAvgPool2d((1, 1)),
            torch.nn.Flatten(),
            torch.nn.Linear(128, 10)
        ).to(self.device)
        
        # Optimize with IPEX if available
        if self.device.type == 'xpu':
            model = ipex.optimize(model, dtype=torch.float16)
        
        model.eval()
        
        for batch_size in batch_sizes:
            print(f"Testing batch size {batch_size}...")
            
            # Create test input (224x224 RGB images)
            input_tensor = torch.randn(batch_size, 3, 224, 224, 
                                     device=self.device, dtype=torch.float16)
            
            # Warmup
            with torch.no_grad():
                for _ in range(5):
                    _ = model(input_tensor)
            
            if self.device.type == 'xpu':
                torch.xpu.synchronize()
            elif self.device.type == 'cuda':
                torch.cuda.synchronize()
            
            # Benchmark inference
            start_time = time.time()
            with torch.no_grad():
                for _ in range(20):
                    output = model(input_tensor)
                    if self.device.type == 'xpu':
                        torch.xpu.synchronize()
                    elif self.device.type == 'cuda':
                        torch.cuda.synchronize()
            end_time = time.time()
            
            avg_time = (end_time - start_time) / 20
            throughput = batch_size / avg_time
            
            results[f"batch_{batch_size}"] = {
                'avg_time_ms': avg_time * 1000,
                'throughput_imgs_per_sec': throughput,
                'memory_mb': batch_size * 3 * 224 * 224 * 2 / (1024**2)
            }
            
            print(f"  Time: {avg_time * 1000:.2f} ms, Throughput: {throughput:.2f} imgs/sec")
        
        self.results['conv_ops'] = results
        return results
    
    def benchmark_stable_diffusion_simulation(self):
        """Simulate Stable Diffusion-like workload"""
        print("\n🎨 Stable Diffusion Simulation Benchmark")
        print("-" * 40)
        
        # Simulate UNet-like architecture
        class SimpleUNet(torch.nn.Module):
            def __init__(self):
                super().__init__()
                self.encoder = torch.nn.Sequential(
                    torch.nn.Conv2d(4, 64, 3, padding=1),
                    torch.nn.GroupNorm(8, 64),
                    torch.nn.SiLU(),
                    torch.nn.Conv2d(64, 128, 3, stride=2, padding=1),
                    torch.nn.GroupNorm(8, 128),
                    torch.nn.SiLU(),
                )
                self.decoder = torch.nn.Sequential(
                    torch.nn.ConvTranspose2d(128, 64, 3, stride=2, padding=1, output_padding=1),
                    torch.nn.GroupNorm(8, 64),
                    torch.nn.SiLU(),
                    torch.nn.Conv2d(64, 4, 3, padding=1),
                )
            
            def forward(self, x):
                x = self.encoder(x)
                x = self.decoder(x)
                return x
        
        model = SimpleUNet().to(self.device)
        
        # Optimize with IPEX
        if self.device.type == 'xpu':
            model = ipex.optimize(model, dtype=torch.float16)
        
        model.eval()
        
        # Test different resolutions
        resolutions = [(512, 512), (768, 768), (1024, 1024)]
        results = {}
        
        for width, height in resolutions:
            print(f"Testing {width}x{height} resolution...")
            
            # Simulate latent space (4 channels for SD)
            latent = torch.randn(1, 4, height//8, width//8, 
                               device=self.device, dtype=torch.float16)
            
            # Warmup
            with torch.no_grad():
                for _ in range(3):
                    _ = model(latent)
            
            if self.device.type == 'xpu':
                torch.xpu.synchronize()
            elif self.device.type == 'cuda':
                torch.cuda.synchronize()
            
            # Benchmark (simulate 20 denoising steps)
            start_time = time.time()
            with torch.no_grad():
                for step in range(20):
                    output = model(latent)
                    if self.device.type == 'xpu':
                        torch.xpu.synchronize()
                    elif self.device.type == 'cuda':
                        torch.cuda.synchronize()
            end_time = time.time()
            
            total_time = end_time - start_time
            time_per_step = total_time / 20
            
            results[f"{width}x{height}"] = {
                'total_time_sec': total_time,
                'time_per_step_ms': time_per_step * 1000,
                'estimated_generation_time_sec': total_time,  # For 20 steps
            }
            
            print(f"  Total time: {total_time:.2f}s, Per step: {time_per_step * 1000:.2f}ms")
        
        self.results['stable_diffusion_sim'] = results
        return results
    
    def save_results(self, output_file='benchmark_results.json'):
        """Save benchmark results to file"""
        full_results = {
            'system_info': self.system_info,
            'benchmarks': self.results
        }
        
        with open(output_file, 'w') as f:
            json.dump(full_results, f, indent=2)
        
        print(f"\n💾 Results saved to {output_file}")
        return output_file
    
    def generate_report(self):
        """Generate a summary report"""
        print("\n📋 Benchmark Summary Report")
        print("=" * 50)
        print(f"Device: {self.system_info['device_type']}")
        print(f"PyTorch: {self.system_info['pytorch_version']}")
        print(f"IPEX: {self.system_info['ipex_version']}")
        print(f"Memory: {self.system_info['memory_gb']:.1f} GB")
        
        if 'tensor_ops' in self.results:
            print(f"\n🔢 Tensor Operations (1024x1024):")
            result = self.results['tensor_ops'].get('1024x1024', {})
            print(f"  Time: {result.get('avg_time_ms', 0):.2f} ms")
            print(f"  GFLOPS: {result.get('gflops', 0):.2f}")
        
        if 'conv_ops' in self.results:
            print(f"\n🔄 Convolution (batch=4):")
            result = self.results['conv_ops'].get('batch_4', {})
            print(f"  Time: {result.get('avg_time_ms', 0):.2f} ms")
            print(f"  Throughput: {result.get('throughput_imgs_per_sec', 0):.2f} imgs/sec")
        
        if 'stable_diffusion_sim' in self.results:
            print(f"\n🎨 Stable Diffusion Simulation (512x512):")
            result = self.results['stable_diffusion_sim'].get('512x512', {})
            print(f"  Generation time: {result.get('total_time_sec', 0):.2f}s")
            print(f"  Per step: {result.get('time_per_step_ms', 0):.2f} ms")

def main():
    parser = argparse.ArgumentParser(description='IPEX Benchmark Suite')
    parser.add_argument('--output', '-o', default='benchmark_results.json',
                       help='Output file for results')
    parser.add_argument('--quick', action='store_true',
                       help='Run quick benchmark (smaller sizes)')
    parser.add_argument('--tensor-only', action='store_true',
                       help='Run only tensor operations benchmark')
    parser.add_argument('--conv-only', action='store_true',
                       help='Run only convolution benchmark')
    parser.add_argument('--sd-only', action='store_true',
                       help='Run only Stable Diffusion simulation')
    
    args = parser.parse_args()
    
    if not DEPS_AVAILABLE:
        print("❌ Required dependencies not available")
        return 1
    
    benchmark = IPEXBenchmark()
    
    print("🚀 Starting IPEX Benchmark Suite")
    print(f"Device: {benchmark.device}")
    print(f"System: {benchmark.system_info['platform']}")
    
    try:
        if args.tensor_only or not (args.conv_only or args.sd_only):
            sizes = [512, 1024] if args.quick else [512, 1024, 2048, 4096]
            benchmark.benchmark_tensor_ops(sizes)
        
        if args.conv_only or not (args.tensor_only or args.sd_only):
            batch_sizes = [1, 4] if args.quick else [1, 4, 8, 16]
            benchmark.benchmark_conv_ops(batch_sizes)
        
        if args.sd_only or not (args.tensor_only or args.conv_only):
            benchmark.benchmark_stable_diffusion_simulation()
        
        benchmark.save_results(args.output)
        benchmark.generate_report()
        
        print("\n✅ Benchmark completed successfully!")
        return 0
        
    except Exception as e:
        print(f"\n❌ Benchmark failed: {e}")
        return 1

if __name__ == '__main__':
    sys.exit(main())
EOF
    
    # Create wrapper script
    cat > $out/bin/ipex-benchmark << EOF
#!/usr/bin/env bash
export ZES_ENABLE_SYSMAN=1
export ONEAPI_DEVICE_SELECTOR="opencl:*"
exec python3 $out/lib/ipex-benchmarks/benchmark.py "\$@"
EOF
    
    chmod +x $out/bin/ipex-benchmark
    chmod +x $out/lib/ipex-benchmarks/benchmark.py
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Comprehensive benchmark suite for Intel IPEX performance testing";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "ipex-benchmark";
  };
}
