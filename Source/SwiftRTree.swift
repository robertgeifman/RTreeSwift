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

public protocol RTreeElement: _Identifiable {
	var rect: CGRect { get }
}

public enum RTreeOptions {
	case `default`, `in`, enclosing
	static let intersecting = Self.default
	static let enclosedBy = Self.in
}

final public class RTree<Element> where Element: _Identifiable {
	deinit {
	}
	public init() {
		RTreeNewIndex()
	}
}

public extension RTree {
	var bounds: CGRect {
		.zero
	}
	func contains(_ element: Element) -> Bool {
		false
	}
	
	func insert(_ element: Element, rect: CGRect) {
	}
	
	func remove(in rect: CGRect, options: RTreeOptions = .default) -> [Element] {
		[]
	}

	func removeAll() {
	}

	func hitTest(_ point: CGPoint, body: (Element, CGRect) -> Bool) {
	}

	func hitTest(_ rect: CGRect, RTreeOptions: RTreeOptions = .default, body: (Element, CGRect) -> Bool) {
	}
}
