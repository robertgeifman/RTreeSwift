
#include <stdio.h>
#include <stdlib.h>
#include "assert.h"
#include "RTreeIndexImpl.h"
#include "RTreeCard.h"


// Initialize one branch cell in a node.
//
static void RTreeInitBranch(RTreeBranch *b)
{
	RTreeInitRect(&(b->rect));
	b->child = NULL;
}



// Initialize a RTreeNode structure.
//
void RTreeInitNode(RTreeNode *N)
{
	register RTreeNode *n = N;
	register int i;
	n->count = 0;
	n->level = -1;
	for (i = 0; i < MAXCARD; i++)
		RTreeInitBranch(&(n->branch[i]));
}



// Make a new node and initialize to have all branch cells empty.
//
RTreeNode * RTreeNewNode()
{
	register RTreeNode *n;

	//n = new RTreeNode;
	n = (RTreeNode*)malloc(sizeof(RTreeNode));
	assert(n);
	RTreeInitNode(n);
	return n;
}


void RTreeFreeNode(RTreeNode *p)
{
	assert(p);
	//delete p;
	free(p);
}



static void RTreePrintBranch(RTreeBranch *b, int depth)
{
	RTreePrintRect(&(b->rect), depth);
	RTreePrintNode(b->child, depth);
}


extern void RTreeTabIn(int depth)
{
	int i;
	for(i=0; i<depth; i++)
		putchar('\t');
}


// Print out the data in a node.
//
void RTreePrintNode(RTreeNode *n, int depth)
{
	int i;
	assert(n);

	RTreeTabIn(depth);
	printf("node");
	if (n->level == 0)
		printf(" LEAF");
	else if (n->level > 0)
		printf(" NONLEAF");
	else
		printf(" TYPE=?");
	printf("  level=%d  count=%d  address=%o\n", n->level, n->count, n);

	for (i=0; i<n->count; i++)
	{
		if(n->level == 0) {
			// RTreeTabIn(depth);
			// printf("\t%d: data = %d\n", i, n->branch[i].child);
		}
		else {
			RTreeTabIn(depth);
			printf("branch %d\n", i);
			RTreePrintBranch(&n->branch[i], depth+1);
		}
	}
}



// Find the smallest rectangle that includes all rectangles in
// branches of a node.
//
RTreeRect RTreeNodeCover(RTreeNode *N)
{
	register RTreeNode *n = N;
	register int i, first_time=1;
	RTreeRect r;
	assert(n);

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
int RTreePickBranch(RTreeRect *R, RTreeNode *N)
{
	register RTreeRect *r = R;
	register RTreeNode *n = N;
	register RTreeRect *rr;
	register int i, first_time=1;
	RectReal increase, bestIncr=(RectReal)-1, area, bestArea = 0.0;
	int best = 0;
	RTreeRect tmp_rect;
	assert(r && n);

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
int RTreeAddBranch(RTreeBranch *B, RTreeNode *N, RTreeNode **New_node)
{
	register RTreeBranch *b = B;
	register RTreeNode *n = N;
	register RTreeNode **new_node = New_node;
	register int i;

	assert(b);
	assert(n);

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
		assert(new_node);
		RTreeSplitNode(n, b, new_node);
		return 1;
	}
}



// Disconnect a dependent node.
//
void RTreeDisconnectBranch(RTreeNode *n, int i)
{
	assert(n && i>=0 && i<MAXKIDS(n));
	assert(n->branch[i].child);

	RTreeInitBranch(&(n->branch[i]));
	n->count--;
}
