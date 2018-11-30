//
//  Canvas.sw.swift
//  Canvas
//
//  Created by 21djl5 on 11/22/18.
//  Copyright © 2018 davidjlee. All rights reserved.
//

import Foundation
import SceneKit
import CoreGraphics

public class Polyline : CustomDebugStringConvertible {
  
  public private(set) var vertices : [float3]
  
  public var debugDescription: String {
    return String(reflecting: vertices)
  }
  
  public init(vertices : [float3]) {
    self.vertices = vertices
    NSLog("Created new PolyLine")
  }
  
  public convenience init() {
    self.init(vertices: [])
  }
  
  public convenience init(generator : (Float) -> float3, values : [Float]) {
    self.init(vertices: values.map(generator))
  }
  
  public func add(vertex : float3) {
    vertices.append(vertex)
    NSLog("Added new vertex: \(vertex)")
  }
  
  public func removeLast() {
    vertices.removeLast()
  }
  
  public func lastSegment() -> (float3, float3)? {
    if vertices.count >= 2 {
      return (vertices[vertices.count - 2], vertices[vertices.count - 1])
    } else {
      return nil
    }
  }
  
  public func segments() -> Zip2Sequence<ArraySlice<float3>, ArraySlice<float3>> {
    return zip(vertices[...], vertices[1...])
  }
  
}

public class Geometry {
  
  private static func rotation(_ u : float3, _ v : float3) -> (axis : float3, angle : Float) {
    // Vector from u to v
    let n = v - u
    let (x,y,z) = (n.x, n.y, n.z)
    
    // Rotating cylinder
    let d = sqrt(pow(x, 2) + pow(z, 2))
    let phi = atan(d/y)
    let w = float3(-z/d, 0, x/d)
    
    return (w, phi)
  }
  
  private static func pointNode(at center: float3, radius : CGFloat, color : UIColor) -> SCNNode {
    let sphere = SCNSphere(radius: radius)
    sphere.firstMaterial?.diffuse.contents = color
    let node = SCNNode(geometry: sphere)
    node.simdPosition = center
    return node
  }
  
  public static func tubeLineGenerator(radius: CGFloat, segmentCount : Int) -> ([float3]) -> SCNNode {

    let range = 0..<segmentCount
    let circleVertices : [float3] = range.map {
      let theta  = Float($0)/Float(segmentCount) * 2 * Float.pi
      return float3(x: cos(theta), y: 0, z: sin(theta)) * Float(radius)
    }

    // Rotate circleVertices to be perpendicular to vector from u to v
    func rotatedVertices(_ u : float3, _ v : float3) -> [float3] {
      let (w,phi) = rotation(u, v)
      let rotationTransform = simd_float4x4(simd_quatf(angle: phi, axis: w))
      return circleVertices.map {
        let rotated = float4($0, 1) * rotationTransform
        return float3(rotated)
      }
    }
    
    return {
      (vertices : [float3]) in

      guard vertices.count >= 2 else {
        return SCNNode()
      }
      
      // The parent node of all nodes generated in the loop; to be returned
      let parent = SCNNode()

      // Construct a set of tubes (uncapped cylinders) and add caps at end
      //var firstCircle : [float3] = rotatedVertices(vertices[0], vertices[1])
      for i in 1..<vertices.count-1 {
        let u = vertices[i-1]
        let v = vertices[i]
        let w = vertices[i+1]

        let firstCircle : [float3] = rotatedVertices(u, v)
        let secondCircle : [float3] = rotatedVertices(v, w).map {
          $0 + (v - u)
        }
        
        // Interleave circle vertices to get cylinder vertices
        let interleaved : [float3] = zip(firstCircle + Array(firstCircle[0...1]),
                                         secondCircle + Array(secondCircle[0...1])).flatMap { [$0,$1] }
        
        // Construct a cylinder
        let source = SCNGeometrySource(vertices: interleaved.map { SCNVector3($0) })
        let indices = (0...interleaved.count-3).map { UInt8($0) }
        let element = SCNGeometryElement(indices: indices,
                                         primitiveType: .triangleStrip)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        //geometry.firstMaterial?.isDoubleSided = true

        // FOR TESTING: set line color red
        geometry.firstMaterial?.diffuse.contents = UIColor.red
        
        // Add to SCNNode
        let node = SCNNode(geometry: geometry)
        node.simdPosition = u
        parent.addChildNode(node)
      }
      return parent
    }
  }
  
  public static func cylinderGenerator(radius: CGFloat) -> (float3, float3) -> SCNNode {
    return { (u : float3, v : float3) -> SCNNode in
      let cylinder = SCNCylinder(radius: radius, height: CGFloat(u.distance(to: v)))
      cylinder.heightSegmentCount = 1

      // Get rotation axis and angle for the vector from u to v
      let (w, phi) = self.rotation(u, v)
      let theta = Float.pi - phi
    
      // Rotate cylinder by phi about w
      let node = SCNNode(geometry: cylinder)
      node.simdPosition = u.midpoint(with: v) //Translate node to position of src node
      node.simdLocalRotate(by: simd_quatf(angle: theta, axis: w))

      return node
    }
  }
  
  // Rotate face to be perpendicular to vector v
  private static func rotatedFace(face : [float3], _ v : float3) -> [float3] {
    let (w,phi) = rotation(float3(), v)
    let rotationTransform = simd_float4x4(simd_quatf(angle: phi, axis: w))
    return face.map {
      let rotated = float4($0, 1) * rotationTransform
      return float3(rotated)
    }
  }
  
  public static func rectangleBrushGenerator(width: CGFloat,
                                             height: CGFloat,
                                             color: UIColor) -> (float3, float3) -> SCNNode {
    let w = Float(width), h = Float(height)
    let wideBrush : [float3] = [
      float3(-w, 0, -h),
      float3(w, 0, -h),
      float3(-w, 0, h),
      float3(w, 0, h)
    ]
    return faceTubeGenerator(face: wideBrush, color: color)
  }
  
  /**
   - Parameter face: the x-z plane version of the face to be used in each prism
   */
  private static func faceTubeGenerator(face : [float3], color : UIColor) -> (float3, float3) -> SCNNode {
    return {
      (u: float3, v: float3) -> SCNNode in
      
      /** TODO: Use SCNShape */
      //let geometry = SCNShape

      let firstFace : [float3] = rotatedFace(face: face, v - u)
      let secondFace : [float3] = rotatedFace(face: face, v - u).map { $0 + (v - u) }
      
      // Interleave circle vertices to get cylinder vertices
      let interleaved : [float3] = zip(firstFace + Array(firstFace[0...1]),
                                       secondFace + Array(secondFace[0...1])).flatMap { [$0,$1] }
      
      // Construct a cylinder
      let source = SCNGeometrySource(vertices: interleaved.map { SCNVector3($0) })
      let indices = (0...interleaved.count-3).map { UInt8($0) }
      let element = SCNGeometryElement(indices: indices,
                                       primitiveType: .triangleStrip)
      let geometry = SCNGeometry(sources: [source], elements: [element])
      geometry.firstMaterial?.diffuse.contents = color
      
      // Add to SCNNode
      let node = SCNNode(geometry: geometry)
      node.simdPosition = u
      return node
    }
  }
  
}

public class Spline {
  // Using cubic Bezier curves
  
  /*
   P(t) = (1-t)³ P1
   + 3t(1-t)² P2
   + 3t²(1-t) P3
   + t³ P4
   */
  
  private let generator : (Float) -> float3
  public let minIndex : Float = 0
  public let maxIndex : Float
  
  private static let bernstein = simd_float4x4(rows:
    [
      float4(1, -3, 3, -1),
      float4(0,3,-6,3),
      float4(0, 0, 3, -3),
      float4(0, 0, 0, 1)
    ])
  
  public init(vertices: [float3]) {
    maxIndex = Float(vertices.count-1)
    
    func basis(t : Float) -> float4 {
      return float4(1, t, powf(t, 2), powf(t, 3))
    }

    generator = { (t : Float) -> float3 in
      // Can't use instance variables here bc in init
      assert(0 <= t && t <= Float(vertices.count - 1))
      
      // Int : (Float) -> float3
      var subgenerators : [(Float) -> float3] = []
      for i in stride(from: 0, to: vertices.count, by: 4) {
        let geometryMatrix = simd_float4x3(vertices[i],
                                           vertices[i+1],
                                           vertices[i+2],
                                           vertices[i+3])
        subgenerators.append {
          return geometryMatrix * Spline.bernstein * basis(t: $0)
        }
      }
      
      // Deal with remaining; between 0 and 3 leftover points
      if t > Float(vertices.count - (vertices.count % 4)) {
        return vertices[Int(t)]
      }
      
      // Package t and feed into corresponding subgenerator
      // Parametrization: t = 0 at first node, t = n-1 at node n
      return subgenerators[Int(t/4)](t.remainder(dividingBy: 1))
    }
  }
  
  public func eval(at t: Float) -> float3 {
    return generator(t)
  }

}


