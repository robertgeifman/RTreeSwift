// CEGeometryIndex.h : interface of the CEGeometryIndex class

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "CEGeometry.h"

////////////////////////////////////////////////////////////
// CEGeometryIndex
@interface CEGeometryIndex : NSObject
{
	NSArray *_contentArray;
	NSMutableSet *_endNodes;
	id _root;
	BOOL shouldCompact;
}
- (id)initWithCapacity:(int)capacity;

- (void)compact;
- (int)addObject:(id)object withRect:(NSRect)rect;
- (void)removeObject:(id)object;
- (void)removeObjectsInRect:(id)object;

- (void)removeAddObjects:(NSSet *)oldObjects :(NSSet *)newObjects :(BOOL)shouldUpdate;

- (id)singleHitTest:(NSPoint)point;
- (id)singleHitTest:(NSPoint)point slop:(float)slop;

- (NSSet *)hitTest:(NSPoint)point;
- (NSSet *)hitTest:(NSPoint)point slop:(float)slop;

- (NSSet *)objectsInRect:(NSRect)rect;
- (NSSet *)objectsIntersectingRect:(NSRect)rect;
- (NSSet *)objectsEnclosingRect:(NSRect)rect;

- (NSIndexSet *)indexesOfObjectsInRect:(NSRect)rect;
- (NSIndexSet *)indexesOfObjectsIntersectingRect:(NSRect)rect;
- (NSIndexSet *)indexesOfObjectsEnclosingRect:(NSRect)rect;

//- (NSIndexSet *)applyIndexesOfObjectsInRect:(NSRect)rect toIndexSet:(NSIndexSet *)indexSet;
@end
