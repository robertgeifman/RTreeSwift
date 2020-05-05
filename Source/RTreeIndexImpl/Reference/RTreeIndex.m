// RTreeIndex.m : implementation of the RTreeIndex class
#import "RTreeIndex.h"
#import "RTreeIndexImpl.h"
#import "RTreeCard.h"

////////////////////////////////////////////////////////////
static inline void RTreeRectFromNSRect(NSRect rect, RTreeRect *r)
{
	r->boundary[0] = NSMinX(rect);
	r->boundary[1] = NSMinY(rect);
	r->boundary[2] = NSMaxX(rect);
	r->boundary[3] = NSMaxY(rect);
}

static inline RTreeRect NSRectToRTreeRect(NSRect rect)
{
	RTreeRect r;
	r.boundary[0] = NSMinX(rect);
	r.boundary[1] = NSMinY(rect);
	r.boundary[2] = NSMaxX(rect);
	r.boundary[3] = NSMaxY(rect);
	return r;
}

__unused static inline NSRect RTreeRectToNSRect(RTreeRect r)
{
	return NSMakeRect(r.boundary[0], r.boundary[1],
		r.boundary[2] - r.boundary[0],
		r.boundary[3] - r.boundary[1]);
}

static inline NSRect RTreeRectPtrToNSRect(RTreeRect *r)
{
	return NSMakeRect(r->boundary[0], r->boundary[1],
		r->boundary[2] - r->boundary[0],
		r->boundary[3] - r->boundary[1]);
}

////////////////////////////////////////////////////////////
static int _objectIsFound(int index, RTreeRect *R, void *userInfo)
{
	BOOL stop = NO;
	void (^block)(int, RTreeRect *, BOOL *) = ((__bridge NSDictionary *)userInfo)[@"block"];
	block(index, R, &stop);
	return stop ? 0 : 1;
}

////////////////////////////////////////////////////////////
// RTreeIndex
@implementation RTreeIndex
{
	void *_indexRootNode;
	NSMutableOrderedSet *_objects;
	NSMutableIndexSet *_emptySlots;
}
////////////////////////////////////////////////////////////
- (void)hitTest:(NSPoint)point usingBlock:(void (^)(NSUInteger index, NSRect rect, BOOL *stop))block;
{
	RTreeRect r;
	r.boundary[0] = point.x - 2;
	r.boundary[1] = point.y - 2;
	r.boundary[2] = point.x + 2;
	r.boundary[3] = point.y + 2;

	NSDictionary *userInfo = @{
		@"object":_objects,
		@"block":[^(int index, RTreeRect *rect, BOOL *stop) {
			block(index - 1, RTreeRectPtrToNSRect(rect), stop);
		} copy]
	};

	RTreeSearch((RTreeNode *)_indexRootNode, &r, _objectIsFound, (__bridge void *)userInfo);
}

- (void)enumerateObjectsInRect:(NSRect)rect withOptions:(RTreeEnumerationOptions)options
	usingBlock:(void (^)(NSUInteger index, NSRect rect, BOOL *stop))block;
{
	RTreeRect r;
	RTreeRectFromNSRect(rect, &r);

	NSDictionary *userInfo = @{
		@"object":_objects,
		@"block":[^(int index, RTreeRect *rect, BOOL *stop) {
			block(index - 1, RTreeRectPtrToNSRect(rect), stop);
		} copy]
	};

	if(options & RTreeEnumerationInRect)
		RTreeSearchContained((RTreeNode *)_indexRootNode, &r, _objectIsFound, (__bridge void *)userInfo);
	else if(options & RTreeEnumerationEnclosingRect)
		RTreeSearchContaining((RTreeNode *)_indexRootNode, &r, _objectIsFound, (__bridge void *)userInfo);
	else
		RTreeSearch((RTreeNode *)_indexRootNode, &r, _objectIsFound, (__bridge void *)userInfo);
}

- (void)enumerateObjectsInRect:(NSRect)rect usingBlock:(void (^)(NSUInteger index, NSRect rect, BOOL *stop))block;
{
	RTreeRect r;
	RTreeRectFromNSRect(rect, &r);

	NSDictionary *userInfo = @{
		@"object":_objects,
		@"block":[^(int index, RTreeRect *rect, BOOL *stop) {
			block(index - 1, RTreeRectPtrToNSRect(rect), stop);
		} copy]
	};

	RTreeSearch((RTreeNode *)_indexRootNode, &r, _objectIsFound, (__bridge void *)userInfo);
}

- (BOOL)containsObject:(id)object;
{
	return [_objects containsObject:object];
}

- (id)objectAtIndex:(NSUInteger)index;
{
	return _objects[index];
}

- (id)objectAtIndexedSubscript:(NSUInteger)index;
{
	return _objects[index];
}

///////////////////////////////////////////////////////////
- (void)removeObjectsInRect:(NSRect)rect options:(RTreeEnumerationOptions)options;
{
	RTreeRect r;
	RTreeRectFromNSRect(rect, &r);

	NSMutableDictionary *rects = [NSMutableDictionary dictionaryWithCapacity:_objects.count];
	NSDictionary *userInfo = @{
		@"object":_objects,
		@"block":^(void *context, RTreeRect *rect, BOOL *stop) {
			rects[[NSValue valueWithBytes:rect objCType:@encode(RTreeRect)]] = @((NSUInteger)context);
		}
	};

	if(options & RTreeEnumerationInRect)
		RTreeSearchContained((RTreeNode *)_indexRootNode, &r, _objectIsFound, &userInfo);
	else if(options & RTreeEnumerationEnclosingRect)
		RTreeSearchContaining((RTreeNode *)_indexRootNode, &r, _objectIsFound, &userInfo);
	else
		RTreeSearch((RTreeNode *)_indexRootNode, &r, _objectIsFound, &userInfo);

	NSUInteger index;
	for(NSValue *rectValue in rects)
	{
		[rectValue getValue:&r];
		index = [rects[rectValue] unsignedIntegerValue];
		if(RTreeDeleteRect(&r, (__bridge void *)_objects[index], (RTreeNode **)&_indexRootNode))
		{
			NSLog(@"this should not have happened!");
			continue;
		}

		_objects[index] = NSNull.null;
		[_emptySlots addIndex:index];

		NSRange indexRange = NSMakeRange(index, _objects.count - index);
		if([_emptySlots countOfIndexesInRange:indexRange] == indexRange.length)
		{
			[_objects removeObjectsInRange:indexRange];
			[_emptySlots removeIndexesInRange:indexRange];
		}
	}
}

- (void)removeAllObjects;
{
	[_objects removeAllObjects];
	[_emptySlots removeAllIndexes];
	if(_indexRootNode)
		RTreeRecursivelyFreeNode((RTreeNode *)_indexRootNode);
	_indexRootNode = RTreeNewIndex();
}

////////////////////////////////////////////////////////////
- (NSInteger)insertObject:(id)object withRect:(NSRect)rect;
{
	RTreeRect rNew = NSRectToRTreeRect(rect);
	NSInteger index = 1 + (_emptySlots.count ? _emptySlots.firstIndex : _objects.count);
	RTreeInsertRect(&rNew, (void *)index, (RTreeNode **)&_indexRootNode, 0);

	if(_emptySlots.count)
	{
		_objects[_emptySlots.firstIndex] = object;
		[_emptySlots removeIndex:_emptySlots.firstIndex];
	}
	else
	{
		[_objects addObject:object];
	}

	return index;
}

////////////////////////////////////////////////////////////
#if defined(ALSO_objectRectangles)
- (BOOL)removeObjectAtIndex:(NSInteger)index;
{
	NSParameterAssert(_objects[index] != [NSNull null]);
	NSRect rect = [_objectRectangles[index] rectValue];

	RTreeRect r = NSRectToRTreeRect(rect);
	if(!RTreeDeleteRect(&r, (void *)index, (RTreeNode **)&_indexRootNode))
		return NO;

	_objects[index] = [NSNull null];
	_objectRectangles[index] = [NSNull null];
	[_emptySlots addIndex:index];

	NSRange indexRange = NSMakeRange(index, _objects.count - index);
	if([_emptySlots countOfIndexesInRange:indexRange] == indexRange.length)
	{
		[_objects removeObjectsInRange:indexRange];
		[_objectRectangles removeObjectsInRange:indexRange];
		[_emptySlots removeIndexesInRange:indexRange];
	}
	return YES;
}
#endif

////////////////////////////////////////////////////////////
- (NSRect)bounds;
{
	RTreeNode *n = (RTreeNode *)_indexRootNode;
	NSRect bounds = NSZeroRect;
	NSRect rect;
	NSParameterAssert(n);
	NSParameterAssert(n->level >= 0);
	NSInteger i, count = (n->level > 0) ? NODECARD : LEAFCARD;
	for(i = 0; i < count; i++)
	{
		rect.origin.x = n->branch[i].rect.boundary[0];
		rect.origin.y = n->branch[i].rect.boundary[1];
		rect.size.width = n->branch[i].rect.boundary[2] - rect.origin.x;
		rect.size.height = n->branch[i].rect.boundary[3] - rect.origin.y;
		bounds = NSUnionRect(bounds, rect);
	}
	return bounds;
}

////////////////////////////////////////////////////////////
- (NSArray *)allObjects;
{
	NSMutableOrderedSet *objects = [NSMutableOrderedSet orderedSetWithOrderedSet:_objects range:NSMakeRange(0, _objects.count) copyItems:NO];
	[objects removeObjectsAtIndexes:_emptySlots];
	return objects.array;
}

////////////////////////////////////////////////////////////
- (void)dealloc;
{
	if(_indexRootNode)
		RTreeRecursivelyFreeNode((RTreeNode *)_indexRootNode);
	_indexRootNode = NULL;
}

- (id)init;
{
	if(![super init])
		return NULL;
	_indexRootNode = RTreeNewIndex();
	_objects = [NSMutableOrderedSet orderedSetWithCapacity:171];
	_emptySlots = [NSMutableIndexSet indexSet];
	return self;
}
@end
