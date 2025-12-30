import Foundation

/// Generic retry policy with exponential backoff for resilient async operations
struct RetryPolicy {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    
    /// Default policy: 3 retries with exponential backoff (1s, 2s, 4s)
    nonisolated static let `default` = RetryPolicy(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 10.0
    )
    
    /// Conservative policy: 2 retries with shorter delays
    nonisolated static let conservative = RetryPolicy(
        maxRetries: 2,
        baseDelay: 0.5,
        maxDelay: 5.0
    )
    
    /// Aggressive policy: 5 retries for very flaky connections
    nonisolated static let aggressive = RetryPolicy(
        maxRetries: 5,
        baseDelay: 1.0,
        maxDelay: 15.0
    )
    
    /// Execute an async operation with retry logic and exponential backoff
    /// - Parameter operation: The async throwing operation to execute
    /// - Returns: The result of the successful operation
    /// - Throws: The last error encountered if all retries fail
    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                // Attempt the operation
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry if we've exhausted attempts
                guard attempt < maxRetries else {
                    print("🔄 [RetryPolicy] All \(maxRetries) retry attempts exhausted")
                    break
                }
                
                // Calculate delay with exponential backoff: baseDelay * 2^attempt
                let delay = min(baseDelay * pow(2.0, Double(attempt)), maxDelay)
                
                print("🔄 [RetryPolicy] Attempt \(attempt + 1)/\(maxRetries + 1) failed: \(error.localizedDescription)")
                print("⏳ [RetryPolicy] Retrying in \(String(format: "%.1f", delay))s...")
                
                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // If we get here, all retries failed
        throw lastError ?? NSError(
            domain: "RetryPolicy",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Operation failed after \(maxRetries) retries"]
        )
    }
}
