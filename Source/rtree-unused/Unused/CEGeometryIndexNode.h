// CEGeometryIndex.h: interface of the CEGeometryIndex class

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "CEGeometry.h"

////////////////////////////////////////////////////////////
// CEGeometryObject
@protocol CEObjectWithBounds <NSObject>
- (NSRect)frame;
@end

////////////////////////////////////////////////////////////
@class CEGeometryIndex;

////////////////////////////////////////////////////////////
typedef BOOL (*_searchFunction)(NSRect, NSRect);

////////////////////////////////////////////////////////////
// CEGeometryIndexNode
@interface CEGeometryIndexNode: NSObject
{
__weak 
	CEGeometryIndex *_index;
	NSMutableSet *_objects;
	NSRect _nodeBounds;
}
+ (CEGeometryIndexNode *)nodeWithObjects:(NSSet *)objects inIndex:(CEGeometryIndex *)index;
- (id)initWithObjects:(NSSet *)objects inIndex:(CEGeometryIndex *)index;

- (NSRect)nodeBounds;
- (NSRect)recursivelyUpdateNodeBounds;
- (int)height;

- (NSSet *)hitTest:(NSPoint)point slop:(float)slop;
- (NSSet *)objectsInRect:(NSRect)rect;
- (NSSet *)objectsIntersectingRect:(NSRect)rect;
- (NSSet *)objectsEnclosingRect:(NSRect)rect;

- (void)searchUsingFunction:(_searchFunction)function rect:(NSRect)rect 
	result:(NSMutableSet *)result;
- (CEGeometryIndexNode *)chooseSubNode:(NSRect)rect;
@end

////////////////////////////////////////////////////////////
// CEGeometryIndexGroupNode
@interface CEGeometryIndexGroupNode: CEGeometryIndexNode
@end
