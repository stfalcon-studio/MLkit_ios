//
//  Settings.swift
//  Prizma
//
//  Created by Alex Frankiv on 02.09.18.
//  Copyright © 2018 Alex Frankiv. All rights reserved.
//

import Foundation


class Settings: Codable {
	
	// MARK: - Singleton
	static var provider = Settings() {
		didSet {
			provider.save()
		}
	}
	
	// MARK: - Properties
	var currentModel: CustomModel = .inceptionV3
	var customModelsSelected = true {
		didSet { if customModelsSelected { didSelectCustom() } }
	}
	var facesSelected = false {
		didSet { if facesSelected { customModelsSelected = false} }
	}
	var rectsSelected = false {
		didSet { if rectsSelected { customModelsSelected = false } }
	}
	var textSelected = false {
		didSet { if textSelected { customModelsSelected = false } }
	}
	var barcodeSelected = false {
		didSet { if barcodeSelected { customModelsSelected = false } }
	}
	
	// MARK: - Consistency
	private func didSelectCustom() {
		facesSelected = false
		rectsSelected = false
		textSelected = false
		barcodeSelected = false
	}
	
	// MARK: - Persistance
	func save() {
		UserDefaults.standard.set(try? PropertyListEncoder().encode(self), forKey:"kSettingsProvider")
	}
	
	static func load() {
		guard let settingsData = UserDefaults.standard.data(forKey: "kSettingsProvider"),
		let settings = try? PropertyListDecoder().decode(self, from: settingsData) else {
			Settings.provider = Settings(); return
		}
		Settings.provider = settings
	}
}
