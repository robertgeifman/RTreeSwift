#import "NPUIKit-Compatibility.h"

/* PGSIZE is normally the natural page size of the machine */
#define PGSIZE	512
#define NUMDIMS	2	/* number of dimensions */
#define NDEBUG

////////////////////////////////////////////////////////////
typedef float RectReal;
//| Global definitions.

#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

#define NUMSIDES 2*NUMDIMS

////////////////////////////////////////////////////////////
typedef struct _RTreeRect
{
	RectReal boundary[NUMSIDES]; /* xmin,ymin,...,xmax,ymax,... */
} RTreeRect;

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

static inline NSRect RTreeRectToNSRect(RTreeRect r)
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
struct _Node;

typedef struct _Branch
{
	RTreeRect rect;
	struct _Node *child;
} Branch;

/* max branching factor of a node */
#define MAXCARD (int)((PGSIZE-(2*sizeof(int))) / sizeof(Branch))

typedef struct _Node
{
	NSInteger count;
	NSInteger level; /* 0 is leaf, others positive */
	Branch branch[MAXCARD];
} Node;

typedef struct _ListNode
{
	struct _ListNode *next;
	Node *node;
} ListNode;

////////////////////////////////////////////////////////////
// If passed to a tree search, this callback function will be called with the ID of each data rect that overlaps the search rect plus whatever user specific pointer was passed to the search. It can terminate the search early by returning 0 in which case the search will return the number of hits found up to that point.
typedef NSInteger (*SearchHitCallback)(void *context, RTreeRect *R, void* userInfo);

////////////////////////////////////////////////////////////
extern NSInteger RTreeSearch(Node* pRootNode, RTreeRect* pRect, SearchHitCallback callback, void* userInfo);
extern NSInteger RTreeSearchContaining(Node *N, RTreeRect *R, SearchHitCallback shcb, void* cbarg);
extern NSInteger RTreeSearchContained(Node *N, RTreeRect *R, SearchHitCallback shcb, void* cbarg);

////////////////////////////////////////////////////////////
extern NSInteger RTreeInsertRect(RTreeRect* pRect, void *context, Node **ppRootNode, NSInteger depth);
extern NSInteger RTreeDeleteRect(RTreeRect* pRect, void *context, Node **ppRootNode);

////////////////////////////////////////////////////////////
extern Node * RTreeNewIndex();
extern Node * RTreeNewNode();

////////////////////////////////////////////////////////////
extern void RTreeInitNode(Node*);
extern void RTreeFreeNode(Node *);
extern void RTreeResursivelyFreeNode(Node *n);

////////////////////////////////////////////////////////////
extern void RTreePrintNode(Node *, NSInteger);
extern void RTreeTabIn(NSInteger);

////////////////////////////////////////////////////////////
extern RTreeRect RTreeNodeCover(Node *);
extern void RTreeInitRect(RTreeRect*);
extern RTreeRect RTreeNullRect();
extern RectReal RTreeRectArea(RTreeRect*);
extern RectReal RTreeRectSphericalVolume(RTreeRect *R);
extern RectReal RTreeRectVolume(RTreeRect *R);
extern RTreeRect RTreeCombineRect(RTreeRect*, RTreeRect*);

extern NSInteger RTreeContained(RTreeRect *R, RTreeRect *S);
extern NSInteger RTreeOverlap(RTreeRect*, RTreeRect*);
extern void RTreePrintRect(RTreeRect*, NSInteger);
extern NSInteger RTreeAddBranch(Branch *, Node *, Node **);
extern NSInteger RTreePickBranch(RTreeRect *, Node *);
extern void RTreeDisconnectBranch(Node *, NSInteger);
extern void RTreeSplitNode(Node*, Branch*, Node**);
extern void RTreeSplitNode_linear(Node*, Branch*, Node**);

extern NSInteger RTreeSetNodeMax(NSInteger);
extern NSInteger RTreeSetLeafMax(NSInteger);
extern NSInteger RTreeGetNodeMax();
extern NSInteger RTreeGetLeafMax();
