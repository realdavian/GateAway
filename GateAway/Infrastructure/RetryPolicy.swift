import Foundation

/// Generic retry policy with exponential backoff
struct RetryPolicy {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    
    /// Default: 3 retries with exponential backoff (1s, 2s, 4s)
    nonisolated static let `default` = RetryPolicy(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 10.0
    )
    
    /// Conservative: 2 retries with shorter delays
    nonisolated static let conservative = RetryPolicy(
        maxRetries: 2,
        baseDelay: 0.5,
        maxDelay: 5.0
    )
    
    /// Aggressive: 5 retries for very flaky connections
    nonisolated static let aggressive = RetryPolicy(
        maxRetries: 5,
        baseDelay: 1.0,
        maxDelay: 15.0
    )
    
    /// Execute an async operation with retry logic and exponential backoff
    /// - Parameter operation: The async throwing operation to execute
    /// - Returns: The result of the successful operation
    /// - Throws: The last error encountered if all retries fail, or CancellationError if cancelled
    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            try Task.checkCancellation()
            
            do {
                return try await operation()
            } catch is CancellationError {
                Log.info("Operation cancelled")
                throw CancellationError()
            } catch {
                lastError = error
                
                guard attempt < maxRetries else {
                    Log.warning("All \(maxRetries) retry attempts exhausted")
                    break
                }
                
                let delay = min(baseDelay * pow(2.0, Double(attempt)), maxDelay)
                
                Log.debug("Attempt \(attempt + 1)/\(maxRetries + 1) failed: \(error.localizedDescription)")
                Log.debug("Retrying in \(String(format: "%.1f", delay))s...")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? NSError(
            domain: "RetryPolicy",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Operation failed after \(maxRetries) retries"]
        )
    }
}
