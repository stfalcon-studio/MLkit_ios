//
//  UIImage+CVPixelBuffer.swift
//  Prizma
//
//  Created by Alex Frankiv on 30.08.18.
//  Copyright © 2018 Alex Frankiv. All rights reserved.
//

import UIKit
import VideoToolbox

extension UIImage {
	public convenience init?(pixelBuffer: CVPixelBuffer) {
		var cgImage: CGImage?
		VTCreateCGImageFromCVPixelBuffer(pixelBuffer, nil, &cgImage)
		
		if let cgImage = cgImage {
			self.init(cgImage: cgImage)
		} else {
			return nil
		}
	}
	
	public convenience init?(pixelBuffer: CVPixelBuffer, context: CIContext) {
		let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
		let rect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer),
						  height: CVPixelBufferGetHeight(pixelBuffer))
		if let cgImage = context.createCGImage(ciImage, from: rect) {
			self.init(cgImage: cgImage)
		} else {
			return nil
		}
	}
}
