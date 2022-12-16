//
//  ViewController.swift
//  metaltest
//
//  Created by Gregg Tavares on 9/27/21.
//

import Cocoa
import Metal
import MetalKit

enum GPUType {
    case Integrated
    case Discrete
}

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
        mtkView.drawableSize = CGSize(width: 512, height: 512)

        let device = ViewController.chooseDevice(gpuType: .Integrated)
        //let device = ViewController.chooseDevice(gpuType: .Discrete)
        print("My GPU is: \(device)")
        mtkView.device = device;
        
        guard let tempRenderer = Renderer(mtkView: mtkView) else {
            print("Renderer failed to initialize")
            return
        }
        renderer = tempRenderer

        mtkView.delegate = renderer
    }

    class func chooseDevice(gpuType: GPUType) -> MTLDevice {
        let devicesWithObserver = MTLCopyAllDevicesWithObserver(handler: { (device, name) in
           // self.handleExternalGPUEvents(device: device, notification: name)
        });
        let deviceList = devicesWithObserver.devices
        let devices = deviceList
                
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
        
        switch gpuType {
        case .Integrated:
            return integratedGPUs.count > 0 ? integratedGPUs[0] : devices[0];
        case .Discrete:
            return discreteGPUs.count > 0 ? discreteGPUs[0] : devices[0];
        }
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

