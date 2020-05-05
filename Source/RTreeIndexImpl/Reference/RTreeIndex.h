// RTreeIndex.h : interface of the RTreeIndex class
#import "Interoperability-Compatibility.h"

////////////////////////////////////////////////////////////
// RTreeEnumerationOptions
typedef enum _RTreeEnumerationOptions {
	RTreeEnumerationDefaultRect = 0,
	RTreeEnumerationIntersectingRect = RTreeEnumerationDefaultRect,
	RTreeEnumerationInRect,
	RTreeEnumerationEnclosedByRect = RTreeEnumerationInRect,
	RTreeEnumerationEnclosingRect,
} RTreeEnumerationOptions;

////////////////////////////////////////////////////////////
// RTreeIndex
@interface RTreeIndex : NSObject
- (id)objectAtIndex:(NSUInteger)index;
- (id)objectAtIndexedSubscript:(NSUInteger)index;
- (BOOL)containsObject:(id)object;
- (NSArray *)allObjects;
- (NSRect)bounds;

- (NSInteger)insertObject:(id)object withRect:(NSRect)rect;
- (void)removeObjectsInRect:(NSRect)rect options:(RTreeEnumerationOptions)options;
- (void)removeAllObjects;

- (void)hitTest:(NSPoint)point usingBlock:(void (^)(NSUInteger index, NSRect rect, BOOL *stop))block;
- (void)enumerateObjectsInRect:(NSRect)rect usingBlock:(void (^)(NSUInteger index, NSRect rect, BOOL *stop))block;
- (void)enumerateObjectsInRect:(NSRect)rect withOptions:(RTreeEnumerationOptions)options
	usingBlock:(void (^)(NSUInteger index, NSRect rect, BOOL *stop))block;
@end

/*////////////////////////////////////////////////////////////
// RTreeIndex (BulkLoading)
@interface RTreeIndex (BulkLoading)
- (NSInteger)insertObjects:(NSArray *)objects withRects:(NSArray *)rectArray;
- (NSInteger)insertObjects:(NSArray *)objects _withRects:(NSRectPointer)rectArray;
- (BOOL)removeObjectsAtIndexes:(NSIndexSet *)indexSet;
@end
*/
