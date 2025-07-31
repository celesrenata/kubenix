#!/usr/bin/env python3

try:
    import ipex_llm
    print("✅ IPEX-LLM imported successfully!")
    print(f"📦 Available modules: {[x for x in dir(ipex_llm) if not x.startswith('_')]}")
    
    # Try to access some basic functionality
    if hasattr(ipex_llm, 'llm_convert'):
        print("✅ llm_convert function available")
    
    if hasattr(ipex_llm, 'optimize'):
        print("✅ optimize module available")
        
    print("🎉 IPEX-LLM package is working correctly!")
    
except ImportError as e:
    print(f"❌ Import error: {e}")
except Exception as e:
    print(f"❌ Other error: {e}")
