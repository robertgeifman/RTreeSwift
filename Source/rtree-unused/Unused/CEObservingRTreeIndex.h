// CEObservingRTreeIndex.h: interface of the CEObservingRTreeIndex class

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "CERTreeIndex.h"
#import "CEGeometry.h"

////////////////////////////////////////////////////////////
// CEObservingRTreeIndex
@interface CEObservingRTreeIndex: CERTreeIndex <NSCoding>
{
	void *_observationInfo;
	NSString *_observedKeyPath;
}
- (id)initWithObservedKey:(NSString *)observedKeyPath;
- (NSString *)observedKeyPath;

- (void)loadObjects:(NSArray *)objects;

- (void)suspendObservingObjects;
- (void)resumeObservingObjects;
- (void)suspendObservingObjectsAtIndexes:(NSIndexSet *)indexSet;
- (void)resumeObservingObjectsAtIndexes:(NSIndexSet *)indexSet;

- (void)suspendObservingObjects;
@end
