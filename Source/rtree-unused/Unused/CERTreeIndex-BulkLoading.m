// CERTreeIndex.m : implementation of the CERTreeIndex class BulkLoading category
#import "CERTreeIndex.h"
#import "RTreeIndexImpl.h"
#import "RTreeCard.h"

////////////////////////////////////////////////////////////
// CERTreeIndex (BulkLoading)
@implementation CERTreeIndex (BulkLoading)
#if 0
- (int)insertObjects:(NSArray *)objects withRects:(NSArray *)rectArray;
{
}

- (int)insertObjects:(NSArray *)objects _withRects:(NSRectPointer)rectArray;
- (BOOL)removeObjectsAtIndexes:(NSIndexSet *)indexSet;
////////////////////////////////////////////////////////////
- (int)insertObject:(id)object withRect:(NSRect)rect;
{
	RTreeRect r;
	r.boundary[0] = NSMinX(rect);
	r.boundary[1] = NSMinY(rect);
	r.boundary[2] = NSMaxX(rect);
	r.boundary[3] = NSMaxY(rect);
	int index = [_emptySlots count] ? [_emptySlots firstIndex] : [_objects count];
	if(!RTreeInsertRect(&r, (void *)index, (Node **)&_indexRootNode, 0))
		return NSNotFound;

	if([_emptySlots count])
	{
		[_objects replaceObjectAtIndex:[_emptySlots firstIndex] 
			withObject:object];
		[_objectRectangles replaceObjectAtIndex:[_emptySlots firstIndex] 
			withObject:[NSValue valueWithRect:rect]];
		[_emptySlots removeIndex:[_emptySlots firstIndex]];
	}
	else
	{
		[_objects addObject:object];
		[_objectRectangles addObject:[NSValue valueWithRect:rect]];
	}
	return index;
}

- (BOOL)removeObjectAtIndex:(int)index;
{
	NSParameterAssert([_objects objectAtIndex:index] != [NSNull null]);
	NSRect rect = [[_objectRectangles objectAtIndex:index] rectValue];

	RTreeRect r;
	r.boundary[0] = NSMinX(rect);
	r.boundary[1] = NSMinY(rect);
	r.boundary[2] = NSMaxX(rect);
	r.boundary[3] = NSMaxY(rect);
	if(!RTreeDeleteRect(&r, (void *)index, (Node **)&_indexRootNode))
		return NO;

	[_objects replaceObjectAtIndex:index withObject:[NSNull null]];
	[_objectRectangles replaceObjectAtIndex:index withObject:[NSNull null]];
	[_emptySlots addIndex:index];

	NSRange indexRange = NSMakeRange(index, [_objects count] - index);
	if([_emptySlots countOfIndexesInRange:indexRange] == indexRange.length)
	{
		[_objects removeObjectsInRange:indexRange];
		[_objectRectangles removeObjectsInRange:indexRange];
		[_emptySlots removeIndexesInRange:indexRange];
	}
	return YES;
}
#endif
@end