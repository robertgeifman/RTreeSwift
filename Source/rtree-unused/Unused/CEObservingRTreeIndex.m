// CEObservingRTreeIndex.m : implementation of the CEObservingRTreeIndex class

#import "CEObservingRTreeIndex.h"
#import "CEFoundation-Private.h"

////////////////////////////////////////////////////////////
// CEObservingRTreeIndex
@implementation CEObservingRTreeIndex
- (int)insertObject:(id)object withRect:(NSRect)rect;
{
	int index = [super insertObject:object withRect:rect];
	if(NSNotFound != index)
		[_objects addObserver:self toObjectsAtIndexes:[NSIndexSet indexSetWithIndex:index]  
			forKeyPath:_observedKeyPath options:__observeBoth context:_observedKeyPathContext];
	return index;
}

- (BOOL)removeObjectAtIndex:(int)index;
{
	BOOL result;
	if(result = [super removeObjectAtIndex:index])
		[_objects removeObserver:self fromObjectsAtIndexes:[NSIndexSet indexSetWithIndex:index] 
			forKeyPath:_observedKeyPath];
	return result;
}

////////////////////////////////////////////////////////////
- (void)loadObjects:(NSArray *)objects;
{
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
	NSEnumerator *enumerator = [objects objectEnumerator];
	id object;
	int index;
	while(object = [enumerator nextObject])
	{
		if(NSNotFound != (index = [super insertObject:object withRectValue:[object valueForKeyPath:_observedKeyPath]]))
			[indexSet addIndex:index];
	}
	[_objects addObserver:self toObjectsAtIndexes:indexSet 
		forKeyPath:_observedKeyPath options:__observeBoth context:_observedKeyPathContext];
}

- (void)removeAllObjects;
{
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_objects count])];
	[indexSet removeIndexes:_emptySlots];
	[_objects removeObserver:self fromObjectsAtIndexes:indexSet forKeyPath:_observedKeyPath];
	[super removeAllObjects];
}

////////////////////////////////////////////////////////////
- (void)suspendObservingObjects;
{
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_objects count])];
	[indexSet removeIndexes:_emptySlots];
	[self suspendObservingObjectsAtIndexes:indexSet];
}

- (void)resumeObservingObjects;
{
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_objects count])];
	[indexSet removeIndexes:_emptySlots];
	[self resumeObservingObjectsAtIndexes:indexSet];
}

- (void)suspendObservingObjectsAtIndexes:(NSIndexSet *)indexes;
{
	NSMutableIndexSet *indexSet = [[indexes mutableCopy] autorelease];
	[indexSet removeIndexes:_emptySlots];
	[_objects removeObserver:self fromObjectsAtIndexes:indexSet forKeyPath:_observedKeyPath];
}

- (void)resumeObservingObjectsAtIndexes:(NSIndexSet *)indexes;
{
	NSMutableIndexSet *indexSet = [[indexes mutableCopy] autorelease];
	[indexSet removeIndexes:_emptySlots];

	foreachindex(indexSet, index)
	{
		id object = [[_objects objectAtIndex:index] retain];
		NSValue *rectValue = [object valueForKeyPath:_observedKeyPath];
		[super setRectValue:rectValue forObjectAtIndex:index];
	}
	[_objects addObserver:self toObjectsAtIndexes:indexSet forKeyPath:_observedKeyPath 
		options:__observeBoth context:_observedKeyPathContext];
}

////////////////////////////////////////////////////////////
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)observedObject 
	change:(NSDictionary *)change context:(void *)context;
{
	change = checkChange(change);
	if(context == _observedKeyPathContext)
	{
		NSIndexSet *indexSet;
		if(!(indexSet = [change objectForKey:NSKeyValueChangeIndexesKey]))
		{
			NSLog(@"No index set in [CEObservingRTreeIndex observeValueForKeyPath:...]");
			indexSet = [NSIndexSet indexSetWithIndex:[_objects indexOfObject:observedObject]];
		}

		foreachindex(indexSet, index)
		{
			NSValue *rectValue = [observedObject valueForKeyPath:_observedKeyPath];
			[super setRectValue:rectValue forObjectAtIndex:index];
		}
//		[self removeAddObjects:objects :objects :NO];
	}
#if 0
	if(context == _observedKeyPathContext) // this is what was there
	{
		NSSet *objects = [NSSet setWithArray:[NSArray arrayWithObject:observedObject]];
		[self removeAddObjects:objects :objects :NO];
	}
	else if(context == _contentArrayContext)
	{
		NSArray *oldObjects = [change objectForKey:NSKeyValueChangeOldKey];
		NSArray *newObjects = [change objectForKey:NSKeyValueChangeNewKey];
		NSIndexSet *indexSet;
		int changeKind = [[change objectForKey:NSKeyValueChangeKindKey] intValue];
		
		if(!(oldObjects && [oldObjects isKindOfClass:[NSArray class]] && [oldObjects count]))
			oldObjects = NULL;
		else
		{
			indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 
				[oldObjects count])];
			[oldObjects removeObserver:self fromObjectsAtIndexes:indexSet forKeyPath:_observedKeyPath];
		}

		if(!(newObjects && [newObjects isKindOfClass:[NSArray class]] && [newObjects count]))
			newObjects = NULL;
		else
		{
			indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [newObjects count])];
			if([indexSet count])
				[newObjects addObserver:self toObjectsAtIndexes:indexSet forKeyPath:_observedKeyPath 
					options:__observeBoth context:_observedKeyPathContext];
		}
		
		[self removeAddObjects:[NSSet setWithArray:oldObjects] :[NSSet setWithArray:newObjects] 
			:changeKind == NSKeyValueChangeSetting];
	}
#endif
}

////////////////////////////////////////////////////////////
- (void *)observationInfo;
{
	return _observationInfo;
}

- (void)setObservationInfo:(void *)value;
{
	_observationInfo = value;
}

- (NSString *)observedKeyPath;
{
	return _observedKeyPath;
}

////////////////////////////////////////////////////////////
- (id)initWithCoder:(NSCoder *)coder;
{
	if(!([[self superclass] conformsToProtocol:@protocol(NSCoding)] ?
		[(id <NSCoding>)super initWithCoder:coder] : [super init]))
		return NULL;
	_observedKeyPath = [[coder decodeObjectForKey:@"observedKeyPath"] retain];
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder;
{
	if([[self superclass] conformsToProtocol:@protocol(NSCoding)])
		[(id <NSCoding>)super encodeWithCoder:coder];
	[coder encodeObject:_observedKeyPath forKey:@"observedKeyPath"];
}

////////////////////////////////////////////////////////////
+ (void)initialize;
{
	CEINITIALIZE;
//	[self exposeBinding:NSContentArrayBinding];
}

- (void)dealloc;
{
//	[self unbind:NSContentArrayBinding];
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_objects count])];
	[indexSet removeIndexes:_emptySlots];
	[_objects removeObserver:self fromObjectsAtIndexes:indexSet forKeyPath:_observedKeyPath];

//	[self removeObserver:self forKeyPath:@"contentArray"];
	[_observedKeyPath release];
	[super dealloc];
}

- (id)initWithObservedKey:(NSString *)observedKeyPath;
{
	if(![super init])
		return NULL;
	_observedKeyPath = [_observedKeyPath copy];
	return self;
}

- (id)init;
{
	return CERejectUnusedImplementation(self, _cmd);
}
@end