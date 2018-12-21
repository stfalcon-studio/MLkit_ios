//
//  SettingsViewController.swift
//  Prizma
//
//  Created by Alex Frankiv on 31.08.18.
//  Copyright © 2018 Alex Frankiv. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController {
	
	//MARK: - IBOutlets
	@IBOutlet private weak var faceSwitch: UISwitch!
	@IBOutlet private weak var rectsSwitch: UISwitch!
	@IBOutlet private weak var textSwitch: UISwitch!
	@IBOutlet private weak var barcodeSwitch: UISwitch!
	@IBOutlet private var defaultSwitches: [UISwitch]!
	
	@IBOutlet private weak var customModelsSwitch: UISwitch!
	@IBOutlet private weak var containerView: UIView!
	
	// MARK: - Lifecycle
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		configureSwitches()
    }
	
	// MARK: - Configuration
	private func configureSwitches() {
		faceSwitch.isOn = Settings.provider.facesSelected
		rectsSwitch.isOn = Settings.provider.rectsSelected
		textSwitch.isOn = Settings.provider.textSelected
		barcodeSwitch.isOn = Settings.provider.barcodeSelected
		customModelsSwitch.isOn = Settings.provider.customModelsSelected
		UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: {
			self.containerView.isHidden = !self.customModelsSwitch.isOn
			self.containerView.alpha = self.customModelsSwitch.isOn ? 1 : 0
		}, completion: nil)
	}
	
	// MARK: - Behaviour
	@IBAction func switchValueChanged(_ sender: UISwitch) {
		switch sender {
		case faceSwitch:
			Settings.provider.facesSelected = faceSwitch.isOn
		case rectsSwitch:
			Settings.provider.rectsSelected = rectsSwitch.isOn
		case textSwitch:
			Settings.provider.textSelected = textSwitch.isOn
		case barcodeSwitch:
			Settings.provider.barcodeSelected = barcodeSwitch.isOn
		case customModelsSwitch:
			Settings.provider.customModelsSelected = customModelsSwitch.isOn
		default:
			() // intentionally nothing
		}
		configureSwitches()
	}
	
}
