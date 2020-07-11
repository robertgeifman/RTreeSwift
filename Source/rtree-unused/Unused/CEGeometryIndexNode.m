// CEGeometryIndexNode.m: implementation of the CEGeometryIndexNode and CEGeometryIndexGroupNode classes

#import "CEGeometryIndexNode.h"
#import "CEGeometryIndex.h"
#import "CEUtilities.h"
#import "CEObjCRuntime.h"
#import "NSArray-CEExtensions.h"

////////////////////////////////////////////////////////////
static BOOL _objectEnclosingRect(NSRect rect1, NSRect rect2)
{
	return NSContainsRect(rect1, rect2);
}

static BOOL _objectInRect(NSRect rect1, NSRect rect2)
{
	return NSContainsRect(rect2, rect1);
}

static BOOL _objectIntersectingRect(NSRect rect1, NSRect rect2)
{
	return NSIntersectsRect(rect2, rect1);
}

////////////////////////////////////////////////////////////
// CEGeometryIndexNode
@implementation CEGeometryIndexNode
- (id)valueForUndefinedKey:(NSString *)key;
{
	if([key isEqualToString:[_index observedKey]])
		return [NSValue valueWithRect:_nodeBounds];
	return [super valueForUndefinedKey:key];
}

- (NSRect)nodeBounds;
{
	return _nodeBounds;
}

- (void)updateNodeBounds;
{
	_nodeBounds = NSZeroRect;
	NSString *key = [_index observedKey];
	NSEnumerator *enumerator = [_objects objectEnumerator];
	id object;
	while(object = [enumerator nextObject])
		_nodeBounds = NSUnionRect(_nodeBounds, [[object valueForKey:key] rectValue]);
}

- (NSRect)recursivelyUpdateNodeBounds;
{
	[self updateNodeBounds];
	return _nodeBounds;
}

////////////////////////////////////////////////////////////
- (NSSet *)_objects;
{
	return _objects;
}

- (void)addObjectsObject:(id)object;
{
	[_objects addObject:object];
	[self updateNodeBounds];
}

- (void)removeObjectsObject:(id)object;
{
	[_objects removeObject:object];
	[self updateNodeBounds];
}

- (void)addObjects:(NSSet *)otherSet;
{
	[_objects unionSet:otherSet];
	[self updateNodeBounds];
}

- (void)removeObjects:(NSSet *)otherSet;
{
	[_objects minusSet:otherSet];
	[self updateNodeBounds];
}

- (void)intersectObjects:(NSSet *)otherSet;
{
	[_objects intersectSet:otherSet];
	[self updateNodeBounds];
}

- (void)setObjects:(NSSet *)otherSet;
{
	[_objects setSet:otherSet];
	[self updateNodeBounds];
}

////////////////////////////////////////////////////////////
- (void)searchUsingFunction:(_searchFunction)function rect:(NSRect)rect 
	result:(NSMutableSet *)result;
{
	NSString *key = [_index observedKey];
	NSEnumerator *enumerator = [_objects objectEnumerator];
	id object;
	while(object = [enumerator nextObject])
	{
		if(function([[object valueForKey:key] rectValue], rect))
			[result addObject:object];
	}
}

- (CEGeometryIndexNode *)chooseSubNode:(NSRect)rect;
{
	return NSContainsRect(_nodeBounds, rect) ? self: NULL;
}

- (int)height;
{
	return 1;
}

////////////////////////////////////////////////////////////
- (NSSet *)hitTest:(NSPoint)point slop:(float)slop;
{
	NSMutableSet *result = [NSMutableSet set];
	[self searchUsingFunction:_objectIntersectingRect 
		rect:NSMakeRect(point.x, point.y, slop, slop) result:result];
	return result;
}

- (NSSet *)objectsInRect:(NSRect)rect;
{
	NSMutableSet *result = [NSMutableSet set];
	[self searchUsingFunction:_objectInRect rect:rect result:result];
	return result;
}

- (NSSet *)objectsIntersectingRect:(NSRect)rect;
{
	NSMutableSet *result = [NSMutableSet set];
	[self searchUsingFunction:_objectIntersectingRect rect:rect result:result];
	return result;
}

- (NSSet *)objectsEnclosingRect:(NSRect)rect;
{
	NSMutableSet *result = [NSMutableSet set];
	[self searchUsingFunction:_objectEnclosingRect rect:rect result:result];
	return result;
}

////////////////////////////////////////////////////////////
- (void)dealloc;
{
	[_objects release];
	[super dealloc];
}

- (id)initWithObjects:(NSSet *)objects inIndex:(CEGeometryIndex *)index;
{
	if(![super init])
		return NULL;
	_objects = [objects mutableCopy];
	_index = index;
	[self updateNodeBounds];
	return self;
}	

+ (CEGeometryIndexNode *)nodeWithObjects:(NSSet *)objects inIndex:(CEGeometryIndex *)index;
{	
	return [[(CEGeometryIndexNode *)[[self class] alloc] initWithObjects:objects inIndex:index] autorelease];
}
@end

////////////////////////////////////////////////////////////
// CEGeometryIndexGroupNode
@implementation CEGeometryIndexGroupNode
- (int)height;
{
	return 1 + [[_objects valueForKeyPath:@"@max.height"] intValue];
}

- (void)searchUsingFunction:(_searchFunction)function rect:(NSRect)rect 
	result:(NSMutableSet *)result;
{
	NSEnumerator *enumerator = [_objects objectEnumerator];
	CEGeometryIndexNode *node;
	while(node = [enumerator nextObject])
	{
		if(NSIntersectsRect([node nodeBounds], rect))
			[node searchUsingFunction:_objectIntersectingRect rect:rect result:result];
	}
}

- (CEGeometryIndexNode *)chooseSubNode:(NSRect)rect;
{
	NSEnumerator *enumerator = [_objects objectEnumerator];
	CEGeometryIndexNode *node;
	while(node = [enumerator nextObject])
	{
		if(!NSIntersectsRect([node nodeBounds], rect))
			continue;
		if([node isKindOfClass:[CEGeometryIndexNode class]])
			return self;
		return [node chooseSubNode:rect];
	}
	return NULL;
}
@end
