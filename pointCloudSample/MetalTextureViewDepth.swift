/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view that displays scene depth information.
*/

import Foundation
import SwiftUI
import MetalKit
import Metal

//- Tag: CoordinatorDepth
final class CoordinatorDepth: MTKCoordinator {
    @Binding var confSelection: Int
    init(depthContent: MetalTextureContent, confSelection: Binding<Int>) {
        self._confSelection = confSelection
        super.init(content: depthContent)
    }
    override func prepareFunctions() {
        guard let metalDevice = mtkView.device else { fatalError("Expected a Metal device.") }
        do {
            let library = EnvironmentVariables.shared.metalLibrary
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "planeVertexShader")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "planeFragmentShaderDepth")
            pipelineDescriptor.vertexDescriptor = createPlaneMetalVertexDescriptor()
            pipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Unexpected error: \(error).")
        }
    }

}

struct MetalTextureViewDepth: UIViewRepresentable {
    var content: MetalTextureContent
    
    @Binding var confSelection: Int
    func makeCoordinator() -> CoordinatorDepth {
        CoordinatorDepth(depthContent: content, confSelection: $confSelection)
    }
    
    func makeUIView(context: UIViewRepresentableContext<MetalTextureViewDepth>) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.backgroundColor = context.environment.colorScheme == .dark ? .black : .white
        context.coordinator.setupView(mtkView: mtkView)
        return mtkView
    }
    
    // `UIViewRepresentable` requires this implementation; however, the sample
    // app doesn't use it. Instead, `MTKView.delegate` handles display updates.
    func updateUIView(_ uiView: MTKView, context: UIViewRepresentableContext<MetalTextureViewDepth>) {
        
    }
}
