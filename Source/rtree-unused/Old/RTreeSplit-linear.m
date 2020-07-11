#include <stdio.h>
#import "RTreeIndexImpl.h"
#import "RTreecard.h"

/*-----------------------------------------------------------------------------
| Definitions and global variables used in linear split code.
-----------------------------------------------------------------------------*/

#define METHODS 1
// namespace RTree {

Branch BranchBuf[MAXCARD+1];
NSInteger BranchCount;
RTreeRect CoverSplit;

/* variables for finding a partition */
struct PartitionVars
{
	NSInteger partition[MAXCARD+1];
	NSInteger total, minfill;
	NSInteger taken[MAXCARD+1];
	NSInteger count[2];
	RTreeRect cover[2];
	RectReal area[2];
} Partitions[METHODS];

/*-----------------------------------------------------------------------------
| Load branch buffer with branches from full node plus the extra branch.
-----------------------------------------------------------------------------*/
static void RTreeGetBranches(Node *N, Branch *B)
{
	register Node *n = N;
	register Branch *b = B;
	register NSInteger i;

	NSCParameterAssert(n);
	NSCParameterAssert(b);

	/* load the branch buffer */
	for (i=0; i<MAXKIDS(n); i++)
	{
		NSCParameterAssert(n->branch[i].child);  /* every entry should be full */
		BranchBuf[i] = n->branch[i];
	}
	BranchBuf[MAXKIDS(n)] = *b;
	BranchCount = MAXKIDS(n) + 1;

	/* calculate rect containing all in the set */
	CoverSplit = BranchBuf[0].rect;
	for (i=1; i<MAXKIDS(n)+1; i++)
	{
		CoverSplit = RTreeCombineRect(&CoverSplit, &BranchBuf[i].rect);
	}

	RTreeInitNode(n);
}



/*-----------------------------------------------------------------------------
| Initialize a PartitionVars structure.
-----------------------------------------------------------------------------*/
static void RTreeInitPVars(struct PartitionVars *P, NSInteger maxrects, NSInteger minfill)
{
	register struct PartitionVars *p = P;
	register NSInteger i;
	NSCParameterAssert(p);

	p->count[0] = p->count[1] = 0;
	p->total = maxrects;
	p->minfill = minfill;
	for (i=0; i<maxrects; i++)
	{
		p->taken[i] = FALSE;
		p->partition[i] = -1;
	}
}



/*-----------------------------------------------------------------------------
| Put a branch in one of the groups.
-----------------------------------------------------------------------------*/
static void RTreeClassify(NSInteger i, NSInteger group, struct PartitionVars *p)
{
	NSCParameterAssert(p);
	NSCParameterAssert(!p->taken[i]);

	p->partition[i] = group;
	p->taken[i] = TRUE;

	if (p->count[group] == 0)
		p->cover[group] = BranchBuf[i].rect;
	else
		p->cover[group] = RTreeCombineRect(&BranchBuf[i].rect,
					&p->cover[group]);
	p->area[group] = RTreeRectSphericalVolume(&p->cover[group]);
	p->count[group]++;
}



/*-----------------------------------------------------------------------------
| Pick two rects from set to be the first elements of the two groups.
| Pick the two that are separated most along any dimension, or overlap least.
| Distance for separation or overlap is measured modulo the width of the
| space covered by the entire set along that dimension.
-----------------------------------------------------------------------------*/
static void RTreePickSeeds(struct PartitionVars *P)
{
	register struct PartitionVars *p = P;
	register NSInteger i, dim, high;
	register RTreeRect *r, *rlow, *rhigh;
	register float w, separation, bestSep;
	RectReal width[NUMDIMS];
	NSInteger leastUpper[NUMDIMS], greatestLower[NUMDIMS];
	NSInteger seed0, seed1;
	NSCParameterAssert(p);
	
	for (dim=0; dim<NUMDIMS; dim++)
	{
		high = dim + NUMDIMS;

		/* find the rectangles farthest out in each direction
		 * along this dimens */
		greatestLower[dim] = leastUpper[dim] = 0;
		for (i=1; i<NODECARD+1; i++)
		{
			r = &BranchBuf[i].rect;
			if (r->boundary[dim] >
				BranchBuf[greatestLower[dim]].rect.boundary[dim])
			{
				greatestLower[dim] = i;
			}
			if (r->boundary[high] <
				BranchBuf[leastUpper[dim]].rect.boundary[high])
			{
				leastUpper[dim] = i;
			}
		}

		/* find width of the whole collection along this dimension */
		width[dim] = CoverSplit.boundary[high] -
				 CoverSplit.boundary[dim];
	}

	/* pick the best separation dimension and the two seed rects */
	for (dim=0; dim<NUMDIMS; dim++)
	{
		high = dim + NUMDIMS;

		/* divisor for normalizing by width */
		NSCParameterAssert(width[dim] >= 0);
		if (width[dim] == 0)
			w = (RectReal)1;
		else
			w = width[dim];

		rlow = &BranchBuf[leastUpper[dim]].rect;
		rhigh = &BranchBuf[greatestLower[dim]].rect;
		if (dim == 0)
		{
			seed0 = leastUpper[0];
			seed1 = greatestLower[0];
			separation = bestSep =
				(rhigh->boundary[0] -
				 rlow->boundary[NUMDIMS]) / w;
		}
		else
		{
			separation =
				(rhigh->boundary[dim] -
				rlow->boundary[dim+NUMDIMS]) / w;
			if (separation > bestSep)
			{
				seed0 = leastUpper[dim];
				seed1 = greatestLower[dim];
				bestSep = separation;
			}
		}
	}

	if (seed0 != seed1)
	{
		RTreeClassify(seed0, 0, p);
		RTreeClassify(seed1, 1, p);
	}
}



/*-----------------------------------------------------------------------------
| Put each rect that is not already in a group into a group.
| Process one rect at a time, using the following hierarchy of criteria.
| In case of a tie, go to the next test.
| 1) If one group already has the max number of elements that will allow
| the minimum fill for the other group, put r in the other.
| 2) Put r in the group whose cover will expand less.  This automatically
| takes care of the case where one group cover contains r.
| 3) Put r in the group whose cover will be smaller.  This takes care of the
| case where r is contained in both covers.
| 4) Put r in the group with fewer elements.
| 5) Put in group 1 (arbitrary).
|
| Also update the covers for both groups.
-----------------------------------------------------------------------------*/
static void RTreePigeonhole(struct PartitionVars *P)
{
	register struct PartitionVars *p = P;
	RTreeRect newCover[2];
	register NSInteger i, group;
	RectReal newArea[2], increase[2];

	for (i=0; i<NODECARD+1; i++)
	{
		if (!p->taken[i])
		{
			/* if one group too full, put rect in the other */
			if (p->count[0] >= p->total - p->minfill)
			{
				RTreeClassify(i, 1, p);
				continue;
			}
			else if (p->count[1] >= p->total - p->minfill)
			{
				RTreeClassify(i, 0, p);
				continue;
			}

			/* find areas of the two groups' old and new covers */
			for (group=0; group<2; group++)
			{
				if (p->count[group]>0)
					newCover[group] = RTreeCombineRect(
						&BranchBuf[i].rect,
						&p->cover[group]);
				else
					newCover[group] = BranchBuf[i].rect;
				newArea[group] = RTreeRectSphericalVolume(
							&newCover[group]);
				increase[group] = newArea[group]-p->area[group];
			}

			/* put rect in group whose cover will expand less */
			if (increase[0] < increase[1])
				RTreeClassify(i, 0, p);
			else if (increase[1] < increase[0])
				RTreeClassify(i, 1, p);

			/* put rect in group that will have a smaller cover */
			else if (p->area[0] < p->area[1])
				RTreeClassify(i, 0, p);
			else if (p->area[1] < p->area[0])
				RTreeClassify(i, 1, p);

			/* put rect in group with fewer elements */
			else if (p->count[0] < p->count[1])
				RTreeClassify(i, 0, p);
			else
				RTreeClassify(i, 1, p);
		}
	}
	NSCParameterAssert(p->count[0] + p->count[1] == NODECARD + 1);
}



/*-----------------------------------------------------------------------------
| Method 0 for finding a partition:
| First find two seeds, one for each group, well separated.
| Then put other rects in whichever group will be smallest after addition.
-----------------------------------------------------------------------------*/
static void RTreeMethodZero(struct PartitionVars *p, NSInteger minfill)
{
	RTreeInitPVars(p, BranchCount, minfill);
	RTreePickSeeds(p);
	RTreePigeonhole(p);
}




/*-----------------------------------------------------------------------------
| Copy branches from the buffer into two nodes according to the partition.
-----------------------------------------------------------------------------*/
static void RTreeLoadNodes(Node *N, Node *Q,
			struct PartitionVars *P)
{
	register Node *n = N, *q = Q;
	register struct PartitionVars *p = P;
	register NSInteger i;
	NSCParameterAssert(n);
	NSCParameterAssert(q);
	NSCParameterAssert(p);

	for (i=0; i<NODECARD+1; i++)
	{
		if (p->partition[i] == 0)
			RTreeAddBranch(&BranchBuf[i], n, NULL);
		else if (p->partition[i] == 1)
			RTreeAddBranch(&BranchBuf[i], q, NULL);
		else
			NSCParameterAssert(FALSE);
	}
}



/*-----------------------------------------------------------------------------
| Split a node.
| Divides the nodes branches and the extra one between two nodes.
| Old node is one of the new ones, and one really new one is created.
-----------------------------------------------------------------------------*/
void RTreeSplitNode_linear(Node *n, Branch *b, Node **nn)
{
	register struct PartitionVars *p;
	register NSInteger level;
	RectReal area;

	NSCParameterAssert(n);
	NSCParameterAssert(b);

	/* load all the branches into a buffer, initialize old node */
	level = n->level;
	RTreeGetBranches(n, b);

	/* find partition */
	p = &Partitions[0];

	/* Note: can't use MINFILL(n) below since n was cleared by GetBranches() */
	RTreeMethodZero(p, level>0 ? MinNodeFill: MinLeafFill);

	/* record how good the split was for statistics */
	area = p->area[0] + p->area[1];

	/* put branches from buffer in 2 nodes according to chosen partition */
	*nn = RTreeNewNode();
	(*nn)->level = n->level = level;
	RTreeLoadNodes(n, *nn, p);
	NSCParameterAssert(n->count + (*nn)->count == NODECARD+1);
}



/*-----------------------------------------------------------------------------
| Print out data for a partition from PartitionVars struct.
-----------------------------------------------------------------------------*/
static void RTreePrintPVars(struct PartitionVars *p)
{
	NSInteger i;
	NSCParameterAssert(p);

	NSLog(@"\npartition:\n");
	for (i=0; i<NODECARD+1; i++)
	{
		NSLog(@"%3d\t", i);
	}
	NSLog(@"\n");
	for (i=0; i<NODECARD+1; i++)
	{
		if (p->taken[i])
			NSLog(@"  t\t");
		else
			NSLog(@"\t");
	}
	NSLog(@"\n");
	for (i=0; i<NODECARD+1; i++)
	{
		NSLog(@"%3d\t", p->partition[i]);
	}
	NSLog(@"\n");

	NSLog(@"count[0] = %d  area = %f\n", p->count[0], p->area[0]);
	NSLog(@"count[1] = %d  area = %f\n", p->count[1], p->area[1]);
	NSLog(@"total area = %f  effectiveness = %3.2f\n",
		p->area[0] + p->area[1],
		RTreeRectSphericalVolume(&CoverSplit)/(p->area[0]+p->area[1]));

	NSLog(@"cover[0]:\n");
	RTreePrintRect(&p->cover[0], 0);

	NSLog(@"cover[1]:\n");
	RTreePrintRect(&p->cover[1], 0);
}

// } // namespace RTree
