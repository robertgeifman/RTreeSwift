#import "////////////////////////////////////////////////////////////
"
#import "RTreecard.h"

/*-----------------------------------------------------------------------------
| Definitions and global variables.
-----------------------------------------------------------------------------*/
#define METHODS 1

Branch BranchBuf[MAXCARD+1];
NSInteger BranchCount;
RTreeRect CoverSplit;
RectReal CoverSplitArea;

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
static void RTreeGetBranches(Node *n, Branch *b)
{
	register NSInteger i;

	NSCParameterAssert(n);
	NSCParameterAssert(b);

	/* load the branch buffer */
	for (i=0; i<MAXKIDS(n); i++)
	{
		if(!n->branch[i].child)
			NSCParameterAssert(n->branch[i].child); /* n should have every entry full */
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
	CoverSplitArea = RTreeRectSphericalVolume(&CoverSplit);

	RTreeInitNode(n);
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
		p->cover[group] =
			RTreeCombineRect(&BranchBuf[i].rect, &p->cover[group]);
	p->area[group] = RTreeRectSphericalVolume(&p->cover[group]);
	p->count[group]++;
}




/*-----------------------------------------------------------------------------
| Pick two rects from set to be the first elements of the two groups.
| Pick the two that waste the most area if covered by a single rectangle.
-----------------------------------------------------------------------------*/
static void RTreePickSeeds(struct PartitionVars *p)
{
	register NSInteger i, j, seed0, seed1;
	RectReal worst, waste, area[MAXCARD+1];

	for (i=0; i<p->total; i++)
		area[i] = RTreeRectSphericalVolume(&BranchBuf[i].rect);

	worst = -CoverSplitArea - 1;
	for (i=0; i<p->total-1; i++)
	{
		for (j=i+1; j<p->total; j++)
		{
			RTreeRect one_rect = RTreeCombineRect(
						&BranchBuf[i].rect,
						&BranchBuf[j].rect);
			waste = RTreeRectSphericalVolume(&one_rect) -
					area[i] - area[j];
			if (waste > worst)
			{
				worst = waste;
				seed0 = i;
				seed1 = j;
			}
		}
	}
	RTreeClassify(seed0, 0, p);
	RTreeClassify(seed1, 1, p);
}




/*-----------------------------------------------------------------------------
| Copy branches from the buffer into two nodes according to the partition.
-----------------------------------------------------------------------------*/
static void RTreeLoadNodes(Node *n, Node *q,
			struct PartitionVars *p)
{
	register NSInteger i;
	NSCParameterAssert(n);
	NSCParameterAssert(q);
	NSCParameterAssert(p);

	for (i=0; i<p->total; i++)
	{
		NSCParameterAssert(p->partition[i] == 0 || p->partition[i] == 1);
		if (p->partition[i] == 0)
			RTreeAddBranch(&BranchBuf[i], n, NULL);
		else if (p->partition[i] == 1)
			RTreeAddBranch(&BranchBuf[i], q, NULL);
	}
}




/*-----------------------------------------------------------------------------
| Initialize a PartitionVars structure.
-----------------------------------------------------------------------------*/
static void RTreeInitPVars(struct PartitionVars *p, NSInteger maxrects, NSInteger minfill)
{
	register NSInteger i;
	NSCParameterAssert(p);

	p->count[0] = p->count[1] = 0;
	p->cover[0] = p->cover[1] = RTreeNullRect();
	p->area[0] = p->area[1] = (RectReal)0;
	p->total = maxrects;
	p->minfill = minfill;
	for (i=0; i<maxrects; i++)
	{
		p->taken[i] = FALSE;
		p->partition[i] = -1;
	}
}




/*-----------------------------------------------------------------------------
| Print out data for a partition from PartitionVars struct.
-----------------------------------------------------------------------------*/
static void RTreePrintPVars(struct PartitionVars *p)
{
	register NSInteger i;
	NSCParameterAssert(p);

	NSLog(@"\npartition:\n");
	for (i=0; i<p->total; i++)
	{
		NSLog(@"%3d\t", i);
	}
	NSLog(@"\n");
	for (i=0; i<p->total; i++)
	{
		if (p->taken[i])
			NSLog(@"  t\t");
		else
			NSLog(@"\t");
	}
	NSLog(@"\n");
	for (i=0; i<p->total; i++)
	{
		NSLog(@"%3d\t", p->partition[i]);
	}
	NSLog(@"\n");

	NSLog(@"count[0] = %d  area = %f\n", p->count[0], p->area[0]);
	NSLog(@"count[1] = %d  area = %f\n", p->count[1], p->area[1]);
	if (p->area[0] + p->area[1] > 0)
	{
		NSLog(@"total area = %f  effectiveness = %3.2f\n",
			p->area[0] + p->area[1],
			(float)CoverSplitArea / (p->area[0] + p->area[1]));
	}
	NSLog(@"cover[0]:\n");
	RTreePrintRect(&p->cover[0], 0);

	NSLog(@"cover[1]:\n");
	RTreePrintRect(&p->cover[1], 0);
}


/*-----------------------------------------------------------------------------
| Method #0 for choosing a partition:
| As the seeds for the two groups, pick the two rects that would waste the
| most area if covered by a single rectangle, i.e. evidently the worst pair
| to have in the same group.
| Of the remaining, one at a time is chosen to be put in one of the two groups.
| The one chosen is the one with the greatest difference in area expansion
| depending on which group - the rect most strongly attracted to one group
| and repelled from the other.
| If one group gets too full (more would force other group to violate min
| fill requirement) then other group gets the rest.
| These last are the ones that can go in either group most easily.
-----------------------------------------------------------------------------*/
static void RTreeMethodZero(struct PartitionVars *p, NSInteger minfill)
{
	register NSInteger i;
	RectReal biggestDiff;
	register NSInteger group, chosen, betterGroup;
	NSCParameterAssert(p);

	RTreeInitPVars(p, BranchCount, minfill);
	RTreePickSeeds(p);

	while (p->count[0] + p->count[1] < p->total
		&& p->count[0] < p->total - p->minfill
		&& p->count[1] < p->total - p->minfill)
	{
		biggestDiff = (RectReal)-1.;
		for (i=0; i<p->total; i++)
		{
			if (!p->taken[i])
			{
				RTreeRect *r, rect_0, rect_1;
				RectReal growth0, growth1, diff;

				r = &BranchBuf[i].rect;
				rect_0 = RTreeCombineRect(r, &p->cover[0]);
				rect_1 = RTreeCombineRect(r, &p->cover[1]);
				growth0 = RTreeRectSphericalVolume(
						&rect_0)-p->area[0];
				growth1 = RTreeRectSphericalVolume(
						&rect_1)-p->area[1];
				diff = growth1 - growth0;
				if (diff >= 0)
					group = 0;
				else
				{
					group = 1;
					diff = -diff;
				}

				if (diff > biggestDiff)
				{
					biggestDiff = diff;
					chosen = i;
					betterGroup = group;
				}
				else if (diff==biggestDiff &&
					 p->count[group]<p->count[betterGroup])
				{
					chosen = i;
					betterGroup = group;
				}
			}
		}
		RTreeClassify(chosen, betterGroup, p);
	}

	/* if one group too full, put remaining rects in the other */
	if (p->count[0] + p->count[1] < p->total)
	{
		if (p->count[0] >= p->total - p->minfill)
			group = 1;
		else
			group = 0;
		for (i=0; i<p->total; i++)
		{
			if (!p->taken[i])
				RTreeClassify(i, group, p);
		}
	}

	NSCParameterAssert(p->count[0] + p->count[1] == p->total);
	NSCParameterAssert(p->count[0] >= p->minfill && p->count[1] >= p->minfill);
}


/*-----------------------------------------------------------------------------
| Split a node.
| Divides the nodes branches and the extra one between two nodes.
| Old node is one of the new ones, and one really new one is created.
| Tries more than one method for choosing a partition, uses best result.
-----------------------------------------------------------------------------*/
extern void RTreeSplitNode(Node *n, Branch *b, Node **nn)
{
	register struct PartitionVars *p;
	register NSInteger level;

	NSCParameterAssert(n);
	NSCParameterAssert(b);

	/* load all the branches into a buffer, initialize old node */
	level = n->level;
	RTreeGetBranches(n, b);

	/* find partition */
	p = &Partitions[0];
	/* Note: can't use MINFILL(n) below since n was cleared by GetBranches() */
	RTreeMethodZero(p, level>0 ? MinNodeFill : MinLeafFill);

	/*
	 * put branches from buffer into 2 nodes
	 * according to chosen partition
	 */
	*nn = RTreeNewNode();
	(*nn)->level = n->level = level;
	RTreeLoadNodes(n, *nn, p);
	NSCParameterAssert(n->count+(*nn)->count == p->total);
}
