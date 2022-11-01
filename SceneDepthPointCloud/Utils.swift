//
//  Utils.swift
//  SceneDepthPointCloud
//
//  Created by Waley Zheng on 10/2/22.
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation
import UIKit
import VideoToolbox

/// Get current time in string.
func getTimeStr() -> String {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd hh:mm:ss"
    return df.string(from: Date())
}

/// Save file to a directory.
func saveFile(content: String, filename: String, folder: String) async throws -> () {
    print("Save file to \(folder)/\(filename)")
    let url = getDocumentsDirectory().appendingPathComponent(folder, isDirectory: true).appendingPathComponent(filename)
    try content.write(to: url, atomically: true, encoding: .utf8)
}

/// Save jpeg to a directory.
func savePic(pic: UIImage, filename: String, folder: String) async throws -> () {
    print("Save picture to \(folder)/\(filename)")
    let url = getDocumentsDirectory().appendingPathComponent(folder, isDirectory: true).appendingPathComponent(filename)
    try pic.jpegData(compressionQuality: 0)?.write(to: url)
}

/// Transform cvPixelBuffer to a 2D array depth map.
func cvPixelBuffer2DepthMap(rawDepth: CVPixelBuffer) async -> [[Float32]] {
    CVPixelBufferLockBaseAddress(rawDepth, CVPixelBufferLockFlags(rawValue: 0))
    let addr = CVPixelBufferGetBaseAddress(rawDepth)
    let height = CVPixelBufferGetHeight(rawDepth)
    let width = CVPixelBufferGetWidth(rawDepth)
    
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

/// Transform cvPixelBuffer to a UIImage.
func cvPixelBuffer2UIImage(pixelBuffer: CVPixelBuffer) -> UIImage {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    return UIImage(ciImage: ciImage)
}

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

/// https://stackoverflow.com/questions/63661474/how-can-i-encode-an-array-of-simd-float4x4-elements-in-swift-convert-simd-float
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

extension simd_float3x3: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        try self.init(container.decode([SIMD3<Float>].self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode([columns.0, columns.1, columns.2])
    }
}

/// Deep copy a CVPixelBuffer for image (not working on depth data)
/// http://stackoverflow.com/questions/38335365/pulling-data-from-a-cmsamplebuffer-in-order-to-create-a-deep-copy
extension CVPixelBuffer
{
    func copy() -> CVPixelBuffer {
        precondition(CFGetTypeID(self) == CVPixelBufferGetTypeID(), "copy() cannot be called on a non-CVPixelBuffer")
        
        var _copy: CVPixelBuffer?
        
        CVPixelBufferCreate(
            nil,
            CVPixelBufferGetWidth(self),
            CVPixelBufferGetHeight(self),
            CVPixelBufferGetPixelFormatType(self),
            CVBufferGetAttachments(self, .shouldPropagate),
            &_copy)
        
        guard let copy = _copy else { fatalError() }
        
        CVPixelBufferLockBaseAddress(self, .readOnly)
        CVPixelBufferLockBaseAddress(copy, [])
        defer
        {
            CVPixelBufferUnlockBaseAddress(copy, [])
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
        }
        
        for plane in 0 ..< CVPixelBufferGetPlaneCount(self)
        {
            let dest        = CVPixelBufferGetBaseAddressOfPlane(copy, plane)
            let source      = CVPixelBufferGetBaseAddressOfPlane(self, plane)
            let height      = CVPixelBufferGetHeightOfPlane(self, plane)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(self, plane)
            
            memcpy(dest, source, height * bytesPerRow)
        }
        
        return copy
    }
}

/// Send task start/finish messages.
protocol TaskDelegate: AnyObject {
    func didStartTask()
    func didFinishTask()
}

/// Deep copy CVPixelBuffer for depth data
/// https://stackoverflow.com/questions/65868215/deep-copy-cvpixelbuffer-for-depth-data-in-swift
func duplicatePixelBuffer(input: CVPixelBuffer) -> CVPixelBuffer {
    var copyOut: CVPixelBuffer?
    let bufferWidth = CVPixelBufferGetWidth(input)
    let bufferHeight = CVPixelBufferGetHeight(input)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(input)
    let bufferFormat = CVPixelBufferGetPixelFormatType(input)
        
    _ = CVPixelBufferCreate(kCFAllocatorDefault, bufferWidth, bufferHeight, bufferFormat, CVBufferGetAttachments(input, CVAttachmentMode.shouldPropagate), &copyOut)
    let output = copyOut!
    // Lock the depth map base address before accessing it
    CVPixelBufferLockBaseAddress(input, CVPixelBufferLockFlags.readOnly)
    CVPixelBufferLockBaseAddress(output, CVPixelBufferLockFlags(rawValue: 0))
    let baseAddress = CVPixelBufferGetBaseAddress(input)
    let baseAddressCopy = CVPixelBufferGetBaseAddress(output)
    memcpy(baseAddressCopy, baseAddress, bufferHeight * bytesPerRow)
        
    // Unlock the base address when finished accessing the buffer
    CVPixelBufferUnlockBaseAddress(input, CVPixelBufferLockFlags.readOnly)
    CVPixelBufferUnlockBaseAddress(output, CVPixelBufferLockFlags(rawValue: 0))
    return output
}
