
/*-----------------------------------------------------------------------------
| Definitions and global variables used in linear split code.
-----------------------------------------------------------------------------*/

#define METHODS 1

RTreeBranch BranchBuf[MAXCARD+1];
int BranchCount;
RTreeRect CoverSplit;

/* variables for finding a partition */
struct PartitionVars
{
	int partition[MAXCARD+1];
	int total, minfill;
	int taken[MAXCARD+1];
	int count[2];
	RTreeRect cover[2];
	RectReal area[2];
} Partitions[METHODS];
