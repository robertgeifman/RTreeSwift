#ifndef _INDEX_
#define _INDEX_

/* PGSIZE is normally the natural page size of the machine */
#define PGSIZE	512
#define NUMDIMS	2	/* number of dimensions */
#define NDEBUG

typedef float RectReal;
// Global definitions.

#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

#define NUMSIDES 2*NUMDIMS

typedef struct RTreeRect
{
	RectReal boundary[NUMSIDES]; /* xmin,ymin,...,xmax,ymax,... */
} RTreeRect;

struct _RTreeNode;
typedef struct _RTreeNode RTreeNode;

typedef struct _RTreeBranch
{
	RTreeRect rect;
	RTreeNode *child;
} RTreeBranch;

/* max branching factor of a node */
#define MAXCARD (int)((PGSIZE-(2*sizeof(int))) / sizeof(RTreeBranch))

struct _RTreeNode
{
	int count;
	int level; /* 0 is leaf, others positive */
	RTreeBranch branch[MAXCARD];
};

typedef struct _RTreeListNode
{
	struct _RTreeListNode *next;
	RTreeNode *node;
} RTreeListNode;

typedef struct RTreeSearchContext
{
	RTreeNode *node;
	RTreeRect *rect;
	int i;
} RTreeSearchContext;

/*
 * If passed to a tree search, this callback function will be called
 * with the ID of each data rect that overlaps the search rect
 * plus whatever user specific pointer was passed to the search.
 * It can terminate the search early by returning 0 in which case
 * the search will return the number of hits found up to that point.
 */
typedef int (*RTreeSearchHitCallback)(void *, RTreeRect *, void *);
typedef int (*RTreeSplitNodeCallback)(RTreeNode *, RTreeBranch *, RTreeNode **);

extern int RTreeSearch(RTreeNode*, RTreeRect*, void* cbarg, RTreeSearchHitCallback callback);
extern int RTreeSearchNonRecursive(RTreeNode*, RTreeRect*, RTreeSearchContext* context);
extern int RTreeSearchContained(RTreeNode *N, RTreeRect *R, void* cbarg, RTreeSearchHitCallback callback);
extern int RTreeSearchContaining(RTreeNode *N, RTreeRect *R, void* cbarg, RTreeSearchHitCallback callback);

extern int RTreeInsertRect(RTreeRect*, void *, RTreeNode**, int depth);
extern int RTreeDeleteRect(RTreeRect*, void *, RTreeNode**);
extern RTreeNode * RTreeNewIndex();
extern RTreeNode * RTreeNewNode();
extern void RTreeInitNode(RTreeNode*);
extern void RTreeFreeNode(RTreeNode *);
extern RTreeRect RTreeNodeCover(RTreeNode *);
extern void RTreeInitRect(RTreeRect*);
extern RTreeRect RTreeNullRect();
extern RectReal RTreeRectArea(RTreeRect*);
extern RectReal RTreeRectSphericalVolume(RTreeRect *R);
extern RectReal RTreeRectVolume(RTreeRect *R);
extern RTreeRect RTreeCombineRect(RTreeRect*, RTreeRect*);
extern int RTreeOverlap(RTreeRect*, RTreeRect*);
extern int RTreeContained(struct RTreeRect *R, struct RTreeRect *S);
extern int RTreeAddBranch(RTreeBranch *, RTreeNode *, RTreeNode **);
extern int RTreePickBranch(RTreeRect *, RTreeNode *);
extern void RTreeDisconnectBranch(RTreeNode *, int);

// MARK: - RTreeSplitNode
extern void RTreeSplitNodeQuadratic(RTreeNode *n, RTreeBranch *b, RTreeNode **nn);
extern void RTreeSplitNodeLinear(RTreeNode *n, RTreeBranch *b, RTreeNode **nn);
#define RTreeSplitNode	RTreeSplitNodeQuadratic

extern int RTreeSetNodeMax(int);
extern int RTreeSetLeafMax(int);
extern int RTreeGetNodeMax();
extern int RTreeGetLeafMax();

extern void RTreeRecursivelyFreeBranch(RTreeBranch *b);
extern void RTreeRecursivelyFreeNode(RTreeNode *n);

extern int NODECARD;
extern int LEAFCARD;

/* balance criteria for node splitting */
/* NOTE: can be changed if needed. */
#define MinNodeFill (NODECARD / 2)
#define MinLeafFill (LEAFCARD / 2)

#define MAXKIDS(n) ((n)->level > 0 ? NODECARD : LEAFCARD)
#define MINFILL(n) ((n)->level > 0 ? MinNodeFill : MinLeafFill)
#endif /* _INDEX_ */
