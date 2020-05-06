//
//  SwiftRTree.swift
//  
//
//  Created by Robert Geifman on 05/05/2020.
//

import Foundation
import QuartzCore
import RTreeIndexImpl

public protocol _Identifiable {
    /// A type representing the stable identity of the entity associated with `self`.
    associatedtype ID : Hashable
    /// The stable identity of the entity associated with `self`.
    var id: ID { get }
}

extension _Identifiable where Self: AnyObject {
    /// The stable identity of the entity associated with `self`.
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

// MARK: - RTreeElement
public protocol RTreeElement: _Identifiable {
	var rect: CGRect { get }
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
extension RTreeRect {
	var rect: CGRect {
		let origin = CGPoint(x: CGFloat(boundary.0), y: CGFloat(boundary.1))
		let size = CGSize(width: CGFloat(boundary.2) - origin.x, height: CGFloat(boundary.3) - origin.y)
		return CGRect(origin: origin, size: size)
	}
	
	init(_ rect: CGRect) {
		self.init(boundary: (RectReal(rect.minX), RectReal(rect.minY), RectReal(rect.maxX), RectReal(rect.maxY)))
	}
}

// MARK: - RTree
final public class RTree<Element> where Element: _Identifiable {
	var root: UnsafeMutablePointer<RTreeNode>?
	var elements = [Element.ID: Element]()
	deinit {
		RTreeRecursivelyFreeNode(root)
	}
	public init() {
		root = RTreeNewIndex()
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
	
	func contains(_ element: Element) -> Bool {
		nil != elements[element.id]
	}
	func insert(_ element: Element, rect: CGRect) {
		elements[element.id] = element

		var id = element.id
		var rect = RTreeRect(rect)

		withUnsafeMutablePointer(to: &rect) { ptrRect in
			withUnsafeMutableBytes(of: &id) { ptrID in
				withUnsafeMutablePointer(to: &root) { ptrRoot in
					_ = RTreeInsertRect(ptrRect, ptrID.baseAddress, ptrRoot, 0)
				}
			}
		}
	}
	func removeAll() {
		elements.removeAll()
		RTreeRecursivelyFreeNode(root)
		root = RTreeNewIndex()
	}
	func remove(in rect: CGRect, options: RTreeSearchOptions = .default) -> [Element] {
		var foundElements = [(Element.ID, RTreeRect)]()
		search(RTreeRect(rect), options: options) {
			guard let ptrID = $0, let rect = $1?.pointee else { return 0 }
			let id = ptrID.assumingMemoryBound(to: Element.ID.self).pointee
			foundElements.append((id, rect))
			return 1
		}

		var deletedElements = [Element]()
		withUnsafeMutablePointer(to: &root) { ptrRoot in
			for element in foundElements {
				var (id, rect) = element
				guard let deletedElement = elements[id],
					let index = elements.index(forKey: id) else {
					fatalError("this should not have happened!")
				}

				let deleted = withUnsafeMutablePointer(to: &rect) { ptrRect in
					withUnsafeMutablePointer(to: &id) { ptrID in
						0 != RTreeDeleteRect(ptrRect, ptrID, ptrRoot)
					}
				}
				
				guard deleted else { fatalError("error removing element with id: \(id)") }

				deletedElements.append(deletedElement)
				elements.remove(at: index)
			}
		}
		return deletedElements
	}
	func search(_ rect: CGRect, options: RTreeSearchOptions = .default, body: (Element.ID, CGRect) -> Bool) {
		withoutActuallyEscaping(body) { escapingBody in
			search(RTreeRect(rect), options: options) {
				guard let rect = $1?.pointee, let ptrID = $0 else { return 0 }
				let id = ptrID.assumingMemoryBound(to: Element.ID.self).pointee
				return escapingBody(id, rect.rect) ? 1 : 0
			}
		}
	}
	func hitTest(_ point: CGPoint, size: CGSize = CGSize(width: 4, height: 4), body: (Element.ID, CGRect) -> Bool) {
		let rect = CGRect(origin: point, size: size).offsetBy(dx: -size.width / 2, dy: -size.height / 2)
		search(rect, body: body)
	}

	subscript(id: Element.ID) -> Element? {
		elements[id]
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
