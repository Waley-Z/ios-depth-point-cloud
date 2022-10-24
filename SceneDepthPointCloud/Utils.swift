//
//  FileManager.swift
//  SceneDepthPointCloud
//
//  Created by Waley Zheng on 10/2/22.
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation
import UIKit
import VideoToolbox

func getTimeStr() -> String {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd hh:mm:ss"
    return df.string(from: Date())
}

func saveStr(content: String, filename: String, folder: String) async throws -> () {
    print("Save file to \(folder)/\(filename)")
    let url = getDocumentsDirectory().appendingPathComponent(folder, isDirectory: true).appendingPathComponent(filename)
    try content.write(to: url, atomically: true, encoding: .utf8)
//        let input = try String(contentsOf: url)
//        print(input)
}

func savePic(pic: UIImage, filename: String, folder: String) async throws -> () {
    print("Save picture to \(folder)/\(filename)")
    let url = getDocumentsDirectory().appendingPathComponent(folder, isDirectory: true).appendingPathComponent(filename)
    try pic.jpegData(compressionQuality: 0)?.write(to: url)
}

func cvPixelBuffer2DepthMap(rawDepth: CVPixelBuffer) async -> [[Float32]] {
    CVPixelBufferLockBaseAddress(rawDepth, CVPixelBufferLockFlags(rawValue: 0))
    let addr = CVPixelBufferGetBaseAddress(rawDepth)
    let height = CVPixelBufferGetHeight(rawDepth)
    let width = CVPixelBufferGetWidth(rawDepth)
//    let bpr = CVPixelBufferGetBytesPerRow(rawDepth)
    
    let floatBuffer = unsafeBitCast(addr, to: UnsafeMutablePointer<Float32>.self)
    
    var depthMap = Array(repeating: [Float32](repeating: 0, count: width), count: height)
    
    for row in 0...(height - 1){
        for col in 0...(width - 1){
            depthMap[row][col] = floatBuffer[row * width + col]
        }
    }
    CVPixelBufferUnlockBaseAddress(rawDepth, CVPixelBufferLockFlags(rawValue: 0))
    return depthMap
}

//func saveDepthMap(depthMap: CVPixelBuffer, filename: String) -> () {
//    print("Save depth map to \(filename)")
//    CVPixelBufferLockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
//    let addr = CVPixelBufferGetBaseAddress(depthMap)
//    let height = CVPixelBufferGetHeight(depthMap)
//    let bpr = CVPixelBufferGetBytesPerRow(depthMap)
//
//    let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthMap), to: UnsafeMutablePointer<Float32>.self)
//
//
//
//    let data = Data(bytes: addr!, count: (bpr*height))
//    CVPixelBufferUnlockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
//
//
//    let url = getDocumentsDirectory().appendingPathComponent(filename)
//    do {
//       try data.write(to: url)
//    } catch {
//        print(error.localizedDescription)
//    }
//}

func getDocumentsDirectory() -> URL {
    // find all possible documents directories for this user
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)

    // just send back the first one, which ought to be the only one
    return paths[0]
}

func createDirectory(folder: String) {
    let path = getDocumentsDirectory().appendingPathComponent(folder)
    do
    {
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
    }
    catch let error as NSError
    {
        print("Unable to create directory \(error.debugDescription)")
    }
    
}

extension simd_float4x4: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        try self.init(container.decode([SIMD4<Float>].self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode([columns.0, columns.1, columns.2, columns.3])
    }
}

func cvPixelBuffer2UIImage(pixelBuffer: CVPixelBuffer) -> UIImage {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    return UIImage(ciImage: ciImage)
    
}
