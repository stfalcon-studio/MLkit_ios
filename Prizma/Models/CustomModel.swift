//
//  CustomModel.swift
//  Prizma
//
//  Created by Alex Frankiv on 02.09.18.
//  Copyright © 2018 Alex Frankiv. All rights reserved.
//

import Foundation
import CoreML
import Vision

enum CustomModel: Int, Codable {
	
	case inceptionV3
	case googleNetPlaces
	case mobileNet
	case visualSentimentCNN
	case ageNet
	case mnist
	case resNet50
	case food101
	
	static let cases: [CustomModel] = [.inceptionV3, .googleNetPlaces, .mobileNet, .visualSentimentCNN,
									   .ageNet, .mnist, .resNet50, .food101]
	
	var name: String {
		switch self {
		case .inceptionV3: return "Inception V3"
		case .googleNetPlaces: return "Google Net Places"
		case .mobileNet: return "Mobile Net"
		case .visualSentimentCNN: return "Visual Sentiment CNN"
		case .ageNet: return "Age Net"
		case .mnist: return "MNIST (handwriting)"
		case .resNet50: return "ResNet 50"
		case .food101: return "Food 101"
		}
	}
	
	var model: VNCoreMLModel? {
		switch self {
		case .inceptionV3: return try? VNCoreMLModel(for: Inceptionv3().model)
		case .googleNetPlaces: return try? VNCoreMLModel(for: GoogLeNetPlaces().model)
		case .mobileNet: return try? VNCoreMLModel(for: MobileNet().model)
		case .visualSentimentCNN: return try? VNCoreMLModel(for: VisualSentimentCNN().model)
		case .ageNet: return try? VNCoreMLModel(for: AgeNet().model)
		case .mnist: return try? VNCoreMLModel(for: MNIST().model)
		case .resNet50: return try? VNCoreMLModel(for: Resnet50().model)
		case .food101: return try? VNCoreMLModel(for: Food101().model)
		}
	}
}
