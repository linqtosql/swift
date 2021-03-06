// RUN: %target-typecheck-verify-swift -enable-experimental-concurrency
// REQUIRES: concurrency

func someAsyncFunc() async -> String { "" }

struct MyError: Error {}
func someThrowingAsyncFunc() async throws -> String { throw MyError() }

func test_unsafeContinuations() async {
  // the closure should not allow async operations;
  // after all: if you have async code, just call it directly, without the unsafe continuation
  let _: String = Task.withUnsafeContinuation { continuation in // expected-error{{cannot convert value of type '(_) async -> ()' to expected argument type '(Task.UnsafeContinuation<String>) -> Void'}}
    let s = await someAsyncFunc() // rdar://70610141 for getting a better error message here
    continuation.resume(returning: s)
  }

  let _: String = await Task.withUnsafeContinuation { continuation in
    continuation.resume(returning: "")
  }
}

func test_unsafeThrowingContinuations() async {
  let _: String = try await Task.withUnsafeThrowingContinuation { continuation in
    continuation.resume(returning: "")
  }

  let _: String = try await Task.withUnsafeThrowingContinuation { continuation in
    continuation.resume(throwing: MyError())
  }

  // TODO: Potentially could offer some warnings if we know that a continuation was resumed or escaped at all in a closure?
}

// ==== Detached Tasks ---------------------------------------------------------

func test_detached() async throws {
  let handle = Task.runDetached() {
    await someAsyncFunc() // able to call async functions
  }

  let result: String = await try handle.get()
  _ = result
}

func test_detached_throwing() async -> String {
  let handle: Task.Handle<String, Error> = Task.runDetached() {
    await try someThrowingAsyncFunc() // able to call async functions
  }

  do {
    return await try handle.get()
  } catch {
    print("caught: \(error)")
  }
}

// ==== Current Task -----------------------------------------------------------

func test_current_task() async {
    _ = await Task.current() // yay, we know "in" what task we're executing
}
