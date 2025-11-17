// main.swift
//
// compile with:
//    xcrun swiftc -o main main.swift -framework Metal -framework MetalKit -framework Foundation
//
// run with:
//    ./main
//
import Metal
import Foundation

func main() {
    let devices = MTLCopyAllDevices()
    guard !devices.isEmpty else {
        fatalError("No Metal devices found.")
    }

    for device in devices {
        print("Testing device: \(device.name)")
        runOnDevice(on: device)
    }
}

func runOnDevice(on device: MTLDevice) {
    let kNumPerStep = 64 * 1024;
    var count = 0;
    var id = 0;

    var numberToObjectMap: [Int: MTLBuffer] = [:]
    while id < 4096 * 1024 {
        let startTime = CACurrentMediaTime() // Record start time
        for _ in 0...(kNumPerStep) {
            let buffer = device.makeBuffer(length: 16, options: [])!
            numberToObjectMap[id] = buffer
            id += 1
        }
        let endTime = CACurrentMediaTime() // Record end time
        let duration = endTime - startTime
        let perIterationTime = duration / Double(kNumPerStep + 1) // kNumPerStep is inclusive, so kNumPerStep + 1 iterations

        count += kNumPerStep;
        print("count: \(count), duration: \(duration)s, item time: \(perIterationTime)s\n")
    }

    exit(0)
}

main()
