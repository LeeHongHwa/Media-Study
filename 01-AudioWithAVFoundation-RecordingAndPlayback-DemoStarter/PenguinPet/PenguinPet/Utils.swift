//
//  Utils.swift
//  Sound Butler
//
//  Created by Michael Briscoe on 12/14/15.
//  Copyright © 2015 Razeware. All rights reserved.
//

import Foundation

var appHasMicAccess = true

enum AudioStatus: Int, CustomStringConvertible {
  case Stopped = 0,
  Playing,
  Recording
  
  var audioName: String {
    let audioNames = ["Audio: Stopped", "Audio:Playing", "Audio:Recording"]
    return audioNames[rawValue]
  }
  
  var description: String {
    return audioName
  }
}
