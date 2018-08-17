//
//  Dispatch+Timer.swift
//  PenguinCam
//
//  Created by kakao on 2018. 8. 13..
//  Copyright © 2018년 Razeware LLC. All rights reserved.
//

import Foundation

extension DispatchQueue {
    func createTimer(seconds: Int, async: @escaping () -> Void) -> DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: self)
        let time: DispatchTime = .now() + .seconds(seconds)
        timer.schedule(deadline: time, repeating: .seconds(seconds))
        timer.setEventHandler { async() }
        return timer
    }
}

extension DispatchSourceTimer {
    func stop() {
        self.cancel()
    }
}
