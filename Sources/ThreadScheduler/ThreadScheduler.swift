//
//  Scheduler.swift
//
//  Created by Alex on 4/6/19.
//  Copyright © 2019 Alex. All rights reserved.
//

import Foundation
import RxSwift


public final class Scheduler {
    private let thread: Thread
    private let target: ThreadTarget

    public init(threadName: String) {
        self.target = ThreadTarget()
        self.thread = Thread(target: target,
                             selector: #selector(ThreadTarget.threadEntryPoint),
                             object: nil)
        self.thread.name = threadName
        self.thread.start()
    }

    public final func performAction(action: @escaping()->Void){
        let action = ThreadAction(action: action)
        action.perform(#selector(ThreadAction.performAction),
                       on: thread,
                       with: nil,
                       waitUntilDone: false,
                       modes: [RunLoop.Mode.default.rawValue])
    }


    public final func performSync<T>(action: @escaping ()->T)->T{
        let sema = DispatchSemaphore(value: 0)
        var value: T?
        self.performAction {
            value = action()
            sema.signal()
        }
        sema.wait()
        return value!
    }

    deinit {
        thread.cancel()
    }
}

extension Scheduler: ImmediateSchedulerType {
    public func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable {
        let disposable = SingleAssignmentDisposable()

        var action: ThreadAction? = ThreadAction {
            if disposable.isDisposed {
                return
            }
            disposable.setDisposable(action(state))
        }

        action?.perform(#selector(ThreadAction.performAction),
                        on: thread,
                        with: nil,
                        waitUntilDone: false,
                        modes: [RunLoop.Mode.default.rawValue])

        let actionDisposable = Disposables.create {
            action = nil
        }

        return Disposables.create(disposable, actionDisposable)
    }
}

private final class ThreadTarget: NSObject {
    @objc fileprivate func threadEntryPoint() {
        let runLoop = RunLoop.current
        runLoop.add(NSMachPort(), forMode: RunLoop.Mode.default)
        runLoop.run()
    }
}

private final class ThreadAction: NSObject {
    private let action: () -> ()

    init(action: @escaping () -> ()) {
        self.action = action
    }

    @objc func performAction() {
        action()
    }
}

