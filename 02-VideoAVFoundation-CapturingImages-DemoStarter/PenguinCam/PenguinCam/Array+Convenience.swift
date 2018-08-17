//
//  Array+Convenience.swift
//  PenguinCam
//
//  Created by lyhonghwa on 2018. 8. 8..
//  Copyright © 2018년 Razeware LLC. All rights reserved.
//

import Foundation

extension Array {
    public func forEachs(_ body: (Element, Element) throws -> Void) {
        guard self.count >= 2 else { print("2개 이상의 element가 필요합니다."); return }
        for (i, element) in self.enumerated() {
            let nextIndex = i + 1
            guard nextIndex != self.count else { break }
            do {
                try body(element, self[nextIndex])
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    public func any(_ body: (Element) -> Bool) -> Bool {
        guard !self.isEmpty else { return false }
        for element in self {
            if body(element) {
                return true
            }
        }
        return false
    }
    
    public func any(_ body: (Int, Element) -> Bool) -> Bool {
        guard !self.isEmpty else { return false }
        for (offset, element) in self.enumerated() {
            if body(offset, element) {
                return true
            }
        }
        return false
    }
    
    public func all(_ body: (Element) -> Bool) -> Bool {
        guard !self.isEmpty else { return false }
        for element in self {
            if !body(element) {
                return false
            }
        }
        return true
    }
    
    public func isSorted(_ body: (Element, Element) -> Bool) -> Bool {
        guard count >= 2 else { return true }
        for (i, element) in self.enumerated() {
            let nextIndex = i + 1
            guard nextIndex != count else { break }
            if !body(element, self[nextIndex]) {
                return false
            }
        }
        return true
    }
}
