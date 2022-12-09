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

        
        
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }

        mtkView.device = defaultDevice
        
        /*
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
                print("external GPU: \(device)")
            } else if device.isLowPower {
                integratedGPUs.append(device)
                print("integrated GPU: \(device)")
            } else {
                discreteGPUs.append(device)
                print("discrete GPU: \(device)")
            }
        }
        //mtkView.device = integratedGPUs[0];
        mtkView.device = discreteGPUs[0];
        */
        print("using GPU:", mtkView.device);
        
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

