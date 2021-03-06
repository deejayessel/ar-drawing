//
//  CanvasTests.swift
//  CanvasTests
//
//  Created by 21djl5 on 11/22/18.
//  Copyright © 2018 davidjlee. All rights reserved.
//

import XCTest
import SceneKit
@testable import Canvas

extension Point {
  public init(_ x : Int, _ y : Int, _ z : Int) {
    self.init(Double(x), Double(y), Double(z))
  }
}

class CanvasTests: XCTestCase {
  
  private func makeCurves(_ numcurves: Int, _ numpoints: Int) -> [[Point]] {
    var curves : [[Point]] = []
    for _ in 1...numcurves {
      let curve = Array(1...numpoints).map { Point($0, $0, $0) }
      curves.append(curve)
    }
    return curves
  }
  
  func testInit() {
    let c1 = Canvas()
    let c2 = Canvas()
    XCTAssertEqual(c1.getCurves(), c2.getCurves())
  }
  
  func testAddCurve() {
    let curves = makeCurves(5, 5)
    let c1 = Canvas(curves: curves)
    let c2 = Canvas()
    for curve in curves {
      c2.add(curve: curve)
    }
    XCTAssertEqual(c1.getCurves(), c2.getCurves())
  }
  
  func testAddPoint() {
    let curves = makeCurves(1, 5)
    let c1 = Canvas(curves: curves)
    let c2 = Canvas()
    for point in curves[0] {
      c2.append(point: point)
    }
    XCTAssertEqual(c1.getCurves(), c2.getCurves())
  }
  
  func testRemove() {
    let curves = makeCurves(5, 5)
    let c1 = Canvas(curves: curves)
    for _ in 1...curves.count {
      c1.remove()
    }
    let c2 = Canvas()
    XCTAssertEqual(c1.getCurves(), c2.getCurves())
  }
  
}

//      func test() -> SCNNode {
//        func getNode(position : float3, color: UIColor) -> SCNNode{
//          let geometry = SCNSphere(radius: radius)
//          let node = SCNNode(geometry: geometry)
//          node.simdPosition = position
//          node.geometry?.firstMaterial?.diffuse.contents = color
//          return node
//        }
//
//        let u_node = getNode(position: u, color: UIColor.white)
//        let w_node = getNode(position: u + 0.001 * w, color: UIColor.red)
//        let v_node = getNode(position: u + 0.002 * v-u, color: UIColor.black)
//
//        let parent = SCNNode()
//        parent.addChildNode(u_node)
//        parent.addChildNode(w_node)
//        parent.addChildNode(v_node)
//
//        return parent
//      }
