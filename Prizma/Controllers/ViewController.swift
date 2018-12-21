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

	@IBOutlet private weak var cameraView: UIView!
	@IBOutlet private weak var resultLabel: UILabel!
	
	override var prefersStatusBarHidden: Bool {
		return true
	}
	
	// set up the handler for the captured images
	private let visionSequenceHandler = VNSequenceRequestHandler()
	
	// set up the camera preview layer
	private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
	
	// set up the capture session
	private lazy var captureSession: AVCaptureSession = {
		let session = AVCaptureSession()
		session.sessionPreset = AVCaptureSession.Preset.photo
		
		// set up the rear camera as the device to capture images from
		guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera,
													 for: .video,
													 position: .back),
			let input = try? AVCaptureDeviceInput(device: backCamera)
			else {
				print("no camera is available.");
				return session
				
		}
		// add the rear camera as the capture device
		session.addInput(input)
		return session
	}()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// add the camera preview
		self.cameraView?.layer.addSublayer(self.cameraLayer)
		
		// set up the delegate to handle the images to be fed to Core ML
		let videoOutput = AVCaptureVideoDataOutput()
		
		// we want to process the image buffer and ML off the main thread
		videoOutput.setSampleBufferDelegate(self,
											queue: DispatchQueue(label: "DispatchQueue"))
		
		self.captureSession.addOutput(videoOutput)
		
		// make the camera output fill the screen
		cameraLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
		
		// begin the session
		self.captureSession.startRunning()
	}
	
	@IBAction func moveToSettings(_ sender: Any?) {
		if (sender as? UIScreenEdgePanGestureRecognizer)?.state == .ended {
			performSegue(withIdentifier: "toSettings", sender: sender)
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.navigationController?.navigationBar.isHidden = true
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		self.navigationController?.navigationBar.isHidden = false
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		
		// make sure the layer is the correct size
		self.cameraLayer.frame = (self.cameraView?.frame)!
	}
	
	// MARK: - Detection requests
	lazy var rectangleDetectionRequest: VNDetectRectanglesRequest = {
		let rectDetectRequest = VNDetectRectanglesRequest(completionHandler: self.handleDetectedRectangles)
		// Customize & configure the request to detect only certain rectangles.
		rectDetectRequest.maximumObservations = 8 // Vision currently supports up to 16.
		rectDetectRequest.minimumConfidence = 0.6 // Be confident.
		rectDetectRequest.minimumAspectRatio = 0.3 // height / width
		return rectDetectRequest
	}()
	
	lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: self.handleDetectedFaces)
	lazy var faceLandmarkRequest = VNDetectFaceLandmarksRequest(completionHandler: self.handleDetectedFaceLandmarks)
	
	lazy var textDetectionRequest: VNDetectTextRectanglesRequest = {
		let textDetectRequest = VNDetectTextRectanglesRequest(completionHandler: self.handleDetectedText)
		// Tell Vision to report bounding box around each character.
		textDetectRequest.reportCharacterBoxes = true
		return textDetectRequest
	}()
	
	lazy var barcodeDetectionRequest: VNDetectBarcodesRequest = {
		let barcodeDetectRequest = VNDetectBarcodesRequest(completionHandler: self.handleDetectedBarcodes)
		// Restrict detection to most common symbologies.
		barcodeDetectRequest.symbologies = [.QR, .Aztec, .UPCE]
		return barcodeDetectRequest
	}()
}

// MARK: - ML Stuff

extension MainViewController {
	
	func captureOutput(_ output: AVCaptureOutput,
					   didOutput sampleBuffer: CMSampleBuffer,
					   from connection: AVCaptureConnection) {
		
		// Get the pixel buffer from the capture session
		guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
		
		// load the Core ML model
		guard let visionModel:VNCoreMLModel = try? VNCoreMLModel(for: Inceptionv3().model) else { return }
		
		//  set up the classification request
//		let classificationRequest = VNCoreMLRequest(model: visionModel,
//													completionHandler: handleClassification)
//
//		// automatically resize the image from the pixel buffer to fit what the model needs
//		classificationRequest.imageCropAndScaleOption = .centerCrop
//
//		// perform the machine learning classification
//		do {
//			try self.visionSequenceHandler.perform([classificationRequest], on: pixelBuffer)
//		} catch {
//			print("Throws: \(error)")
//		}
		
		// Convert from UIImageOrientation to CGImagePropertyOrientation.
		let cgOrientation = CGImagePropertyOrientation(UIDevice.current.orientation)

		// Fire off request based on URL of chosen photo.
		guard let cgImage = UIImage(pixelBuffer: pixelBuffer)?.cgImage else {
			return
		}
		DispatchQueue.main.async {
			self.cameraView.layer.sublayers?.forEach({ if $0 != self.cameraLayer { $0.removeFromSuperlayer() } })
		}
		performVisionRequest(image: cgImage,
							 orientation: cgOrientation)
	}
	
	fileprivate func performVisionRequest(image: CGImage, orientation: CGImagePropertyOrientation) {
		
		// Fetch desired requests based on switch status.
		let requests = [
//			rectangleDetectionRequest//,
			faceLandmarkRequest,
			faceDetectionRequest//,
//			textDetectionRequest//,
//			barcodeDetectionRequest
		]
		// Create a request handler.
		let imageRequestHandler = VNImageRequestHandler(cgImage: image,
														orientation: orientation,
														options: [:])
		
		// Send the requests to the request handler.
		DispatchQueue.global(qos: .userInitiated).async {
			do {
				try imageRequestHandler.perform(requests)
			} catch let error as NSError {
				print("Failed to perform image request: \(error)")
				self.presentAlert("Image Request Failed", error: error)
				return
			}
		}
	}
	
	// MARK: - Old handling
	
	func updateClassificationLabel(labelString: String) {
		// We processed the capture session and Core ML off the main thread, so the completion handler was called onthe the same thread
		// So we need to remember to get the main thread again to update the UI
		
		DispatchQueue.main.async {
			self.resultLabel?.text = labelString
		}
	}
	
	func handleClassification(request: VNRequest,
							  error: Error?) {
		guard let observations = request.results else {
			
			// Nothing has been returned so we want to clear the label.
			updateClassificationLabel(labelString: "")
			
			return
		}
		
		let classifications = observations[0...3] //taking just the top 3, ignoring the rest
			.compactMap({ $0 as? VNClassificationObservation}) // discard any erroneous results
			.filter({ $0.confidence > 0.2 }) // discard anything with less than 20% accuracy.
			.map(self.textForClassification) // get the text to display
		// Filter further here if you're looking for specific objects
		
		if (classifications.count > 0) {
			// update the label to display what we found
			updateClassificationLabel(labelString: "\(classifications.joined(separator: "\n"))")
		} else {
			// nothing matches our criteria, so clear the label
			updateClassificationLabel(labelString: "")
		}
	}
	
	func textForClassification(classification: VNClassificationObservation) -> String {
		// Mapping the results from the VNClassificationObservation to a human readable string
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
		// Since handlers are executing on a background thread, explicitly send draw calls to the main thread.
		DispatchQueue.main.async {
			guard let drawLayer = self.cameraView?.layer,
				let results = request?.results as? [VNRectangleObservation] else {
					return
			}
			self.draw(rectangles: results, onImageWithBounds: drawLayer.bounds)
			drawLayer.setNeedsDisplay()
		}
	}
	
	fileprivate func handleDetectedFaces(request: VNRequest?, error: Error?) {
		if let nsError = error as NSError? {
			self.presentAlert("Face Detection Error", error: nsError)
			return
		}
		// Perform drawing on the main thread.
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
		// Perform drawing on the main thread.
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
		// Perform drawing on the main thread.
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
		// Perform drawing on the main thread.
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
	
	/// - Tag: PreprocessImage
	func scaleAndOrient(image: UIImage) -> UIImage {
		
		// Set a default value for limiting image size.
		let maxResolution: CGFloat = 640
		
		guard let cgImage = image.cgImage else {
			print("UIImage has no CGImage backing it!")
			return image
		}
		
		// Compute parameters for transform.
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
		// Always present alert on main thread.
		DispatchQueue.main.async {
			let alertController = UIAlertController(title: title,
													message: error.localizedDescription,
													preferredStyle: .alert)
			let okAction = UIAlertAction(title: "OK",
										 style: .default) { _ in
											// Do nothing -- simply dismiss alert.
			}
			alertController.addAction(okAction)
			self.present(alertController, animated: true, completion: nil)
		}
	}

// MARK: - Path-Drawing

fileprivate func boundingBox(forRegionOfInterest: CGRect, withinImageBounds bounds: CGRect) -> CGRect {
	
	let imageWidth = bounds.width
	let imageHeight = bounds.height
	
	// Begin with input rect.
	var rect = forRegionOfInterest
	
	// Reposition origin.
	rect.origin.x *= imageWidth
	rect.origin.x += bounds.origin.x
	rect.origin.y = (1 - rect.origin.y) * imageHeight + bounds.origin.y
	
	// Rescale normalized coordinates.
	rect.size.width *= imageWidth
	rect.size.height *= imageHeight
	
	return rect
}

fileprivate func shapeLayer(color: UIColor, frame: CGRect) -> CAShapeLayer {
	// Create a new layer.
	let layer = CAShapeLayer()
	
	// Configure layer's appearance.
	layer.fillColor = nil // No fill to show boxed object
	layer.shadowOpacity = 0
	layer.shadowRadius = 0
	layer.borderWidth = 2
	
	// Vary the line color according to input.
	layer.borderColor = color.cgColor
	
	// Locate the layer.
	layer.anchorPoint = .zero
	layer.frame = frame
	layer.masksToBounds = true
	
	// Transform the layer to have same coordinate system as the imageView underneath it.
	layer.transform = CATransform3DMakeScale(1, -1, 1)
	
	return layer
}

// Rectangles are BLUE.
fileprivate func draw(rectangles: [VNRectangleObservation], onImageWithBounds bounds: CGRect) {
	CATransaction.begin()
	for observation in rectangles {
		let rectBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
		let rectLayer = shapeLayer(color: .blue, frame: rectBox)
		
		// Add to pathLayer on top of image.
		self.cameraView?.layer.addSublayer(rectLayer)
	}
	CATransaction.commit()
}

// Faces are YELLOW.
/// - Tag: DrawBoundingBox
fileprivate func draw(faces: [VNFaceObservation], onImageWithBounds bounds: CGRect) {
	CATransaction.begin()
	for observation in faces {
		let faceBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
		let faceLayer = shapeLayer(color: .yellow, frame: faceBox)
		
		// Add to pathLayer on top of image.
		self.cameraView?.layer.addSublayer(faceLayer)
	}
	CATransaction.commit()
}

// Facial landmarks are GREEN.
fileprivate func drawFeatures(onFaces faces: [VNFaceObservation], onImageWithBounds bounds: CGRect) {
	CATransaction.begin()
	for faceObservation in faces {
		let faceBounds = boundingBox(forRegionOfInterest: faceObservation.boundingBox, withinImageBounds: bounds)
		guard let landmarks = faceObservation.landmarks else {
			continue
		}
		
		// Iterate through landmarks detected on the current face.
		let landmarkLayer = CAShapeLayer()
		let landmarkPath = CGMutablePath()
		let affineTransform = CGAffineTransform(scaleX: faceBounds.size.width, y: faceBounds.size.height)
		
		// Treat eyebrows and lines as open-ended regions when drawing paths.
		let openLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
			landmarks.leftEyebrow,
			landmarks.rightEyebrow,
			landmarks.faceContour,
			landmarks.noseCrest,
			landmarks.medianLine
		]
		
		// Draw eyes, lips, and nose as closed regions.
		let closedLandmarkRegions = [
			landmarks.leftEye,
			landmarks.rightEye,
			landmarks.outerLips,
			landmarks.innerLips,
			landmarks.nose
			].compactMap { $0 } // Filter out missing regions.
		
		// Draw paths for the open regions.
		for openLandmarkRegion in openLandmarkRegions where openLandmarkRegion != nil {
			landmarkPath.addPoints(in: openLandmarkRegion!,
								   applying: affineTransform,
								   closingWhenComplete: false)
		}
		
		// Draw paths for the closed regions.
		for closedLandmarkRegion in closedLandmarkRegions {
			landmarkPath.addPoints(in: closedLandmarkRegion,
								   applying: affineTransform,
								   closingWhenComplete: true)
		}
		
		// Format the path's appearance: color, thickness, shadow.
		landmarkLayer.path = landmarkPath
		landmarkLayer.lineWidth = 2
		landmarkLayer.strokeColor = UIColor.green.cgColor
		landmarkLayer.fillColor = nil
		landmarkLayer.shadowOpacity = 0.75
		landmarkLayer.shadowRadius = 4
		
		// Locate the path in the parent coordinate system.
		landmarkLayer.anchorPoint = .zero
		landmarkLayer.frame = faceBounds
		landmarkLayer.transform = CATransform3DMakeScale(1, -1, 1)
		
		// Add to pathLayer on top of image.
		self.cameraView?.layer.addSublayer(landmarkLayer)
	}
	CATransaction.commit()
}

// Lines of text are RED.  Individual characters are PURPLE.
fileprivate func draw(text: [VNTextObservation], onImageWithBounds bounds: CGRect) {
	CATransaction.begin()
	for wordObservation in text {
		let wordBox = boundingBox(forRegionOfInterest: wordObservation.boundingBox, withinImageBounds: bounds)
		let wordLayer = shapeLayer(color: .red, frame: wordBox)
		
		// Add to pathLayer on top of image.
		self.cameraView?.layer.addSublayer(wordLayer)
		
		// Iterate through each character within the word and draw its box.
		guard let charBoxes = wordObservation.characterBoxes else {
			continue
		}
		for charObservation in charBoxes {
			let charBox = boundingBox(forRegionOfInterest: charObservation.boundingBox, withinImageBounds: bounds)
			let charLayer = shapeLayer(color: .purple, frame: charBox)
			charLayer.borderWidth = 1
			
			// Add to pathLayer on top of image.
			self.cameraView?.layer.addSublayer(charLayer)
		}
	}
	CATransaction.commit()
}

// Barcodes are ORANGE.
fileprivate func draw(barcodes: [VNBarcodeObservation], onImageWithBounds bounds: CGRect) {
	CATransaction.begin()
	for observation in barcodes {
		let barcodeBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
		let barcodeLayer = shapeLayer(color: .orange, frame: barcodeBox)
		
		// Add to pathLayer on top of image.
		self.cameraView?.layer.addSublayer(barcodeLayer)
	}
	CATransaction.commit()
}
}

private extension CGMutablePath {
	// Helper function to add lines to a path.
	func addPoints(in landmarkRegion: VNFaceLandmarkRegion2D,
				   applying affineTransform: CGAffineTransform,
				   closingWhenComplete closePath: Bool) {
		let pointCount = landmarkRegion.pointCount
		
		// Draw line if and only if path contains multiple points.
		guard pointCount > 1 else {
			return
		}
		self.addLines(between: landmarkRegion.normalizedPoints, transform: affineTransform)
		
		if closePath {
			self.closeSubpath()
		}
	}
}

