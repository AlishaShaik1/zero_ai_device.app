class BenchmarkService {
  Future<void> runBenchmarkIfNeeded() async {
    // 1. Load Gemma 4 E4B
    // 2. Run fixed 50-token prompt (CPU and GPU)
    // 3. Measure time, peak RAM, temperature
    // 4. Store result in local prefs
    // 5. Default to winner with RAM-ceiling override
  }

  Future<String> getOptimalBackend() async {
    // Check cached benchmark
    // Poll Android thermal API before inference
    // return "cpu" or "gpu"
    return "cpu"; // default for safety
  }
}
