//
//  MainSplitViewController.swift
//  vivarium-studio
//
//  Created by Roy Li on 1/24/26.
//

import Cocoa

class MainSplitViewController: NSSplitViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        splitViewItems.first?.minimumThickness = 220
        splitViewItems.first?.maximumThickness = 220
        splitViewItems.last?.isCollapsed = true
    }
    
}
