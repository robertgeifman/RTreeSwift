// CEGeometryContextualIndex.m : implementation of the CEGeometryContextualIndex class

#import "CEGeometryContextualIndex.h"
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
	return NSMidX([[object1 valueForKeyPath:(NSString *)context] rectValue]) < 
		NSMidX([[object2 valueForKeyPath:(NSString *)context] rectValue]);
}

static int compareCenterY(id object1, id object2, void *context)
{
	return NSMidY([[object1 valueForKeyPath:(NSString *)context] rectValue]) < 
		NSMidY([[object2 valueForKeyPath:(NSString *)context] rectValue]);
}

static int splitCost(NSRect rect1, NSRect rect2)
{
	return ABS(ABS(rect1.size.width * rect1.size.height) - 
		ABS(rect2.size.width * rect2.size.height));
}

////////////////////////////////////////////////////////////
// CEGeometryContextualIndex
@implementation CEGeometryContextualIndex
- (void *)observationInfo;
{
	return _observationInfo;
}

- (void)setObservationInfo:(void *)value;
{
	_observationInfo = value;
}

- (NSString *)observedKey;
{
	return _observedKey;
}

- (void)setObservedKey:(NSString *)value;
{
	[_observedKey release];
	_observedKey = [value retain];
}

////////////////////////////////////////////////////////////
- (void)suspendObservingObjects;
{
	NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_contentArray count])];
	[self suspendObservingObjectsAtIndexes:indexSet];
}

- (void)resumeObservingObjects;
{
	NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_contentArray count])];
	[self resumeObservingObjectsAtIndexes:indexSet];
}

- (void)suspendObservingObjectsAtIndexes:(NSIndexSet *)indexSet;
{
	[_contentArray removeObserver:self fromObjectsAtIndexes:indexSet forKeyPath:_observedKey];
}

- (void)resumeObservingObjectsAtIndexes:(NSIndexSet *)indexSet;
{
	NSSet *objects = [NSSet setWithArray:[_contentArray objectsAtIndexes:indexSet]];
	[self removeAddObjects:objects :objects :YES];
	[_contentArray addObserver:self toObjectsAtIndexes:indexSet forKeyPath:_observedKey 
		options:__observeBoth context:_observedKeyPathContext];
}

////////////////////////////////////////////////////////////
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)observedObject 
	change:(NSDictionary *)change context:(void *)context;
{
	change = checkChange(change);
	if(context == _observedKeyPathContext)
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
			[oldObjects removeObserver:self fromObjectsAtIndexes:indexSet forKeyPath:_observedKey];
		}

		if(!(newObjects && [newObjects isKindOfClass:[NSArray class]] && [newObjects count]))
			newObjects = NULL;
		else
		{
			indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [newObjects count])];
			if([indexSet count])
				[newObjects addObserver:self toObjectsAtIndexes:indexSet forKeyPath:_observedKey options:__observeBoth context:_observedKeyPathContext];
		}
		
		[self removeAddObjects:[NSSet setWithArray:oldObjects] :[NSSet setWithArray:newObjects] 
			:changeKind == NSKeyValueChangeSetting];
	}
}

////////////////////////////////////////////////////////////
- (Class)valueClassForBinding:(NSString *)binding;
{
	if([binding isEqualToString:NSContentArrayBinding])
		return [NSArray class];
	return [super valueClassForBinding:binding];
}

////////////////////////////////////////////////////////////
+ (void)initialize;
{
	CEINITIALIZE;
	[self exposeBinding:NSContentArrayBinding];
}

- (void)dealloc;
{
	[self unbind:NSContentArrayBinding];
	NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_contentArray count])];
	[_contentArray removeObserver:self fromObjectsAtIndexes:indexSet forKeyPath:_observedKey];

	[self removeObserver:self forKeyPath:@"contentArray"];
	[_observedKey release];
	[super dealloc];
}

- (id)initWithCapacity:(int)capacity;
{
	if(![super initWithCapacity:capacity])
		return NULL;
	[self addObserver:self forKeyPath:@"contentArray" options:__observeBoth context:_contentArrayContext];
	_observedKey = [@"frame" retain];
	return self;
}

- (id)init;
{
	return [self initWithCapacity:CAPACITY];
}
@end
