//
//  ViewController.swift
//  AR Pictionary
//
//  Created by 21djl5 on 11/19/18.
//  Copyright © 2018 davidjlee. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Canvas

extension CGPoint {
  public init(_ x : Float, _ y : Float) {
    self.init(x: Double(x), y: Double(y))
  }
}

/// Controls the AR view and updates the model.
class ViewController: UIViewController, ARSCNViewDelegate {
  
  /// AR view
  @IBOutlet var sceneView: ARSCNView!
  
  /// Computed property to make the AR view's root node more accessible
  private var rootNode : SCNNode {
    return sceneView.scene.rootNode
  }
  
  /// Line stroke parameters
  private let lineRadius : CGFloat = 0.001
  private let lineColor : UIColor = UIColor.white
  private let lineDetail : Int = 9
  
  /// Model: collection of Polylines
  private var lines : [Polyline] = []
  
  /// Tracks whether user currently has their finger on the phone screen
  /// (i.e. whether in active drawing state)
  private var touched : Bool = false
  
  /**
   Coordinates response to user screen presses.
   
   **Modifies**: lines, touched, sceneView
   
   **Effects**:
   - When user starts pressing the screen, adds a new line to
      model and draws a point in sceneView.  Sets touched true.
   - While user is still pressing the screen, draws a point in sceneView
      and adds to model.
   - When user is done pressing the screen, sets touched false,
      ending point-draw queueing.
   
   */
  @IBAction func pressed(_ sender: UILongPressGestureRecognizer) {
    switch sender.state {
    case .began:
      touched = true
      lines.append(Polyline())
      fallthrough
    case .changed:
      drawPoint()
    case .ended:
      touched = false
    default:
      break
    }
  }
  
  /**
   Matrix for camera transform that gives the position at which new points
   should be drawn.
  */
  private let deviceToDrawpointTranslation : matrix_float4x4 =
    matrix_float4x4(rows:
      [
        float4([1, 0, 0, 0.0025 * 0.6]), // compensate for x offset
        float4([0, 1, 0, 0]),
        float4([0, 0, 1, -0.06]), // z-offset draws objects a fixed distance away from device
        float4([0, 0, 0, 1])
      ])
  
  /**
   - Returns: The position of the device, offset by deviceToDrawpointTranslation,
      given as a 4x4 matrix.
   */
  private var deviceLocationTransform : simd_float4x4? {
    if let cameraTransform = sceneView.session.currentFrame?.camera.transform {
      return cameraTransform * deviceToDrawpointTranslation
    } else {
      return nil
    }
  }
  
  /// The current position of the device, given as a 3-component vector
  private var currentPos : float3? {
    return deviceLocationTransform?.translation
  }
  
  /// Tracks the location of the most recently drawn point.
  private var previous : float3?
  
  /**
    Draws a new point in the sceneView, extending the currently drawn line
    if one exists.
   
   **Modifies**: previous, lines, sceneView
   
   **Effects**:
   - If the user is not actively drawing (touched is false), sets previous to nil
      and quits.
   - If this is the first vertex in the line being drawn (previous is nil),
      sets previous to the current position and recurses.
   - Otherwise, if the new point is far enough away from the last drawn point
      (distance > lineRadius/2), then adds a point to the model and view.  Recurses.
   
   */
  private func drawPoint() {
    DispatchQueue.global().async {
      [weak self] in
      DispatchQueue.main.async {
        guard self?.touched ?? false, let currentPos = self?.currentPos else {
          self?.previous = nil
          return
        }
        guard let previousPos = self?.previous else {
          self?.previous = currentPos
          self?.drawPoint()
          return
        }
        
        // Check that new points are far enough away to be worth drawing
        if currentPos.distance(to: previousPos) > Float(self!.lineRadius)/2 {
          self?.lines.last?.add(vertex: currentPos)
          
          let factory = Geometry.cylinderGenerator(radius: self!.lineRadius * 0.5)
          let node = factory(previousPos, currentPos)
          self?.rootNode.addChildNode(node)
          self?.previous = currentPos
        }

        // Repeat
        self?.drawPoint()
      }
    }
  }
  
  /// Tracks whether the scene is currently being cleared (in case the user presses
  /// the clear button multiple times in succession).
  private var inMiddleOfClearing : Bool = false
  
  /**
   Responds to the user's 'clear' button press.
   
   **Modifies**: inMiddleOfClearing, sceneView
   
   **Effects**: sets inMiddleOfClearing to reflect clearing state
    and clears the scene.
   
   */
  @IBAction func clearPressed() {
    // Only clear if program isn't already in the middle of clearing
    // and there are lines to be cleared
    if !inMiddleOfClearing, lines.count != 0 {
      DispatchQueue.global().async {
        [weak self] in
        self?.inMiddleOfClearing = true
        self?.clearScene()
        self?.inMiddleOfClearing = false
      }
    }
  }
  
  /// Clears the scene and model.
  public func clearScene() {
    sceneView.scene = SCNScene()
    lines = []
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Set the view's delegate
    sceneView.delegate = self
    
    // Show statistics such as fps and timing information
    sceneView.showsStatistics = true
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // Create a session configuration
    let configuration = ARWorldTrackingConfiguration()
    
    // Run the view's session
    sceneView.session.run(configuration)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    // Pause the view's session
    sceneView.session.pause()
  }
  
  // MARK: - ARSCNViewDelegate
  
  /*
   // Override to create and configure nodes for anchors added to the view's session.
   func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
   let node = SCNNode()
   
   return node
   }
   */
  
  func session(_ session: ARSession, didFailWithError error: Error) {
    // Present an error message to the user
    
  }
  
  func sessionWasInterrupted(_ session: ARSession) {
    // Inform the user that the session has been interrupted, for example, by presenting an overlay
    
  }
  
  func sessionInterruptionEnded(_ session: ARSession) {
    // Reset tracking and/or remove existing anchors if consistent tracking is required
    
  }
}
