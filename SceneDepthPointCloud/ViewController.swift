/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Main view controller for the AR experience.
 */

import UIKit
import Metal
import MetalKit
import ARKit

final class ViewController: UIViewController, ARSessionDelegate {
    private let isUIEnabled = true
    private let confidenceControl = UISegmentedControl(items: ["Low", "Medium", "High"])
    private let rgbRadiusSlider = UISlider()
    private let recordButton = UIButton()
    private let textLabel = UILabel()
    
    private var isRecording = false
    
    private var taskNum = 0;
    private var completedTaskNum = 0;
    
    private let session = ARSession()
    private var renderer: Renderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
        session.delegate = self
        
        // Set the view to use the default device
        if let view = view as? MTKView {
            view.device = device
            
            view.backgroundColor = UIColor.clear
            // we need this to enable depth test
            view.depthStencilPixelFormat = .depth32Float
            view.contentScaleFactor = 1
            view.delegate = self
            
            // Configure the renderer to draw to the view
            renderer = Renderer(session: session, metalDevice: device, renderDestination: view)
            renderer.drawRectResized(size: view.bounds.size)
            renderer.delegate = self
        }
        
        // Confidence control
        confidenceControl.backgroundColor = .white
        confidenceControl.selectedSegmentIndex = renderer.confidenceThreshold
        confidenceControl.addTarget(self, action: #selector(viewValueChanged), for: .valueChanged)
        
        // RGB Radius control
        rgbRadiusSlider.minimumValue = 0
        rgbRadiusSlider.maximumValue = 1.5
        rgbRadiusSlider.isContinuous = true
        rgbRadiusSlider.value = renderer.rgbRadius
        rgbRadiusSlider.addTarget(self, action: #selector(viewValueChanged), for: .valueChanged)
        
        // UIButton
        recordButton.setTitle("START", for: .normal)
        recordButton.backgroundColor = .systemBlue
        recordButton.layer.cornerRadius = 5
        recordButton.addTarget(self, action: #selector(onButtonClick), for: .touchUpInside)
        
        // UILabel
        textLabel.text = "  Files saved 0/0  "
        textLabel.textColor = .white
        textLabel.backgroundColor = UIColor.darkGray.withAlphaComponent(0.5)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.layer.masksToBounds = true
        textLabel.layer.cornerRadius = 8
//        textLabel.textAlignment = .right
        textLabel.sizeToFit()
        
        let stackView = UIStackView(arrangedSubviews: [confidenceControl, rgbRadiusSlider, recordButton])
        stackView.isHidden = !isUIEnabled
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 10
        view.addSubview(stackView)
        view.addSubview(textLabel)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            textLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            textLabel.heightAnchor.constraint(equalToConstant: 30),
//            textLabel.widthAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a world-tracking configuration, and
        // enable the scene depth frame-semantic.
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        
        // Run the view's session
        session.run(configuration)
        
        // The screen shouldn't dim during AR experiences.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        print("memory warning!!!")
        memoryAlert()
        updateIsRecording(_isRecording: false)
    }
    
    private func memoryAlert() {
        let alert = UIAlertController(title: "Low Memory Warning", message: "The recording has been paused. Do not quit the app until all files have been saved.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
            NSLog("The \"OK\" alert occured.")
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc
    private func viewValueChanged(view: UIView) {
        switch view {
            
        case confidenceControl:
            renderer.confidenceThreshold = confidenceControl.selectedSegmentIndex
            
        case rgbRadiusSlider:
            renderer.rgbRadius = rgbRadiusSlider.value
            
        default:
            break
        }
    }
    
    @objc
    private func onButtonClick(_ sender: UIButton) {
        if (sender != recordButton) {
            return
        }
        updateIsRecording(_isRecording: !isRecording)
    }
    
    private func updateIsRecording(_isRecording: Bool) {
        isRecording = _isRecording
        if (isRecording){
            recordButton.setTitle("PAUSE", for: .normal)
            recordButton.backgroundColor = .systemRed
            renderer.currentFolder = getTimeStr()
            createDirectory(folder: renderer.currentFolder + "/data")
        } else {
            recordButton.setTitle("START", for: .normal)
            recordButton.backgroundColor = .systemBlue
            renderer.savePointCloud()
        }
        renderer.isRecording = isRecording
    }
    
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // Hide the status bar to maximize immersion in AR experiences.
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                if let configuration = self.session.configuration {
                    self.session.run(configuration, options: .resetSceneReconstruction)
                }
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

// update textlabel on tasks start/finish
extension ViewController: TaskDelegate {
    func didStartTask() {
        self.taskNum += 1
        updateTextLabel()
    }
    
    func didFinishTask() {
        self.completedTaskNum += 1
        updateTextLabel()
    }
    
    private func updateTextLabel() {
        let text = "  Files saved \(self.completedTaskNum)/\(self.taskNum)  "
        DispatchQueue.main.async {
            self.textLabel.text = text
        }
    }
}

// MARK: - MTKViewDelegate

extension ViewController: MTKViewDelegate {
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
    }
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        renderer.draw()
    }
}

// MARK: - RenderDestinationProvider

protocol RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}

extension MTKView: RenderDestinationProvider {
    
}
