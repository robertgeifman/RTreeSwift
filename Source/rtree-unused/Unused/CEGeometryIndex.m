// CEGeometryIndex.m: implementation of the CEGeometryIndex class

#import "CEGeometryIndex.h"
#import "CEGeometryIndexNode.h"
#import "CEFoundation-Private.h"

#define GSI_MAP_HAS_VALUE 0
#define GSI_MAP_KTYPE GSUNION_OBJ
#include "GSIMap.h"

////////////////////////////////////////////////////////////
static NSZone *rectZone = NULL;
static const float CAPACITY = 5;

////////////////////////////////////////////////////////////
static int compareCenterX(id object1, id object2, void *context)
{
	return NSMidX([object1 nodeBounds]) < 
		NSMidX([object2 nodeBounds]);
}

static int compareCenterY(id object1, id object2, void *context)
{
	return NSMidY([object1 nodeBounds]) < 
		NSMidY([object2 nodeBounds]);
}

static int splitCost(NSRect rect1, NSRect rect2)
{
	return ABS(ABS(rect1.size.width * rect1.size.height) - 
		ABS(rect2.size.width * rect2.size.height));
}

////////////////////////////////////////////////////////////
// CEGeometryIndex
@implementation CEGeometryIndex
- (CEGeometryIndexNode *)mergeNode:(CEGeometryIndexNode *)newNode 
	withNode:(CEGeometryIndexNode *)node diffHeight:(int)diffHeight;
{
	if(diffHeight > 1)
	{
		node = [node chooseSubNode:[newNode nodeBounds]];
		[self mergeNode:newNode withNode:node diffHeight:diffHeight - 1];
	}
	else
	{
		[[node mutableSetValueForKey:@"objects"] addObject:newNode];
	}
	return node;
}

////////////////////////////////////////////////////////////
- (CEGeometryIndexNode *)loadObjects:(NSSet *)objects :(NSMutableSet *)endNodes;
{
	const int count = [objects count];
	const float M = pow(CAPACITY, (ceil(log2((float)count)/log2(CAPACITY)) - 1));

	if(count <= M || M <= 1)
	{
		CEGeometryIndexNode *node = [CEGeometryIndexNode nodeWithObjects:objects inIndex:self];
		[endNodes addObject:node];
		return node;
	}

	int numberOfGroups = ceil(count/M);
	if(M * numberOfGroups < count)
		++numberOfGroups;

	int result[2] = { INT_MAX, INT_MAX };
	int position[2] = { 0, 0 };
	NSRect *rectArray = NSZoneCalloc(rectZone, numberOfGroups * 2, sizeof(NSRect));
	NSArray *sortedObjects[2];
	int i, j, k;
	int currentValue;
	NSRect rect1, rect2;

	////////////////////////////////////////////////////////////
	sortedObjects[0] = [objects sortedSetUsingFunction:compareCenterX];
	NSData *hint = [[sortedObjects[0] sortedArrayHint] retain];

	rectArray[0] = NSZeroRect;
	j = k = 0;
	for(i = 0; i < count; i++)
	{
		rectArray[k] = NSUnionRect(rectArray[k], 
			[[[sortedObjects[0] objectAtIndex:i] valueForKey:_observedKey] rectValue]);
		if(++j == M)
		{
			rectArray[++k] = NSZeroRect;
			j = 0;
		}	
	}

	rect1 = NSZeroRect;
	rect2 = NSZeroRect;
	for(i = 1; i < numberOfGroups; i++)
	{
		for(j = 0; j < i; j++)
			rect1 = NSUnionRect(rect1, rectArray[j]);
		for(; j < numberOfGroups; j++)
			rect2 = NSUnionRect(rect2, rectArray[j]);
		if(result[0] > (currentValue = splitCost(rect1, rect2)))
		{
			result[0] = currentValue;
			position[0] = i * M;
		}
	}

	////////////////////////////////////////////////////////////
	sortedObjects[1] = [sortedObjects[0] sortedArrayUsingFunction:compareCenterY 
		context:_observedKey hint:hint];
	[hint release];

	rectArray[0] = NSZeroRect;
	j = k = 0;
	for(i = 0; i < count; i++)
	{
		rectArray[k] = NSUnionRect(rectArray[k], 
			[[[sortedObjects[1] objectAtIndex:i] valueForKey:_observedKey] rectValue]);
		if(++j == M)
		{
			rectArray[++k] = NSZeroRect;
			j = 0;
		}	
	}

	rect1 = NSZeroRect;
	rect2 = NSZeroRect;
	for(i = 1; i < numberOfGroups; i++)
	{
		for(j = 0; j < i; j++)
			rect1 = NSUnionRect(rect1, rectArray[j]);
		for(; j < numberOfGroups; j++)
			rect2 = NSUnionRect(rect2, rectArray[j]);
		if(result[1] > (currentValue = splitCost(rect1, rect2)))
		{
			result[1] = currentValue;
			position[1] = i * M;
		}
	}

	NSZoneFree(rectZone, rectArray);

	int index = (result[0] < result[1] ? 0: 1);
	NSSet *a1 = [NSSet setWithArray:[sortedObjects[index] subarrayWithRange:NSMakeRange(0, position[index])]];
	NSSet *a2 = [NSSet setWithArray:[sortedObjects[index] subarrayWithRange:NSMakeRange(position[index], count - position[index])]];
	CEGeometryIndexNode *n1 = [self loadObjects:a1 :endNodes];
	CEGeometryIndexNode *n2 = [self loadObjects:a2 :endNodes];
	return [CEGeometryIndexGroupNode nodeWithObjects:[NSSet setWithObjects:n1, n2, NULL] inIndex:self];
}

////////////////////////////////////////////////////////////
- (void)addObjects:(NSSet *)objects;
{
	NSRect treeBounds = [_root nodeBounds];
	NSEnumerator *enumerator = [objects objectEnumerator];
	id object;

#if 0 // TO DO
	if(!shouldCompact && [objects count] <= CAPACITY) // add Object By Object
	{
		//[self addObjects:insideObjectsOBO:insideObjects];
		// return;
	}
#endif

	NSMutableSet *insideObjects = [NSMutableSet set];
	NSMutableSet *outsideObjects = [NSMutableSet set];
	while(object = [enumerator nextObject])
	{
		if(NSContainsRect(treeBounds, [[object valueForKey:_observedKey] rectValue]))
			[insideObjects addObject:object];
		else
			[outsideObjects addObject:object];
	}
	
	CEGeometryIndexNode *newNode, *newRoot;
	if([insideObjects count])
	{
		NSMutableSet *insideNodes = [NSMutableSet set];
		newNode = [self loadObjects:insideObjects :[insideNodes retain]];
		[_endNodes unionSet:[insideNodes autorelease]];
		int diffHeight = [_root height] - [newNode height];
		if(!diffHeight)
			[self compact]; // this should not happen 
		else if(diffHeight > 0)
		{
			newRoot = [self mergeNode:newNode withNode:_root diffHeight:diffHeight]; 
			[self setRoot:newRoot];
		}
		else
		{
			newRoot = [self mergeNode:_root withNode:newNode diffHeight:0 - diffHeight];
			[self setRoot:newRoot];
		}
		[_root recursivelyUpdateNodeBounds];
	}
	
	if([outsideObjects count])
	{
		NS_DURING
		NSMutableSet *outsideNodes = [NSMutableSet set];
		newNode = [self loadObjects:outsideObjects :[outsideNodes retain]];
		[_endNodes unionSet:[outsideNodes autorelease]];
		if([[_root valueForKey:@"objects"] count])
		{
			newRoot = [CEGeometryIndexGroupNode nodeWithObjects:[NSSet
				setWithObjects:_root, newNode, NULL] inIndex:self];
			[self setRoot:newRoot];
		}
		else
			[self setRoot:newNode];
		NS_HANDLER
		NS_ENDHANDLER
	}
}

- (void)removeObjects:(NSSet *)objects;
{
	NSEnumerator *enumerator = [_endNodes objectEnumerator];
	CEGeometryIndexNode *node;
//	id object;
	while(node = [enumerator nextObject])
		[[node mutableSetValueForKey:@"objects"] minusSet:objects];

	[_root recursivelyUpdateNodeBounds];
}

- (void)compact;
{
	[_endNodes release];
	_endNodes = [[NSMutableSet setWithCapacity:31] retain];
	[self setRoot:[self loadObjects:[NSSet setWithArray:_contentArray] :_endNodes]];
}

////////////////////////////////////////////////////////////
- (void)removeAddObjects:(NSSet *)oldObjects :(NSSet *)newObjects :(BOOL)shouldUpdate;
{
	if(shouldUpdate)
	{
		[self removeObjects:oldObjects];
		[self addObjects:newObjects];
		return;
	}

	int oldCount = [oldObjects count], newCount = [newObjects count];

	GSIMapTable_t objectsToRemove, objectsToAdd;
	GSIMapInitWithZoneAndCapacity(&objectsToRemove, [self zone], oldCount);
	GSIMapInitWithZoneAndCapacity(&objectsToAdd, [self zone], newCount);
	NSEnumerator *enumerator;
	id object;
	if(oldCount < newCount)
	{
		enumerator = [oldObjects objectEnumerator];
		while(object = [enumerator nextObject])
		{
			if(!GSIMapNodeForKey(&objectsToRemove, (GSIMapKey)object))
				GSIMapAddKey(&objectsToRemove, (GSIMapKey)object);
		}

		enumerator = [newObjects objectEnumerator];
		while(object = [enumerator nextObject])
		{
			if(GSIMapNodeForKey(&objectsToRemove, (GSIMapKey)object))
			{
				GSIMapRemoveKey(&objectsToRemove, (GSIMapKey)object);
				--oldCount;
				--newCount;
			}
			else if(!GSIMapNodeForKey(&objectsToAdd, (GSIMapKey)object))
				GSIMapAddKey(&objectsToAdd, (GSIMapKey)object);
		}
	}
	else
	{
		enumerator = [newObjects objectEnumerator];
		while(object = [enumerator nextObject])
		{
			if(!GSIMapNodeForKey(&objectsToAdd, (GSIMapKey)object))
				GSIMapAddKey(&objectsToAdd, (GSIMapKey)object);
		}

		enumerator = [oldObjects objectEnumerator];
		while(object = [enumerator nextObject])
		{
			if(GSIMapNodeForKey(&objectsToAdd, (GSIMapKey)object))
			{
				GSIMapRemoveKey(&objectsToAdd, (GSIMapKey)object);
				--newCount;
				--oldCount;
			}
			else if(!GSIMapNodeForKey(&objectsToRemove, (GSIMapKey)object))
				GSIMapAddKey(&objectsToRemove, (GSIMapKey)object);
		}
	}

	GSIMapEnumerator_t mapEnumerator = GSIMapEnumeratorForMap(&objectsToRemove);
	GSIMapNode node;
	NSMutableSet *set = [NSMutableSet set];
	while(node = GSIMapEnumeratorNextNode(&mapEnumerator))
		[set addObject:node->key.obj];
	GSIMapEndEnumerator(&mapEnumerator);
	[self removeObjects:set];

	mapEnumerator = GSIMapEnumeratorForMap(&objectsToAdd);
	set = [NSMutableSet set];
	while(node = GSIMapEnumeratorNextNode(&mapEnumerator))
		[set addObject:node->key.obj];
	GSIMapEndEnumerator(&mapEnumerator);
	[self addObjects:set];
}

////////////////////////////////////////////////////////////
- (id)singleHitTest:(NSPoint)point;
{
	return [[(CEGeometryIndexNode *)_root hitTest:point slop:1] anyObject];
}

- (id)singleHitTest:(NSPoint)point slop:(float)slop;
{
	return [[(CEGeometryIndexNode *)_root hitTest:point slop:slop] anyObject];
}

- (NSSet *)hitTest:(NSPoint)point;
{
	return [self hitTest:point slop:1];
}

- (NSSet *)hitTest:(NSPoint)point slop:(float)slop;
{
	return [(CEGeometryIndexNode *)_root hitTest:point slop:slop];
}

- (NSSet *)objectsInRect:(NSRect)rect;
{
	return [(CEGeometryIndexNode *)_root objectsInRect:rect];
}

- (NSSet *)objectsIntersectingRect:(NSRect)rect;
{
	return [(CEGeometryIndexNode *)_root objectsIntersectingRect:rect];
}

- (NSSet *)objectsEnclosingRect:(NSRect)rect;
{
	return [(CEGeometryIndexNode *)_root objectsEnclosingRect:rect];
}

////////////////////////////////////////////////////////////
- (NSIndexSet *)indexesOfObjectsInRect:(NSRect)rect;
{
	return [_contentArray indexesOfObjectsInSet:[(CEGeometryIndexNode *)_root objectsInRect:rect]];
}

- (NSIndexSet *)indexesOfObjectsIntersectingRect:(NSRect)rect;
{
	return [_contentArray indexesOfObjectsInSet:[(CEGeometryIndexNode *)_root objectsIntersectingRect:rect]];
}

- (NSIndexSet *)indexesOfObjectsEnclosingRect:(NSRect)rect;
{
	return [_contentArray indexesOfObjectsInSet:[(CEGeometryIndexNode *)_root objectsEnclosingRect:rect]];
}

////////////////////////////////////////////////////////////
- (NSArray *)contentArray;
{
	return _contentArray;
}

- (void)setContentArray:(NSArray *)value;
{
//	[self willChangeValueForKey:NSContentArrayBinding];
	[_contentArray release];
	_contentArray = [value copy];
//	[self didChangeValueForKey:NSContentArrayBinding];
}

- (CEGeometryIndexNode *)root;
{
	return _root;
}

- (void)setRoot:(CEGeometryIndexNode *)value;
{
	[value retain];
	[_root release];
	_root = value;
}

////////////////////////////////////////////////////////////
+ (void)initialize;
{
	CEINITIALIZE;
	rectZone = NSCreateZone(40 * sizeof(NSRect), 20 * sizeof(NSRect), NO);
}

- (void)dealloc;
{
	[_root release];
	[_endNodes release];
	[_contentArray release];
	[super dealloc];
}


- (id)initWithCapacity:(int)capacity;
{
	if(![super init])
		return NULL;
	_root = NULL;
	_endNodes = [[NSMutableSet setWithCapacity:31] retain];
	return self;
}

- (id)init;
{
	return [self initWithCapacity:CAPACITY];
}
@end
