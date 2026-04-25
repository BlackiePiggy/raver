import Foundation

enum DemoAlignedWeakBinder {
    static func assemblyConfiguration(
        owner: DemoAlignedChatViewController,
        _ method: @escaping (DemoAlignedChatViewController) -> () -> Void
    ) -> () -> Void {
        { [weak owner] in
            guard let owner else { return }
            method(owner)()
        }
    }

    static func action<Value>(
        owner: DemoAlignedChatViewController,
        _ method: @escaping (DemoAlignedChatViewController) -> (Value) -> Void
    ) -> (Value) -> Void {
        { [weak owner] value in
            guard let owner else { return }
            method(owner)(value)
        }
    }

    static func mainActorAsyncAction<Value>(
        owner: DemoAlignedChatViewController,
        _ method: @escaping (DemoAlignedChatViewController) -> (Value) async -> Void
    ) -> (Value) -> Void {
        { [weak owner] value in
            Task { @MainActor [weak owner] in
                guard let owner else { return }
                await method(owner)(value)
            }
        }
    }

    static func callback(
        owner: DemoAlignedChatViewController,
        _ method: @escaping (DemoAlignedChatViewController) -> () -> Void
    ) -> () -> Void {
        { [weak owner] in
            guard let owner else { return }
            method(owner)()
        }
    }

    static func asyncCallback(
        owner: DemoAlignedChatViewController,
        _ method: @escaping (DemoAlignedChatViewController) -> () async -> Void
    ) -> () async -> Void {
        { [weak owner] in
            guard let owner else { return }
            await method(owner)()
        }
    }

    static func valueProvider<Value>(
        owner: DemoAlignedChatViewController,
        _ method: @escaping (DemoAlignedChatViewController) -> () -> Value,
        fallback: @autoclosure @escaping () -> Value
    ) -> () -> Value {
        { [weak owner] in
            guard let owner else { return fallback() }
            return method(owner)()
        }
    }
}
