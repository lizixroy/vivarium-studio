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
        
        print("items: \(splitViewItems)")
        splitViewItems.last?.isCollapsed = true
    }
    
}
