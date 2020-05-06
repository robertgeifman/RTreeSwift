//
//  SwiftRTree.swift
//  
//
//  Created by Robert Geifman on 05/05/2020.
//

import Foundation
import QuartzCore
import RTreeIndexImpl

func modified<T, R>(_ object: T, using closure: (T) -> R) -> R {
    closure(object)
}

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
public enum RTreeOptions {
	case `default`, `in`, enclosing
	static let intersecting = Self.default
	static let enclosedBy = Self.in
	var function: (UnsafeMutablePointer<RTreeNode>?, UnsafeMutablePointer<RTreeRect>?, UnsafeMutableRawPointer?, RTreeSearchHitCallback?) -> Int32 {
		switch self {
		case .default: return RTreeSearch
		case .in: return RTreeSearchContained
		case .enclosing: return RTreeSearchContaining
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

final internal class Iterator: Sequence {
	typealias Element = (UnsafeMutableRawPointer, RTreeRect)
	typealias Iterator = Array<Element>.Iterator
	typealias Index = Array<Element>.Index
	
	var startIndex: Index { elements.startIndex }
	var endIndex: Index { elements.endIndex }
	
	var elements = [Element]()

	func append(_ element: Element) {
		elements.append(element)
	}
	__consuming func makeIterator() -> Iterator {
		elements.makeIterator()
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
	

	static func handler(_ ptrID: UnsafeMutableRawPointer?, _ ptrRect: UnsafeMutablePointer<RTreeRect>?, userInfo: UnsafeMutableRawPointer?) -> Int32 {
		guard let rect = ptrRect?.pointee, let ptrID = ptrID,
			let iterator = userInfo?.assumingMemoryBound(to: Iterator.self).pointee else { return 0 }
		iterator.append((ptrID, rect))
		return 1
	}

	func remove(in rect: CGRect, options: RTreeOptions = .default) -> [Element] {
		var rect = RTreeRect(rect)
		var iterator = Iterator()
		let function = options.function

		_ = withUnsafeMutablePointer(to: &rect) { ptrRect in
			withUnsafeMutablePointer(to: &iterator) { ptrIterator in
				function(root, ptrRect, ptrIterator) {
					guard let ptrID = $0, let rect = $1?.pointee,
						let iterator = $2?.assumingMemoryBound(to: Iterator.self).pointee else { return 0 }
					iterator.append((ptrID, rect))
					return 1
				}
			}
		}
		
		var deletedElements = [Element]()
		for element in iterator {
			var (ptrID, rect) = element
			_ = withUnsafeMutablePointer(to: &rect) { ptrRect in
				withUnsafeMutablePointer(to: &root) { ptrRoot in
					let id = ptrID.assumingMemoryBound(to: Element.ID.self).pointee
					guard let deletedElement = elements[id],
						let index = elements.index(forKey: id),
						0 != RTreeDeleteRect(ptrRect, ptrID, ptrRoot) else {
						fatalError("this should not have happened!")
					}
					deletedElements.append(deletedElement)
					elements.remove(at: index)
				}
			}
			
		}
		return deletedElements
	}

	func removeAll() {
		elements.removeAll()
		RTreeRecursivelyFreeNode(root)
		root = RTreeNewIndex()
	}

	func hitTest(_ point: CGPoint, body: (Element, CGRect) -> Bool) {
	}

	func hitTest(_ rect: CGRect, RTreeOptions: RTreeOptions = .default, body: (Element, CGRect) -> Bool) {
	}
}
