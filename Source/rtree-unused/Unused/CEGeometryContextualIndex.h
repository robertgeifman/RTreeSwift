// CEGeometryContextualIndex.h: interface of the CEGeometryContextualIndex class

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "CEGeometry.h"
#import "CEGeometryIndex.h"

////////////////////////////////////////////////////////////
// CEGeometryContextualIndex
@interface CEGeometryContextualIndex: CEGeometryIndex
{
	void *_observationInfo;
	NSString *_observedKey;
}
- (NSString *)observedKey;
- (void)setObservedKey:(NSString *)value;

- (void)suspendObservingObjects;
- (void)resumeObservingObjects;
- (void)suspendObservingObjectsAtIndexes:(NSIndexSet *)indexSet;
- (void)resumeObservingObjectsAtIndexes:(NSIndexSet *)indexSet;
@end
