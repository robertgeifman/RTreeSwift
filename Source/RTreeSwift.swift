//
//  RTreeSwift.swift
//  
//
//  Created by Robert Geifman on 05/05/2020.
//

import Foundation
import QuartzCore
import RTreeIndexImpl

// MARK: - RTree
typealias Node = UnsafeMutablePointer<RTreeNode>
final public class RTree<Element> where Element: Hashable {
	var ptrRootNode: Node?
	var elements = Set<Element>()
	deinit {
		RTreeRecursivelyFreeNode(ptrRootNode)
	}
	public init() {
		ptrRootNode = RTreeNewIndex()
	}
}

public extension RTree {
	struct ElementsIntersectingRect<Element> {
		let ptrRootNode: Node
		let rect: CGRect
	}

	var bounds: CGRect {
		guard let root = ptrRootNode else { fatalError() }
		var node = root.pointee
		assert(node.level >= 0)

		return withUnsafeBytes(of: &node.branch) { rawPtr in
			let branch = rawPtr.baseAddress!.assumingMemoryBound(to: RTreeBranch.self)
			let count = Int(node.level > 0 ? NODECARD : LEAFCARD)
			return (0 ..< count).reduce(CGRect.zero) {
				$0.union(branch[$1].rect.bounds)
			}
		}
	}
	
	func insert(_ element: Element, at point: CGPoint) {
		elements.insert(element)

		var element = element
		var rect = RTreeRect(point)

		withUnsafeMutablePointer(to: &rect) { ptrRect in
			withUnsafeMutableBytes(of: &element) { ptrElement in
				withUnsafeMutablePointer(to: &ptrRootNode) { ptrRoot in
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
				withUnsafeMutablePointer(to: &ptrRootNode) { ptrRoot in
					_ = RTreeInsertRect(ptrRect, ptrElement.baseAddress, ptrRoot, 0)
				}
			}
		}
	}

	func remove(in rect: CGRect, options: RTreeSearchOptions = .default) -> [Element] {
		var foundElements = [(Element, RTreeRect)]()
		search(RTreeRect(rect), searchMethod: options) {
			guard let ptrElement = $0, let rect = $1?.pointee else { return 0 }
			let element = ptrElement.assumingMemoryBound(to: Element.self).pointee
			foundElements.append((element, rect))
			return 1
		}

		var deletedElements = [Element]()
		withUnsafeMutablePointer(to: &ptrRootNode) { ptrRoot in
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
		RTreeRecursivelyFreeNode(ptrRootNode)
		ptrRootNode = RTreeNewIndex()
	}

	func contains(_ element: Element) -> Bool {
		elements.contains(element)
	}

	func search(_ rect: CGRect, options: RTreeSearchOptions = .default, body: (Element, CGRect) -> Bool) {
		withoutActuallyEscaping(body) { escapingBody in
			search(RTreeRect(rect), searchMethod: options) {
				guard let rect = $1?.pointee, let ptrElement = $0 else { return 0 }
				let id = ptrElement.assumingMemoryBound(to: Element.self).pointee
				return escapingBody(id, rect.bounds) ? 1 : 0
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

	subscript(rect: CGRect) -> ElementsIntersectingRect<Element> { .init(ptrRootNode: ptrRootNode!, rect: rect) }
}

extension RTree: Sequence {
	public func makeIterator() -> AnyIterator<Element> {
		AnyIterator(elements.makeIterator())
	}
}

// MARK: - ElementsIntersectingRect
extension RTree.ElementsIntersectingRect: Sequence {
	public struct Iterator {
		let rect: CGRect
		var ptrNode: Node
		var index: Int
		var stack = [(ptrNode: Node, index: Int)]()
		init(root ptrRootNode: Node, rect: CGRect) {
			self.rect = rect
			self.ptrNode = ptrRootNode
			self.index = 0
		}
	}

	public func makeIterator() -> Iterator { .init(root: ptrRootNode, rect: rect) }
}

extension RTree.ElementsIntersectingRect.Iterator: IteratorProtocol {
	mutating public func next() -> Element? {
		repeat {
			guard index < ptrNode.pointee.count else {
				guard let last = stack.last else { return nil }
				_ = stack.dropLast()
				self.ptrNode = last.ptrNode
				self.index = last.index
				continue
			}

			let node = ptrNode.pointee
			let branch = node[index]
			
			let bounds = branch.rect.bounds
			index += 1
			if rect.intersects(bounds), var child = branch.child {
				if node.isLeaf {
					return withUnsafeBytes(of: &child) { rawPtr in
						rawPtr.baseAddress!.assumingMemoryBound(to: Element.self)[0]
					}
				} else {
					stack.append((ptrNode: self.ptrNode, index: index))
					self.ptrNode = child
					self.index = 0
				}
			}
		} while true
	}
}

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
	var bounds: CGRect {
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
	var isLeaf: Bool { level == 0 }
	var bounds: CGRect {
		var root = self
		return withUnsafeBytes(of: &root.branch) { rawPtr in
			let branch = rawPtr.baseAddress!.assumingMemoryBound(to: RTreeBranch.self)
			let count = Int(level > 0 ? NODECARD : LEAFCARD)
			return (0 ..< count).reduce(CGRect.zero) {
				$0.union(branch[$1].rect.bounds)
			}
		}
	}
	subscript(index: Int) -> RTreeBranch {
		var branchTuple = branch
		return withUnsafeBytes(of: &branchTuple) { rawPtr in
			rawPtr.baseAddress!.assumingMemoryBound(to: RTreeBranch.self)[index]
		}
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
	func search(_ rect: RTreeRect, searchMethod: RTreeSearchOptions = .default, body: @escaping (UnsafeMutableRawPointer?, UnsafeMutablePointer<RTreeRect>?) -> Int32) {
		var rect = rect
		var function = Function(body: body)
		_ = withUnsafeMutablePointer(to: &rect) { ptrRect in
			withUnsafeMutablePointer(to: &function) { ptrFunction in
				searchMethod.function(ptrRootNode, ptrRect, ptrFunction, searchCallback)
			}
		}
	}
}
