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

class ViewController: UIViewController, ARSCNViewDelegate {
  
  @IBOutlet var sceneView: ARSCNView!
  
  private let lineRadius : CGFloat = 0.005
  private let lineColor : UIColor = UIColor.white
  
  /** Model */
  private let canvas = Canvas()
  
  private var touched : Bool = false
  
  @IBAction func pressed(_ sender: UILongPressGestureRecognizer) {
    switch sender.state {
    case .began:
      touched = true
      fallthrough
    case .changed:
      drawPoint()
    case .ended:
      touched = false
    default:
      break
    }
  }
  
  private let translation : matrix_float4x4 =
    matrix_float4x4(rows:
      [
        float4([1, 0, 0, 0.0025]),
        float4([0, 1, 0, 0]),
        float4([0, 0, 1, -0.1]),
        float4([0, 0, 0, 1])
      ])
  
  private func cameraTransform() -> simd_float4x4? {
    if let cameraTransform = sceneView.session.currentFrame?.camera.transform {
      return cameraTransform * translation
    } else {
      return nil
    }
  }
  
  private func position(of matrix: simd_float4x4) -> SCNVector3 {
    return SCNVector3(matrix.columns.3.x,
                      matrix.columns.3.y,
                      matrix.columns.3.z)
  }

  private var lastPoint : SCNVector3?
  
  private func drawPoint() {
    DispatchQueue.global().async {
      [weak self] in
      DispatchQueue.main.async {
        if let this = self, this.touched, let cameraTransform = this.cameraTransform()
        {
          let currentPos = cameraTransform.position()
          if let previousPos = this.lastPoint {
            // Make cylinder
            let length : CGFloat = CGFloat(previousPos.distance(to: currentPos))
            let cylinderGeometry = SCNCylinder(radius: this.lineRadius,
                                               height: length)
            cylinderGeometry.radialSegmentCount = 5
            let cylinderNode = SCNNode(geometry: cylinderGeometry)
            cylinderNode.simdTransform = cameraTransform
            cylinderNode.orientation = cylinderNode.orientation.rotated(x: 0, y: Float.pi/2, z: 0)
            
            // Add to scene
            this.sceneView.scene.rootNode.addChildNode(cylinderNode)
          }
          this.lastPoint = currentPos
          this.drawPoint()
        } else {
          self?.lastPoint = nil
        }
        
        //          let pointGeometry = SCNSphere(radius: this.lineRadius)
        //          let pointNode = SCNNode(geometry: pointGeometry)
        //          pointGeometry.firstMaterial?.diffuse.contents = this.lineColor
        
        // Translate point to position in front of camera
        // pointNode.simdTransform = cameraTransform
        // this.sceneView.scene.rootNode.addChildNode(pointNode)
      }
    }
  }
  
  @IBAction func clear(_ sender: UIButton) {
    NSLog("Trash pressed")
    clear()
  }
  
  private func clear() {
    sceneView.scene.rootNode.enumerateChildNodes {
      (node, _) in node.removeFromParentNode()
    }
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

extension simd_float4x4 {
  func position() -> SCNVector3 {
    return SCNVector3(columns.3.x, columns.3.y, columns.3.z)
  }
}

extension SCNVector3 {
  func distance(to dst : SCNVector3) -> Float {
    return sqrt(pow(self.x - dst.x, 2) +
      pow(self.y - dst.y, 2) +
      pow(self.z - dst.z, 2))
  }
  
  func rotated(x : Float, y : Float, z : Float) -> SCNVector3 {
    let matrices : [simd_float3x3] =
      [
        simd_float3x3(rows:
          [
            float3([1, 0 , 0]),
            float3([0, cos(x), -sin(x)]),
            float3([0, sin(x), cos(x)])
          ]),
        simd_float3x3(rows:
          [
            float3([cos(y), 0, sin(y)]),
            float3([0, 1, 0]),
            float3([-sin(y), 0, cos(y)])
          ]),
        simd_float3x3(rows:
          [
            float3([cos(z), -sin(z), 0]),
            float3([sin(z), cos(z), 0]),
            float3([0, 0, 1])
          ]
        )
    ]
    var result : float3 = float3(self)
    for m in matrices {
      result = m * result
    }
    return SCNVector3(result)
  }
}

extension SCNVector4 {
  func rotated(x : Float, y : Float, z : Float) -> SCNVector4 {
    let vector = SCNVector3(self.x, self.y, self.z)
    let rotated = vector.rotated(x: x, y: y, z: z)
    return SCNVector4(rotated.x, rotated.y, rotated.z, self.w)
  }
}
