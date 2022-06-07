/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A parent view class that displays the sample app's other views.
*/

import Foundation
import SwiftUI
import MetalKit
import ARKit

// Add a title to a view that enlarges the view to full screen on tap.
struct Texture<T: View>: ViewModifier {
    let height: CGFloat
    let width: CGFloat
    let title: String
    let view: T
    func body(content: Content) -> some View {
        VStack {
            Text(title).foregroundColor(Color.red)
            // To display the same view in the navigation, reference the view
            // directly versus using the view's `content` property.
            NavigationLink(destination: view.aspectRatio(CGSize(width: width, height: height), contentMode: .fill)) {
                view.frame(maxWidth: width, maxHeight: height, alignment: .center)
                    .aspectRatio(CGSize(width: width, height: height), contentMode: .fill)
            }
        }
    }
}

extension View {
    // Apply `zoomOnTapModifier` with a `self` reference to show the same view
    // on tap.
    func zoomOnTapModifier(height: CGFloat, width: CGFloat, title: String) -> some View {
        modifier(Texture(height: height, width: width, title: title, view: self))
    }
}
extension Image {
    init(_ texture: MTLTexture, ciContext: CIContext, scale: CGFloat, orientation: Image.Orientation, label: Text) {
        let ciimage = CIImage(mtlTexture: texture)!
        let cgimage = ciContext.createCGImage(ciimage, from: ciimage.extent)
        self.init(cgimage!, scale: 1.0, orientation: orientation, label: label)
    }
}
//- Tag: MetalDepthView
struct MetalDepthView: View {
    
    // Set the default sizes for the texture views.
    let sizeH: CGFloat = 256
    let sizeW: CGFloat = 192
    
    // Manage the AR session and AR data processing.
    //- Tag: ARProvider
    var arProvider: ARProvider = ARProvider()
    let ciContext: CIContext = CIContext()
    
    // Save the user's confidence selection.
    @State private var selectedConfidence = 0
    // Set the depth view's state data.
    @State var isToUpsampleDepth = false
    @State var isShowSmoothDepth = false
    @State var isArPaused = false
    @State private var scaleMovement: Float = 1.5
    
    var confLevels = ["🔵🟢🔴", "🔵🟢", "🔵"]
    
    var body: some View {
        if !ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) {
            Text("Unsupported Device: This app requires the LiDAR Scanner to access the scene's depth.")
        } else {
            NavigationView {
                GeometryReader { geometry in
                    VStack() {
                        // Size the point cloud view relative to the underlying
                        // 3D geometry by matching the textures' aspect ratio.
                        HStack() {
                            Spacer()
                            MetalPointCloud(arData: arProvider,
                                            confSelection: $selectedConfidence,
                                            scaleMovement: $scaleMovement).zoomOnTapModifier(
                                                height: geometry.size.width / 2 / sizeW * sizeH,
                                                width: geometry.size.width / 2, title: "")
                            Spacer()
                        }
                        HStack {
                            Text("Confidence Select:")
                            Picker(selection: $selectedConfidence, label: Text("Confidence Select")) {
                                ForEach(0..<confLevels.count, id: \.self) { index in
                                    Text(self.confLevels[index]).tag(index)
                                }
                                
                            }.pickerStyle(SegmentedPickerStyle())
                        }.padding(.horizontal)
                        HStack {
                            Text("Scale Movement: ")
                            Slider(value: $scaleMovement, in: -3...10, step: 0.5)
                            Text(String(format: "%.1f", scaleMovement))
                        }.padding(.horizontal)
                        HStack {
                            Toggle("Guided Filter", isOn: $isToUpsampleDepth).onChange(of: isToUpsampleDepth) { _ in
                                isToUpsampleDepth.toggle()
                                arProvider.isToUpsampleDepth = isToUpsampleDepth
                            }.frame(width: 160, height: 30)
                            Toggle("Smooth", isOn: $isShowSmoothDepth).onChange(of: isShowSmoothDepth) { _ in
                                isShowSmoothDepth.toggle()
                                arProvider.isUseSmoothedDepthForUpsampling = isShowSmoothDepth
                            }.frame(width: 160, height: 30)
                            Spacer()
                            Button(action: {
                                isArPaused.toggle()
                                isArPaused ? arProvider.pause() : arProvider.start()
                            }) {
                                Image(systemName: isArPaused ? "play.circle" : "pause.circle").resizable().frame(width: 30, height: 30)
                            }
                        }.padding(.horizontal)
                        
                        ScrollView(.horizontal) {
                            HStack() {
                                MetalTextureViewDepth(content: arProvider.depthContent, confSelection: $selectedConfidence)
                                    .zoomOnTapModifier(height: sizeH, width: sizeW, title: isToUpsampleDepth ? "Upscaled Depth" : "Depth")
                                MetalTextureViewConfidence(content: arProvider.confidenceContent)
                                    .zoomOnTapModifier(height: sizeH, width: sizeW, title: "Confidence")
                                if isToUpsampleDepth {
                                    VStack {
                                        Text("Upscale Coefficients").foregroundColor(Color.red)
                                        MetalTextureViewCoefs(content: arProvider.upscaledCoef).frame(maxWidth: sizeW,
                                                                                                      maxHeight: sizeH,
                                                                                                      alignment: .center)
                                    }
                                    
                                }
                                
                            }
                        }
                        Spacer()
                    }
                }
            }.navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
struct MtkView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MetalDepthView().previewDevice("iPad Pro (12.9-inch) (4th generation)")
            MetalDepthView().previewDevice("iPhone 11 Pro")
        }
    }
}
