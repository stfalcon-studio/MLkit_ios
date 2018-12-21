//
//  MainViewController.swift
//  Prizma
//
//  Created by Alex Frankiv on 29.08.18.
//  Copyright © 2018 Alex Frankiv. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import CoreML
import Photos

class MainViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

	// MARK: - IBOutlets
	@IBOutlet private weak var cameraView: UIView!
	@IBOutlet private weak var resultLabel: UILabel!
	
	// MARK: - Properties
	override var prefersStatusBarHidden: Bool {
		return true
	}
	
	private let visionSequenceHandler = VNSequenceRequestHandler()
	private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
	
	private lazy var captureSession: AVCaptureSession = {
		let session = AVCaptureSession()
		session.sessionPreset = AVCaptureSession.Preset.photo
		guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
			let input = try? AVCaptureDeviceInput(device: backCamera)
			else {
				print("no camera is available.");
				return session
		}
		session.addInput(input)
		return session
	}()
	
	// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		self.cameraView?.layer.addSublayer(self.cameraLayer)
		let videoOutput = AVCaptureVideoDataOutput()
		videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "DispatchQueue"))
		self.captureSession.addOutput(videoOutput)
		cameraLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
		
		self.captureSession.startRunning()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.navigationController?.navigationBar.isHidden = true
		clearScreen()
		resultLabel.text = ""
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		self.navigationController?.navigationBar.isHidden = false
		resultLabel.text = ""
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		if let frame = self.cameraView?.frame {
			self.cameraLayer.frame = frame
		}
	}
	
	//MARK: - Internal
	private func clearScreen() {
		DispatchQueue.main.async {
			self.cameraView.layer.sublayers?.forEach({ if $0 != self.cameraLayer { $0.removeFromSuperlayer() } })
		}
	}
	
	// MARK: - Behaviour
	@IBAction func moveToSettings(_ sender: Any?) {
		if (sender as? UIScreenEdgePanGestureRecognizer)?.state == .ended {
			performSegue(withIdentifier: "toSettings", sender: sender)
		}
	}
	
	// MARK: - Detection requests
	lazy var rectangleDetectionRequest: VNDetectRectanglesRequest = {
		let rectDetectRequest = VNDetectRectanglesRequest(completionHandler: self.handleDetectedRectangles)
		rectDetectRequest.maximumObservations = 8
		rectDetectRequest.minimumConfidence = 0.6
		rectDetectRequest.minimumAspectRatio = 0.3
		return rectDetectRequest
	}()
	
	lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: self.handleDetectedFaces)
	lazy var faceLandmarkRequest = VNDetectFaceLandmarksRequest(completionHandler: self.handleDetectedFaceLandmarks)
	
	lazy var textDetectionRequest: VNDetectTextRectanglesRequest = {
		let textDetectRequest = VNDetectTextRectanglesRequest(completionHandler: self.handleDetectedText)
		textDetectRequest.reportCharacterBoxes = true
		return textDetectRequest
	}()
	
	lazy var barcodeDetectionRequest: VNDetectBarcodesRequest = {
		let barcodeDetectRequest = VNDetectBarcodesRequest(completionHandler: self.handleDetectedBarcodes)
		barcodeDetectRequest.symbologies = [.QR, .Aztec, .UPCE]
		return barcodeDetectRequest
	}()
}

// MARK: - ML Stuff
extension MainViewController {
	
	func captureOutput(_ output: AVCaptureOutput,
					   didOutput sampleBuffer: CMSampleBuffer,
					   from connection: AVCaptureConnection) {
		
		
		guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
		
		if Settings.provider.customModelsSelected {
			guard let visionModel:VNCoreMLModel = Settings.provider.currentModel.model else { return }
			let classificationRequest = VNCoreMLRequest(model: visionModel,
														completionHandler: handleClassification)
			classificationRequest.imageCropAndScaleOption = .centerCrop
			do {
				try self.visionSequenceHandler.perform([classificationRequest], on: pixelBuffer)
			} catch {
				print("Throws: \(error)")
			}
		} else {
			let cgOrientation = CGImagePropertyOrientation(UIDevice.current.orientation)
			guard let cgImage = UIImage(pixelBuffer: pixelBuffer)?.cgImage else { return }
			performVisionRequest(image: cgImage, orientation: cgOrientation)
		}
		clearScreen()
	}
	
	fileprivate func performVisionRequest(image: CGImage, orientation: CGImagePropertyOrientation) {
		
		var requests = [VNImageBasedRequest]()
		if Settings.provider.facesSelected { requests.append(faceLandmarkRequest); requests.append(faceDetectionRequest) }
		if Settings.provider.rectsSelected { requests.append(rectangleDetectionRequest) }
		if Settings.provider.textSelected { requests.append(textDetectionRequest) }
		if Settings.provider.barcodeSelected { requests.append(barcodeDetectionRequest) }
		
		let imageRequestHandler = VNImageRequestHandler(cgImage: image,
														orientation: orientation,
														options: [:])
		
		DispatchQueue.global(qos: .userInitiated).async {
			do {
				try imageRequestHandler.perform(requests)
			} catch let error as NSError {
				self.presentAlert("Image Request Failed", error: error)
				return
			}
		}
	}
	
	// MARK: - Custom models handling
	func updateClassificationLabel(labelString: String) {
		DispatchQueue.main.async {
			self.resultLabel?.text = labelString
		}
	}
	
	func handleClassification(request: VNRequest,
							  error: Error?) {
		guard let observations = request.results else {
			updateClassificationLabel(labelString: "")
			return
		}
		
		let classifications = observations[0...min(3, (observations.count - 1))]
			.compactMap({ $0 as? VNClassificationObservation})
			.filter({ $0.confidence > 0.2 })
			.map(self.textForClassification)
		
		if (classifications.count > 0) {
			updateClassificationLabel(labelString: "\(classifications.joined(separator: "\n"))")
		} else {
			updateClassificationLabel(labelString: "")
		}
	}
	
	func textForClassification(classification: VNClassificationObservation) -> String {
		let pc = Int(classification.confidence * 100)
		return "\(classification.identifier)\nConfidence: \(pc)%"
	}
}

// MARK: - Handle detection
extension MainViewController {
	fileprivate func handleDetectedRectangles(request: VNRequest?, error: Error?) {
		if let nsError = error as NSError? {
			self.presentAlert("Rectangle Detection Error", error: nsError)
			return
		}
		DispatchQueue.main.async {
			guard let drawLayer = self.cameraView?.layer,
				  let results = request?.results as? [VNRectangleObservation] else { return }
			self.draw(rectangles: results, onImageWithBounds: drawLayer.bounds)
			drawLayer.setNeedsDisplay()
		}
	}
	
	fileprivate func handleDetectedFaces(request: VNRequest?, error: Error?) {
		if let nsError = error as NSError? {
			self.presentAlert("Face Detection Error", error: nsError)
			return
		}
		DispatchQueue.main.async {
			guard let drawLayer = self.cameraView?.layer,
				let results = request?.results as? [VNFaceObservation] else {
					return
			}
			self.draw(faces: results, onImageWithBounds: drawLayer.bounds)
			drawLayer.setNeedsDisplay()
		}
	}
	
	fileprivate func handleDetectedFaceLandmarks(request: VNRequest?, error: Error?) {
		if let nsError = error as NSError? {
			self.presentAlert("Face Landmark Detection Error", error: nsError)
			return
		}
		DispatchQueue.main.async {
			guard let drawLayer = self.cameraView?.layer,
				let results = request?.results as? [VNFaceObservation] else {
					return
			}
			self.drawFeatures(onFaces: results, onImageWithBounds: drawLayer.bounds)
			drawLayer.setNeedsDisplay()
		}
	}
	
	fileprivate func handleDetectedText(request: VNRequest?, error: Error?) {
		if let nsError = error as NSError? {
			self.presentAlert("Text Detection Error", error: nsError)
			return
		}
		DispatchQueue.main.async {
			guard let drawLayer = self.cameraView?.layer,
				let results = request?.results as? [VNTextObservation] else {
					return
			}
			self.draw(text: results, onImageWithBounds: drawLayer.bounds)
			drawLayer.setNeedsDisplay()
		}
	}
	
	fileprivate func handleDetectedBarcodes(request: VNRequest?, error: Error?) {
		if let nsError = error as NSError? {
			self.presentAlert("Barcode Detection Error", error: nsError)
			return
		}
		DispatchQueue.main.async {
			guard let drawLayer = self.cameraView?.layer,
				let results = request?.results as? [VNBarcodeObservation] else {
					return
			}
			self.draw(barcodes: results, onImageWithBounds: drawLayer.bounds)
			drawLayer.setNeedsDisplay()
		}
	}
}

// MARK: - Helper Methods
extension MainViewController {
	
	func scaleAndOrient(image: UIImage) -> UIImage {
		
		let maxResolution: CGFloat = 640
		
		guard let cgImage = image.cgImage else {
			print("UIImage has no CGImage backing it!")
			return image
		}
		
		let width = CGFloat(cgImage.width)
		let height = CGFloat(cgImage.height)
		var transform = CGAffineTransform.identity
		
		var bounds = CGRect(x: 0, y: 0, width: width, height: height)
		
		if width > maxResolution ||
			height > maxResolution {
			let ratio = width / height
			if width > height {
				bounds.size.width = maxResolution
				bounds.size.height = round(maxResolution / ratio)
			} else {
				bounds.size.width = round(maxResolution * ratio)
				bounds.size.height = maxResolution
			}
		}
		
		let scaleRatio = bounds.size.width / width
		let orientation = image.imageOrientation
		switch orientation {
		case .up:
			transform = .identity
		case .down:
			transform = CGAffineTransform(translationX: width, y: height).rotated(by: .pi)
		case .left:
			let boundsHeight = bounds.size.height
			bounds.size.height = bounds.size.width
			bounds.size.width = boundsHeight
			transform = CGAffineTransform(translationX: 0, y: width).rotated(by: 3.0 * .pi / 2.0)
		case .right:
			let boundsHeight = bounds.size.height
			bounds.size.height = bounds.size.width
			bounds.size.width = boundsHeight
			transform = CGAffineTransform(translationX: height, y: 0).rotated(by: .pi / 2.0)
		case .upMirrored:
			transform = CGAffineTransform(translationX: width, y: 0).scaledBy(x: -1, y: 1)
		case .downMirrored:
			transform = CGAffineTransform(translationX: 0, y: height).scaledBy(x: 1, y: -1)
		case .leftMirrored:
			let boundsHeight = bounds.size.height
			bounds.size.height = bounds.size.width
			bounds.size.width = boundsHeight
			transform = CGAffineTransform(translationX: height, y: width).scaledBy(x: -1, y: 1).rotated(by: 3.0 * .pi / 2.0)
		case .rightMirrored:
			let boundsHeight = bounds.size.height
			bounds.size.height = bounds.size.width
			bounds.size.width = boundsHeight
			transform = CGAffineTransform(scaleX: -1, y: 1).rotated(by: .pi / 2.0)
		}
		
		return UIGraphicsImageRenderer(size: bounds.size).image { rendererContext in
			let context = rendererContext.cgContext
			
			if orientation == .right || orientation == .left {
				context.scaleBy(x: -scaleRatio, y: scaleRatio)
				context.translateBy(x: -height, y: 0)
			} else {
				context.scaleBy(x: scaleRatio, y: -scaleRatio)
				context.translateBy(x: 0, y: -height)
			}
			context.concatenate(transform)
			context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
		}
	}
	
	func presentAlert(_ title: String, error: NSError) {
		DispatchQueue.main.async {
			let alertController = UIAlertController(title: title,
													message: error.localizedDescription,
													preferredStyle: .alert)
			let okAction = UIAlertAction(title: "OK",
										 style: .default) { _ in
				() // intentionally nothing
			}
			alertController.addAction(okAction)
			self.present(alertController, animated: true, completion: nil)
		}
	}

// MARK: - Path-Drawing

fileprivate func boundingBox(forRegionOfInterest: CGRect, withinImageBounds bounds: CGRect) -> CGRect {
	
	let imageWidth = bounds.width
	let imageHeight = bounds.height
	
	var rect = forRegionOfInterest
	rect.origin.x *= imageWidth
	rect.origin.x += bounds.origin.x
	rect.origin.y = (1 - rect.origin.y) * imageHeight + bounds.origin.y
	
	rect.size.width *= imageWidth
	rect.size.height *= imageHeight
	
	return rect
}

fileprivate func shapeLayer(color: UIColor, frame: CGRect) -> CAShapeLayer {
	let layer = CAShapeLayer()
	
	layer.fillColor = nil
	layer.shadowOpacity = 0
	layer.shadowRadius = 0
	layer.borderWidth = 2
	
	layer.borderColor = color.cgColor
	
	layer.anchorPoint = .zero
	layer.frame = frame
	layer.masksToBounds = true
	
	layer.transform = CATransform3DMakeScale(1, -1, 1)
	
	return layer
}

fileprivate func draw(rectangles: [VNRectangleObservation], onImageWithBounds bounds: CGRect) {
	CATransaction.begin()
	for observation in rectangles {
		let rectBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
		let rectLayer = shapeLayer(color: .blue, frame: rectBox)
		
		self.cameraView?.layer.addSublayer(rectLayer)
	}
	CATransaction.commit()
}

fileprivate func draw(faces: [VNFaceObservation], onImageWithBounds bounds: CGRect) {
	CATransaction.begin()
	for observation in faces {
		let faceBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
		let faceLayer = shapeLayer(color: .yellow, frame: faceBox)
		
		self.cameraView?.layer.addSublayer(faceLayer)
	}
	CATransaction.commit()
}

fileprivate func drawFeatures(onFaces faces: [VNFaceObservation], onImageWithBounds bounds: CGRect) {
	CATransaction.begin()
	for faceObservation in faces {
		let faceBounds = boundingBox(forRegionOfInterest: faceObservation.boundingBox, withinImageBounds: bounds)
		guard let landmarks = faceObservation.landmarks else {
			continue
		}
		
		let landmarkLayer = CAShapeLayer()
		let landmarkPath = CGMutablePath()
		let affineTransform = CGAffineTransform(scaleX: faceBounds.size.width, y: faceBounds.size.height)
		
		let openLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
			landmarks.leftEyebrow,
			landmarks.rightEyebrow,
			landmarks.faceContour,
			landmarks.noseCrest,
			landmarks.medianLine
		]
		
		let closedLandmarkRegions = [
			landmarks.leftEye,
			landmarks.rightEye,
			landmarks.outerLips,
			landmarks.innerLips,
			landmarks.nose
			].compactMap { $0 }
		
		for openLandmarkRegion in openLandmarkRegions where openLandmarkRegion != nil {
			landmarkPath.addPoints(in: openLandmarkRegion!,
								   applying: affineTransform,
								   closingWhenComplete: false)
		}
		
		for closedLandmarkRegion in closedLandmarkRegions {
			landmarkPath.addPoints(in: closedLandmarkRegion,
								   applying: affineTransform,
								   closingWhenComplete: true)
		}
		
		landmarkLayer.path = landmarkPath
		landmarkLayer.lineWidth = 2
		landmarkLayer.strokeColor = UIColor.green.cgColor
		landmarkLayer.fillColor = nil
		landmarkLayer.shadowOpacity = 0.75
		landmarkLayer.shadowRadius = 4
		
		landmarkLayer.anchorPoint = .zero
		landmarkLayer.frame = faceBounds
		landmarkLayer.transform = CATransform3DMakeScale(1, -1, 1)
		
		self.cameraView?.layer.addSublayer(landmarkLayer)
	}
	CATransaction.commit()
}

fileprivate func draw(text: [VNTextObservation], onImageWithBounds bounds: CGRect) {
	CATransaction.begin()
	for wordObservation in text {
		let wordBox = boundingBox(forRegionOfInterest: wordObservation.boundingBox, withinImageBounds: bounds)
		let wordLayer = shapeLayer(color: .red, frame: wordBox)
		
		self.cameraView?.layer.addSublayer(wordLayer)
		
		guard let charBoxes = wordObservation.characterBoxes else {
			continue
		}
		for charObservation in charBoxes {
			let charBox = boundingBox(forRegionOfInterest: charObservation.boundingBox, withinImageBounds: bounds)
			let charLayer = shapeLayer(color: .purple, frame: charBox)
			charLayer.borderWidth = 1
			self.cameraView?.layer.addSublayer(charLayer)
		}
	}
	CATransaction.commit()
}

fileprivate func draw(barcodes: [VNBarcodeObservation], onImageWithBounds bounds: CGRect) {
	CATransaction.begin()
	for observation in barcodes {
		let barcodeBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
		let barcodeLayer = shapeLayer(color: .orange, frame: barcodeBox)
		
		self.cameraView?.layer.addSublayer(barcodeLayer)
	}
	CATransaction.commit()
}
}

private extension CGMutablePath {
	func addPoints(in landmarkRegion: VNFaceLandmarkRegion2D,
				   applying affineTransform: CGAffineTransform,
				   closingWhenComplete closePath: Bool) {
		let pointCount = landmarkRegion.pointCount
		guard pointCount > 1 else {
			return
		}
		self.addLines(between: landmarkRegion.normalizedPoints, transform: affineTransform)
		
		if closePath {
			self.closeSubpath()
		}
	}
}

