//
//  CustomModelsTableViewController.swift
//  Prizma
//
//  Created by Alex Frankiv on 02.09.18.
//  Copyright © 2018 Alex Frankiv. All rights reserved.
//

import UIKit

class CustomModelTableViewCell: UITableViewCell {
	
	@IBOutlet private weak var nameLabel: UILabel!
	
	var model: CustomModel? {
		didSet { nameLabel.text = model?.name }
	}
}

class CustomModelsTableViewController: UITableViewController {

	// MARK: - Lifecyce
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if let index = CustomModel.cases.index(of: Settings.provider.currentModel) {
			tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .middle)
		}
	}
	
    // MARK: - Table view data source & delegate
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CustomModel.cases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let cell = tableView.dequeueReusableCell(withIdentifier: "customModelCell", for: indexPath) as? CustomModelTableViewCell else {
			fatalError("Illegal cell reuse ID")
		}
		cell.model = CustomModel.cases[indexPath.row]
		cell.isSelected = (Settings.provider.currentModel == cell.model)
        return cell
    }

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		Settings.provider.currentModel = CustomModel.cases[indexPath.row]
	}
}
