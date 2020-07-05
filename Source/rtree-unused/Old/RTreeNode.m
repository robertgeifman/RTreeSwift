#import "RTreeIndexImpl.h"
#import "RTreecard.h"

////////////////////////////////////////////////////////////
// Initialize one branch cell in a node.
static void RTreeInitBranch(Branch *b)
{
	RTreeInitRect(&(b->rect));
	b->child = NULL;
}

////////////////////////////////////////////////////////////
// Initialize a Node structure.
void RTreeInitNode(Node *N)
{
	register Node *n = N;
	register NSInteger i;
	n->count = 0;
	n->level = -1;
	for (i = 0; i < MAXCARD; i++)
		RTreeInitBranch(&(n->branch[i]));
}


// Make a new node and initialize to have all branch cells empty.
Node * RTreeNewNode()
{
	register Node *n = (Node*)malloc(sizeof(Node));
	NSCParameterAssert(n);
	RTreeInitNode(n);
	return n;
}


void RTreeFreeNode(Node *p)
{
	NSCParameterAssert(p);
	//delete p;
	free(p);
}

static void RTreePrintBranch(Branch *b, NSInteger depth)
{
	RTreePrintRect(&(b->rect), depth);
	RTreePrintNode(b->child, depth);
}


extern void RTreeTabIn(NSInteger depth)
{
	NSInteger i;
	for(i=0; i<depth; i++)
		putchar('\t');
}

// Print out the data in a node.
void RTreePrintNode(Node *n, NSInteger depth)
{
	NSInteger i;
	NSCParameterAssert(n);

	RTreeTabIn(depth);
	NSLog(@"node");
	if (n->level == 0)
		NSLog(@" LEAF");
	else if (n->level > 0)
		NSLog(@" NONLEAF");
	else
		NSLog(@" TYPE=?");
	NSLog(@"  level=%d  count=%d  address=%o\n", n->level, n->count, n);

	for (i=0; i<n->count; i++)
	{
		if(n->level == 0) {
			// RTreeTabIn(depth);
			// NSLog(@"\t%d: data = %d\n", i, n->branch[i].child);
		}
		else {
			RTreeTabIn(depth);
			NSLog(@"branch %d\n", i);
			RTreePrintBranch(&n->branch[i], depth+1);
		}
	}
}



// Find the smallest rectangle that includes all rectangles in
// branches of a node.
//
RTreeRect RTreeNodeCover(Node *N)
{
	register Node *n = N;
	register NSInteger i, first_time=1;
	RTreeRect r;
	NSCParameterAssert(n);

	RTreeInitRect(&r);
	for (i = 0; i < MAXKIDS(n); i++)
		if (n->branch[i].child)
		{
			if (first_time)
			{
				r = n->branch[i].rect;
				first_time = 0;
			}
			else
				r = RTreeCombineRect(&r, &(n->branch[i].rect));
		}
	return r;
}



// Pick a branch.  Pick the one that will need the smallest increase
// in area to accomodate the new rectangle.  This will result in the
// least total area for the covering rectangles in the current node.
// In case of a tie, pick the one which was smaller before, to get
// the best resolution when searching.
//
NSInteger RTreePickBranch(RTreeRect *R, Node *N)
{
	register RTreeRect *r = R;
	register Node *n = N;
	register RTreeRect *rr;
	register NSInteger i, first_time=1;
	RectReal increase, bestIncr=(RectReal)-1, area, bestArea;
	NSInteger best;
	RTreeRect tmp_rect;
	NSCParameterAssert(r && n);

	for (i=0; i<MAXKIDS(n); i++)
	{
		if (n->branch[i].child)
		{
			rr = &n->branch[i].rect;
			area = RTreeRectSphericalVolume(rr);
			tmp_rect = RTreeCombineRect(r, rr);
			increase = RTreeRectSphericalVolume(&tmp_rect) - area;
			if (increase < bestIncr || first_time)
			{
				best = i;
				bestArea = area;
				bestIncr = increase;
				first_time = 0;
			}
			else if (increase == bestIncr && area < bestArea)
			{
				best = i;
				bestArea = area;
				bestIncr = increase;
			}
		}
	}
	return best;
}



// Add a branch to a node.  Split the node if necessary.
// Returns 0 if node not split.  Old node updated.
// Returns 1 if node split, sets *new_node to address of new node.
// Old node updated, becomes one of two.
//
NSInteger RTreeAddBranch(Branch *B, Node *N, Node **New_node)
{
	register Branch *b = B;
	register Node *n = N;
	register Node **new_node = New_node;
	register NSInteger i;

	NSCParameterAssert(b);
	NSCParameterAssert(n);

	if (n->count < MAXKIDS(n))  /* split won't be necessary */
	{
		for (i = 0; i < MAXKIDS(n); i++)  /* find empty branch */
		{
			if (n->branch[i].child == NULL)
			{
				n->branch[i] = *b;
				n->count++;
				break;
			}
		}
		return 0;
	}
	else
	{
		NSCParameterAssert(new_node);
		RTreeSplitNode(n, b, new_node);
		return 1;
	}
}

// Disconnect a dependent node.
void RTreeDisconnectBranch(Node *n, NSInteger i)
{
	NSCParameterAssert(n && i>=0 && i<MAXKIDS(n));
	NSCParameterAssert(n->branch[i].child);

	RTreeInitBranch(&(n->branch[i]));
	n->count--;
}


static void RTreeResursivelyFreeBranch(Branch *b)
{
	RTreeResursivelyFreeNode(b->child);
}

void RTreeResursivelyFreeNode(Node *n)
{
	NSCParameterAssert(n);
	if(n->level)
	{
		for(NSInteger i=0; i<n->count; i++)
			RTreeResursivelyFreeBranch(&n->branch[i]);
	}

	RTreeFreeNode(n);
}
