#include <stdio.h>
#include <stdlib.h>
#include "assert.h"
#include "include/RTreeIndexImpl.h"
#include "include/RTreeCard.h"

/// Make a new index, empty.  Consists of a single node.
RTreeNode * RTreeNewIndex() {
	RTreeNode *x;
	x = RTreeNewNode();
	x->level = 0; /* leaf */
	return x;
}

/// Search in an index tree or subtree for all data retangles that overlap the argument rectangle.
/// Return the number of qualifying data rects.
int RTreeSearch(RTreeNode *N, RTreeRect *R, RTreeSearchHitCallback callback, void* cbarg) {
	register RTreeNode *n = N;
	register RTreeRect *r = R; /// NOTE: Suspected bug was R sent in as RTreeNode* and cast to RTreeRect* here. Fix not yet tested.
	register int i;
	assert(n);
	assert(n->level >= 0);
	assert(r);

	if (n->level > 0) /* this is an internal node in the tree */
	{
		for (i=0; i<NODECARD; i++)
		{
			if (n->branch[i].child && RTreeOverlap(r, &n->branch[i].rect))
			{
				if(!RTreeSearch(n->branch[i].child, R, callback, cbarg))
					return 0;
			}
		}
	}
	else /* this is a leaf node */
	{
		for (i=0; i<LEAFCARD; i++)
		{
			if (n->branch[i].child && RTreeOverlap(r, &n->branch[i].rect))
			{
				if(callback && !callback((int)n->branch[i].child, &n->branch[i].rect, cbarg))
					return 0; /// callback wants to terminate search early
			}
		}
	}

	return 1;
}

/// Search in an index tree or subtree for all data retangles that contain the argument rectangle.
int RTreeSearchContained(RTreeNode *N, RTreeRect *R, RTreeSearchHitCallback callback, void* cbarg) {
	register RTreeNode *n = N;
	register RTreeRect *r = R; /// NOTE: Suspected bug was R sent in as RTreeNode* and cast to RTreeRect* here. Fix not yet tested.
	register int i;
	assert(n);
	assert(n->level >= 0);
	assert(r);

	if (n->level > 0) /* this is an internal node in the tree */
	{
		for (i=0; i<NODECARD; i++)
		{
			if (n->branch[i].child && RTreeContained(&n->branch[i].rect, r))
			{
				if(!RTreeSearchContained(n->branch[i].child, R, callback, cbarg))
					return 0;
			}
		}
	}
	else /* this is a leaf node */
	{
		for (i=0; i<LEAFCARD; i++)
		{
			if (n->branch[i].child && RTreeContained(&n->branch[i].rect, r))
			{
				if(callback && !callback((int)n->branch[i].child, &n->branch[i].rect, cbarg))
					return 0; /// callback wants to terminate search early
			}
		}
	}

	return 1;
}

/// Search in an index tree or subtree for all data retangles that are contained within the argument rectangle.
/// Return the number of qualifying data rects.
int RTreeSearchContaining(RTreeNode *N, RTreeRect *R, RTreeSearchHitCallback callback, void* cbarg) {
	register RTreeNode *n = N;
	register RTreeRect *r = R; /// NOTE: Suspected bug was R sent in as RTreeNode* and cast to RTreeRect* here. Fix not yet tested.
	register int i;
	assert(n);
	assert(n->level >= 0);
	assert(r);

	if (n->level > 0) /* this is an internal node in the tree */
	{
		for (i=0; i<NODECARD; i++)
		{
			if (n->branch[i].child && RTreeContained(r, &n->branch[i].rect))
			{
				if(!RTreeSearchContaining(n->branch[i].child, R, callback, cbarg))
					return 0;
			}
		}
	}
	else /* this is a leaf node */
	{
		for (i=0; i<LEAFCARD; i++)
		{
			if (n->branch[i].child && RTreeContained(r, &n->branch[i].rect))
			{
				if(callback && !callback((int)n->branch[i].child, &n->branch[i].rect, cbarg))
					return 0; /// callback wants to terminate search early
			}
		}
	}

	return 1;
}

/// Inserts a new data rectangle into the index structure.
/// Recursively descends tree, propagates splits back up.
/// Returns 0 if node was not split.  Old node updated.
/// If node was split, returns 1 and sets the pointer pointed to by new_node to point to the new node.  Old node updated to become one of two.
/// The level argument specifies the number of steps up from the leaf level to insert; e.g. a data rectangle goes in at level = 0.
static int RTreeInsertRect2(RTreeRect *r, void *tid, RTreeNode *n, RTreeNode **new_node, int level) {
/*
	register RTreeRect *r = R;
	register int tid = Tid;
	register RTreeNode *n = N, **new_node = New_node;
	register int level = Level;
*/

	register int i;
	RTreeBranch b;
	RTreeNode *n2;

	assert(r && n && new_node);
	assert(level >= 0 && level <= n->level);

	/// Still above level for insertion, go down tree recursively
	//
	if (n->level > level)
	{
		i = RTreePickBranch(r, n);
		if (!RTreeInsertRect2(r, tid, n->branch[i].child, &n2, level))
		{
			/// child was not split
			//
			n->branch[i].rect = RTreeCombineRect(r, &(n->branch[i].rect));
			return 0;
		}
		else    /// child was split
		{
			n->branch[i].rect = RTreeNodeCover(n->branch[i].child);
			b.child = n2;
			b.rect = RTreeNodeCover(n2);
			return RTreeAddBranch(&b, n, new_node);
		}
	}

	/// Have reached level for insertion. Add rect, split if necessary
	//
	else if (n->level == level)
	{
		b.rect = *r;
		b.child = (RTreeNode *)tid;
		/* child field of leaves contains tid of data record */
		return RTreeAddBranch(&b, n, new_node);
	}
	else
	{
		/* Not supposed to happen */
		assert (FALSE);
		return 0;
	}
}

/// Insert a data rectangle into an index structure.
/// RTreeInsertRect provides for splitting the root;
/// returns 1 if root was split, 0 if it was not.
/// The level argument specifies the number of steps up from the leaf level to insert; e.g. a data rectangle goes in at level = 0.
/// RTreeInsertRect2 does the recursion.
int RTreeInsertRect(RTreeRect *R, void *Tid, RTreeNode **Root, int Level) {
	register RTreeRect *r = R;
	register long tid = (int)Tid;
	register RTreeNode **root = Root;
	register int level = Level;
	register int i;
	register RTreeNode *newroot;
	RTreeNode *newnode;
	RTreeBranch b;
	int result;

	assert(r && root);
	assert(level >= 0 && level <= (*root)->level);
	for (i=0; i<NUMDIMS; i++)
		assert(r->boundary[i] <= r->boundary[NUMDIMS+i]);

	if (RTreeInsertRect2(r, (void *)tid, *root, &newnode, level))  /* root split */
	{
		newroot = RTreeNewNode();  /* grow a new root, & tree taller */
		newroot->level = (*root)->level + 1;
		b.rect = RTreeNodeCover(*root);
		b.child = *root;
		RTreeAddBranch(&b, newroot, NULL);
		b.rect = RTreeNodeCover(newnode);
		b.child = newnode;
		RTreeAddBranch(&b, newroot, NULL);
		*root = newroot;
		result = 1;
	}
	else
		result = 0;

	return result;
}

/// Allocate space for a node in the list used in DeletRect to
/// store Nodes that are too empty.
static RTreeListNode * RTreeNewListNode() {
	return (RTreeListNode *) malloc(sizeof(RTreeListNode));
	//return new RTreeListNode;
}

static void RTreeFreeListNode(RTreeListNode *p) {
	free(p);
	//delete(p);
}

/// Add a node to the reinsertion list.  All its branches will later
/// be reinserted into the index structure.
static void RTreeReInsert(RTreeNode *n, RTreeListNode **ee) {
	register RTreeListNode *l;

	l = RTreeNewListNode();
	l->node = n;
	l->next = *ee;
	*ee = l;
}

/// Delete a rectangle from non-root part of an index structure.
/// Called by RTreeDeleteRect.  Descends tree recursively, merges branches on the way back up.
/// Returns 1 if record not found, 0 if success.
static int RTreeDeleteRect2(RTreeRect *R, void *Tid, RTreeNode *N, RTreeListNode **Ee) {
	register RTreeRect *r = R;
	register void *tid = Tid;
	register RTreeNode *n = N;
	register RTreeListNode **ee = Ee;
	register int i;

	assert(r && n && ee);
	assert(tid >= 0);
	assert(n->level >= 0);

	if (n->level > 0)  /// not a leaf node
	{
	    for (i = 0; i < NODECARD; i++)
	    {
		if (n->branch[i].child && RTreeOverlap(r, &(n->branch[i].rect)))
		{
			if (!RTreeDeleteRect2(r, tid, n->branch[i].child, ee))
			{
				if (n->branch[i].child->count >= MinNodeFill)
					n->branch[i].rect = RTreeNodeCover(n->branch[i].child);
				else
				{
					/// not enough entries in child,
					/// eliminate child node
					//
					RTreeReInsert(n->branch[i].child, ee);
					RTreeDisconnectBranch(n, i);
				}
				return 0;
			}
		}
	    }
	    return 1;
	}
	else  /// a leaf node
	{
		for (i = 0; i < LEAFCARD; i++)
		{
			if (n->branch[i].child &&
			    n->branch[i].child == (RTreeNode *) tid)
			{
				RTreeDisconnectBranch(n, i);
				return 0;
			}
		}
		return 1;
	}
}

/// Delete a data rectangle from an index structure.
/// Pass in a pointer to a RTreeRect, the tid of the record, ptr to ptr to root node.
/// Returns 1 if record not found, 0 if success.
/// RTreeDeleteRect provides for eliminating the root.
int RTreeDeleteRect(RTreeRect *R, void *Tid, RTreeNode**Nn) {
	register RTreeRect *r = R;
	register void *tid = Tid;
	register RTreeNode **nn = Nn;
	register int i;
	register RTreeNode *tmp_nptr = NULL;
	RTreeListNode *reInsertList = NULL;
	register RTreeListNode *e;

	assert(r && nn);
	assert(*nn);
	assert(tid >= 0);

	if (!RTreeDeleteRect2(r, tid, *nn, &reInsertList))
	{
		/* found and deleted a data item */

		/* reinsert any branches from eliminated nodes */
		while (reInsertList)
		{
			tmp_nptr = reInsertList->node;
			for (i = 0; i < MAXKIDS(tmp_nptr); i++)
			{
				if (tmp_nptr->branch[i].child)
				{
					RTreeInsertRect(
						&(tmp_nptr->branch[i].rect),
						(void *)tmp_nptr->branch[i].child,
						nn,
						tmp_nptr->level);
				}
			}
			e = reInsertList;
			reInsertList = reInsertList->next;
			RTreeFreeNode(e->node);
			RTreeFreeListNode(e);
		}
		
		/* check for redundant root (not leaf, 1 child) and eliminate
		*/
		if ((*nn)->count == 1 && (*nn)->level > 0)
		{
			for (i = 0; i < NODECARD; i++)
			{
				tmp_nptr = (*nn)->branch[i].child;
				if(tmp_nptr)
					break;
			}
			assert(tmp_nptr);
			RTreeFreeNode(*nn);
			*nn = tmp_nptr;
		}
		return 0;
	}
	else
	{
		return 1;
	}
}

void RTreeRecursivelyFreeBranch(RTreeBranch *b) {
	RTreeRecursivelyFreeNode(b->child);
}

void RTreeRecursivelyFreeNode(RTreeNode *n) {
	assert(n != NULL);
	if(n->level)
	{
		for(int i=0; i<n->count; i++)
			RTreeRecursivelyFreeBranch(&n->branch[i]);
	}

	RTreeFreeNode(n);
}
