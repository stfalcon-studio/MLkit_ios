//
//  CGImagePropertyOrientation+ UIDeviceOrientation.swift
//  Prizma
//
//  Created by Alex Frankiv on 30.08.18.
//  Copyright © 2018 Alex Frankiv. All rights reserved.
//

import UIKit

extension CGImagePropertyOrientation {
	
	init(_ deviceOrientation: UIDeviceOrientation) {
		switch deviceOrientation {
		case .portraitUpsideDown: self = .left
		case .landscapeLeft: self = .up
		case .landscapeRight: self = .down
		default: self = .right
		}
	}
}
