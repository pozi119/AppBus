//
//  ViewController.swift
//  AppBus
//
//  Created by pozi119 on 09/11/2019.
//  Copyright (c) 2019 pozi119. All rights reserved.
//

import AppBus
import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        Bus.register(event: .default) { print("Event:\($0), object:\(String(describing: $1))") }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
