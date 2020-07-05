//
//  RTreeSwift.swift
//  
//
//  Created by Robert Geifman on 05/05/2020.
//

import Foundation
import QuartzCore
import RTreeIndexImpl

// MARK: - RTreeOptions
public enum RTreeSearchOptions {
	case intersecting, contained, containing

	public static let `default` = Self.intersecting

	var function: (UnsafeMutablePointer<RTreeNode>?, UnsafeMutablePointer<RTreeRect>?, UnsafeMutableRawPointer?, RTreeSearchHitCallback?) -> Int32 {
		switch self {
		case .intersecting: return RTreeSearch
		case .contained: return RTreeSearchContained
		case .containing: return RTreeSearchContaining
		}
	}
}

// MARK: - RTreeRect
public extension RTreeRect {
	var rect: CGRect {
		let origin = CGPoint(x: CGFloat(boundary.0), y: CGFloat(boundary.1))
		let size = CGSize(width: CGFloat(boundary.2) - origin.x, height: CGFloat(boundary.3) - origin.y)
		return CGRect(origin: origin, size: size)
	}
	
	init(_ point: CGPoint) {
		self.init(boundary: (RectReal(point.x), RectReal(point.y), RectReal(point.x), RectReal(point.y)))
	}
	init(_ rect: CGRect) {
		self.init(boundary: (RectReal(rect.minX), RectReal(rect.minY), RectReal(rect.maxX), RectReal(rect.maxY)))
	}
}

// MARK: - RTreeNode
public extension RTreeNode {
	enum Kind {
		case leaf(Int), node(Int)
	}
	var kind: Kind {
		level > 0 ? .node(Int(count)) : .leaf(Int(count))
	}
	var bounds: CGRect {
		var root = self
		return withUnsafeBytes(of: &root.branch) { rawPtr in
			let branch = rawPtr.baseAddress!.assumingMemoryBound(to: RTreeBranch.self)
			let count = Int(level > 0 ? NODECARD : LEAFCARD)
			return (0 ..< count).reduce(CGRect.zero) {
				$0.union(branch[$1].rect.rect)
			}
		}
	}
}

// MARK: - RTree
final public class RTree<Element> where Element: Hashable {
	var root: UnsafeMutablePointer<RTreeNode>?
	var elements = Set<Element>()
	deinit {
		RTreeRecursivelyFreeNode(root)
	}
	public init() {
		root = RTreeNewIndex()
	}
}

extension RTree: Sequence {
	public func makeIterator() -> AnyIterator<Element> {
		AnyIterator(elements.makeIterator())
	}
}

public extension RTree {
	var bounds: CGRect {
		guard let root = root else { fatalError() }
		var node = root.pointee
		assert(node.level >= 0)

		return withUnsafeBytes(of: &node.branch) { rawPtr in
			let branch = rawPtr.baseAddress!.assumingMemoryBound(to: RTreeBranch.self)
			let count = Int(node.level > 0 ? NODECARD : LEAFCARD)
			return (0 ..< count).reduce(CGRect.zero) {
				$0.union(branch[$1].rect.rect)
			}
		}
	}
	
	func insert(_ element: Element, at point: CGPoint) {
		elements.insert(element)

		var element = element
		var rect = RTreeRect(point)

		withUnsafeMutablePointer(to: &rect) { ptrRect in
			withUnsafeMutableBytes(of: &element) { ptrElement in
				withUnsafeMutablePointer(to: &root) { ptrRoot in
					_ = RTreeInsertRect(ptrRect, ptrElement.baseAddress, ptrRoot, 0)
				}
			}
		}
	}
	func insert(_ element: Element, in rect: CGRect) {
		elements.insert(element)

		var element = element
		var rect = RTreeRect(rect)

		withUnsafeMutablePointer(to: &rect) { ptrRect in
			withUnsafeMutableBytes(of: &element) { ptrElement in
				withUnsafeMutablePointer(to: &root) { ptrRoot in
					_ = RTreeInsertRect(ptrRect, ptrElement.baseAddress, ptrRoot, 0)
				}
			}
		}
	}

	func remove(in rect: CGRect, options: RTreeSearchOptions = .default) -> [Element] {
		var foundElements = [(Element, RTreeRect)]()
		search(RTreeRect(rect), options: options) {
			guard let ptrElement = $0, let rect = $1?.pointee else { return 0 }
			let element = ptrElement.assumingMemoryBound(to: Element.self).pointee
			foundElements.append((element, rect))
			return 1
		}

		var deletedElements = [Element]()
		withUnsafeMutablePointer(to: &root) { ptrRoot in
			for foundElement in foundElements {
				var (element, rect) = foundElement

				guard elements.contains(element) else {
					fatalError("this should not have happened!")
				}

				let deleted = withUnsafeMutablePointer(to: &rect) { ptrRect in
					withUnsafeMutablePointer(to: &element) { ptrElement in
						0 != RTreeDeleteRect(ptrRect, ptrElement, ptrRoot)
					}
				}
				
				guard deleted else { fatalError("error removing element with id: \(element)") }

				deletedElements.append(element)
				elements.remove(element)
			}
		}
		return deletedElements
	}
	func removeAll() {
		elements.removeAll()
		RTreeRecursivelyFreeNode(root)
		root = RTreeNewIndex()
	}

	func contains(_ element: Element) -> Bool {
		elements.contains(element)
	}

	func search(_ rect: CGRect, options: RTreeSearchOptions = .default, body: (Element, CGRect) -> Bool) {
		withoutActuallyEscaping(body) { escapingBody in
			search(RTreeRect(rect), options: options) {
				guard let rect = $1?.pointee, let ptrElement = $0 else { return 0 }
				let id = ptrElement.assumingMemoryBound(to: Element.self).pointee
				return escapingBody(id, rect.rect) ? 1 : 0
			}
		}
	}
	func search(_ point: CGPoint, size: CGSize = CGSize(width: 4, height: 4), body: (Element, CGRect) -> Bool) {
		let rect = CGRect(origin: point, size: size).offsetBy(dx: -size.width / 2, dy: -size.height / 2)
		search(rect, body: body)
	}

	func element(at point: CGPoint, size: CGSize = CGSize(width: 4, height: 4)) -> Element? {
		var result: Element?
		search(point, size: size) { element, _ in
			result = element
			return false
		}
		return result
	}
}

// MARK: - Search
fileprivate struct Function {
	var body: (UnsafeMutableRawPointer?, UnsafeMutablePointer<RTreeRect>?) -> Int32
}

fileprivate func searchCallback(_ ptrID: UnsafeMutableRawPointer?, _ ptrRect: UnsafeMutablePointer<RTreeRect>?, userInfo: UnsafeMutableRawPointer?) -> Int32 {
	guard let function = userInfo?.assumingMemoryBound(to: Function.self).pointee else { return 0 }
	return function.body(ptrID, ptrRect)
}

fileprivate extension RTree {
	func search(_ rect: RTreeRect, options: RTreeSearchOptions = .default, body: @escaping (UnsafeMutableRawPointer?, UnsafeMutablePointer<RTreeRect>?) -> Int32) {
		var rect = rect
		var function = Function(body: body)
		_ = withUnsafeMutablePointer(to: &rect) { ptrRect in
			withUnsafeMutablePointer(to: &function) { ptrFunction in
				options.function(root, ptrRect, ptrFunction, searchCallback)
			}
		}
	}
}
