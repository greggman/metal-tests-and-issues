//
//  ViewController.swift
//  metaltest
//
//  Created by Gregg Tavares on 9/27/21.
//

import Cocoa
import Metal
import MetalKit

class ViewController: NSViewController {

    var mtkView: MTKView!
    var renderer: Renderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let mtkViewTemp = self.view as? MTKView else {
            print("View attached to ViewController is not an MTKView!")
            return
        }
        mtkView = mtkViewTemp

        let devicesWithObserver = MTLCopyAllDevicesWithObserver(handler: { (device, name) in
           // self.handleExternalGPUEvents(device: device, notification: name)
        });
        let deviceList = devicesWithObserver.devices
        //let deviceObserver = devicesWithObserver.observer
        let devices = deviceList// else { return }
                
        var externalGPUs = [MTLDevice]()
        var integratedGPUs = [MTLDevice]()
        var discreteGPUs = [MTLDevice]()
                
        for device in devices {
            if device.isRemovable {
                externalGPUs.append(device)
                print("// found external GPU: \(device)")
            } else if device.isLowPower {
                integratedGPUs.append(device)
                print("// found integrated GPU: \(device)")
            } else {
                discreteGPUs.append(device)
                print("// found discrete GPU: \(device)")
            }
        }
      mtkView.device = integratedGPUs.count > 0 ? integratedGPUs[0] : discreteGPUs[0];
        //mtkView.device = discreteGPUs[0];

        print("// using GPU: ", mtkView.device);
        
        guard let tempRenderer = Renderer(mtkView: mtkView) else {
            print("Renderer failed to initialize")
            return
        }
        renderer = tempRenderer

        mtkView.delegate = renderer
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

