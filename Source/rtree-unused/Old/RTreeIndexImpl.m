////////////////////////////////////////////////////////////
#import "RTreeIndexImpl.h"
#import "RTreeCard.h"

////////////////////////////////////////////////////////////
// Make a new index, empty.  Consists of a single node.
Node * RTreeNewIndex()
{
	Node *x = RTreeNewNode();
	x->level = 0; /* leaf */
	return x;
}

////////////////////////////////////////////////////////////
extern NSInteger _RTreeInsertRect(RTreeRect*, void *context, Node**, NSInteger depth);
extern NSInteger _RTreeDeleteRect(RTreeRect*, void *context, Node**);

////////////////////////////////////////////////////////////
NSInteger RTreeInsertRect(RTreeRect* pRect, void *context, Node **ppRootNode, NSInteger depth)
{
	Node *root = *ppRootNode;
	NSInteger result = _RTreeInsertRect(pRect, context, &root, depth);
	*ppRootNode = root;
	return result;
}

NSInteger RTreeDeleteRect(RTreeRect*pRect, void *context, Node **ppRootNode)
{
	Node *root = *ppRootNode;
	NSInteger result = _RTreeDeleteRect(pRect, context, &root);
	*ppRootNode = root;
	return result;
}

////////////////////////////////////////////////////////////
// Allocate space for a node in the list used in DeletRect to
// store Nodes that are too empty.
static ListNode * RTreeNewListNode()
{
	return (ListNode *)malloc(sizeof(ListNode));
}

static void RTreeFreeListNode(ListNode *p)
{
	free(p);
}

////////////////////////////////////////////////////////////
// Search in an index tree or subtree for all data retangles that
// overlap the argument rectangle.
// Return the number of qualifying data rects.
NSInteger RTreeSearch(Node *N, RTreeRect *R, SearchHitCallback shcb, void* cbarg)
{
	register Node *n = N;
	register RTreeRect *r = R; // NOTE: Suspected bug was R sent in as Node* and cast to RTreeRect* here. Fix not yet tested.
	register NSInteger hitCount = 0;
	register NSInteger i;

	NSCParameterAssert(n);
	NSCParameterAssert(n->level >= 0);
	NSCParameterAssert(r);

	if (n->level > 0) /* this is an internal node in the tree */
	{
		for (i=0; i<NODECARD; i++)
		{
			if (n->branch[i].child && RTreeOverlap(r, &n->branch[i].rect))
				hitCount += RTreeSearch(n->branch[i].child, R, shcb, cbarg);
		}
	}
	else /* this is a leaf node */
	{
		for (i=0; i<LEAFCARD; i++)
		{
			if (n->branch[i].child && RTreeOverlap(r, &n->branch[i].rect))
			{
				hitCount++;
				if(shcb) // call the user-provided callback
					if( ! shcb(n->branch[i].child, &n->branch[i].rect, cbarg))
						return hitCount; // callback wants to terminate search early
			}
		}
	}
	return hitCount;
}

////////////////////////////////////////////////////////////
// Search in an index tree or subtree for all data retangles that
// contain the argument rectangle.
// Return the number of qualifying data rects.
NSInteger RTreeSearchContained(Node *N, RTreeRect *R, SearchHitCallback shcb, void* cbarg)
{
	register Node *n = N;
	register RTreeRect *r = R; // NOTE: Suspected bug was R sent in as Node* and cast to RTreeRect* here. Fix not yet tested.
	register NSInteger hitCount = 0;
	register NSInteger i;

	NSCParameterAssert(n);
	NSCParameterAssert(n->level >= 0);
	NSCParameterAssert(r);

	if (n->level > 0) /* this is an internal node in the tree */
	{
		for (i=0; i<NODECARD; i++)
		{
			if (n->branch[i].child && RTreeContained(&n->branch[i].rect, r))
				hitCount += RTreeSearch(n->branch[i].child, R, shcb, cbarg);
		}
	}
	else /* this is a leaf node */
	{
		for (i=0; i<LEAFCARD; i++)
		{
			if (n->branch[i].child && RTreeContained(&n->branch[i].rect, r))
			{
				hitCount++;
				if(shcb) // call the user-provided callback
					if( ! shcb(n->branch[i].child, &n->branch[i].rect, cbarg))
						return hitCount; // callback wants to terminate search early
			}
		}
	}
	return hitCount;
}

////////////////////////////////////////////////////////////
// Search in an index tree or subtree for all data retangles that
// are contained within the argument rectangle.
// Return the number of qualifying data rects.
NSInteger RTreeSearchContaining(Node *N, RTreeRect *R, SearchHitCallback shcb, void* cbarg)
{
	register Node *n = N;
	register RTreeRect *r = R; // NOTE: Suspected bug was R sent in as Node* and cast to RTreeRect* here. Fix not yet tested.
	register NSInteger hitCount = 0;
	register NSInteger i;

	NSCParameterAssert(n);
	NSCParameterAssert(n->level >= 0);
	NSCParameterAssert(r);

	if (n->level > 0) /* this is an internal node in the tree */
	{
		for (i=0; i<NODECARD; i++)
		{
			if (n->branch[i].child && RTreeContained(r,&n->branch[i].rect))
				hitCount += RTreeSearch(n->branch[i].child, R, shcb, cbarg);
		}
	}
	else /* this is a leaf node */
	{
		for (i=0; i<LEAFCARD; i++)
		{
			if (n->branch[i].child && RTreeContained(r,&n->branch[i].rect))
			{
				hitCount++;
				if(shcb) // call the user-provided callback
					if( ! shcb(n->branch[i].child, &n->branch[i].rect, cbarg))
						return hitCount; // callback wants to terminate search early
			}
		}
	}
	return hitCount;
}

////////////////////////////////////////////////////////////
// Inserts a new data rectangle into the index structure.
// Recursively descends tree, propagates splits back up.
// Returns 0 if node was not split.  Old node updated.
// If node was split, returns 1 and sets the pointer pointed to by
// new_node to point to the new node.  Old node updated to become one of two.
// The level argument specifies the number of steps up from the leaf
// level to insert; e.g. a data rectangle goes in at level = 0.
static NSInteger RTreeInsertRect2(RTreeRect *r,
		void *context, Node *n, Node **new_node, NSInteger level)
{
/*
	register RTreeRect *r = R;
	register NSInteger tid = Tid;
	register Node *n = N, **new_node = New_node;
	register NSInteger level = Level;
*/

	register NSInteger i;
	Branch b;
	Node *n2;

	NSCParameterAssert(r && n && new_node);
	NSCParameterAssert(level >= 0 && level <= n->level);

	// Still above level for insertion, go down tree recursively
	if (n->level > level)
	{
		i = RTreePickBranch(r, n);
		if (!RTreeInsertRect2(r, context, n->branch[i].child, &n2, level))
		{
			// child was not split
			//
			n->branch[i].rect = RTreeCombineRect(r,&(n->branch[i].rect));
			return 0;
		}
		else    // child was split
		{
			n->branch[i].rect = RTreeNodeCover(n->branch[i].child);
			b.child = n2;
			b.rect = RTreeNodeCover(n2);
			NSInteger result = RTreeAddBranch(&b, n, new_node);
			return result;
		}
	}
	else if (n->level == level) // Have reached level for insertion. Add rect, split if necessary
	{
		b.rect = *r;
		b.child = (Node *) context;
		/* child field of leaves contains tid of data record */
		NSInteger result = RTreeAddBranch(&b, n, new_node);
		return result;
	}
	else
	{
		/* Not supposed to happen */
		NSCParameterAssert (FALSE);
		return 0;
	}
}

////////////////////////////////////////////////////////////
// Insert a data rectangle into an index structure.
// RTreeInsertRect provides for splitting the root;
// returns 1 if root was split, 0 if it was not.
// The level argument specifies the number of steps up from the leaf
// level to insert; e.g. a data rectangle goes in at level = 0.
// RTreeInsertRect2 does the recursion.
NSInteger _RTreeInsertRect(RTreeRect *R, void *Context, Node **Root, NSInteger Level)
{
	register RTreeRect *r = R;
	register void *tid = Context;
	register Node **root = Root;
	register NSInteger level = Level;
	register NSInteger i;
	register Node *newroot;
	Node *newnode;
	Branch b;
	NSInteger result;

	NSCParameterAssert(r && root);
	NSCParameterAssert(level >= 0 && level <= (*root)->level);
	for (i=0; i<NUMDIMS; i++)
		NSCParameterAssert(r->boundary[i] <= r->boundary[NUMDIMS+i]);

	if (RTreeInsertRect2(r, tid, *root, &newnode, level))  /* root split */
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

////////////////////////////////////////////////////////////
// Add a node to the reinsertion list.  All its branches will later
// be reinserted into the index structure.
static void RTreeReInsert(Node *n, ListNode **ee)
{
	register ListNode *l;

	l = RTreeNewListNode();
	l->node = n;
	l->next = *ee;
	*ee = l;
}

////////////////////////////////////////////////////////////
// Delete a rectangle from non-root part of an index structure.
// Called by RTreeDeleteRect.  Descends tree recursively,
// merges branches on the way back up.
// Returns 1 if record not found, 0 if success.
static NSInteger RTreeDeleteRect2(RTreeRect *R, void *context, Node *N, ListNode **Ee)
{
	register RTreeRect *r = R;
	register void *tid = context;
	register Node *n = N;
	register ListNode **ee = Ee;
	register NSInteger i;

	NSCParameterAssert(r && n && ee);
	NSCParameterAssert(tid >= 0);
	NSCParameterAssert(n->level >= 0);

	if (n->level > 0)  // not a leaf node
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
						// not enough entries in child,
						// eliminate child node
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
	else  // a leaf node
	{
		for (i = 0; i < LEAFCARD; i++)
		{
			if (n->branch[i].child && n->branch[i].child == (Node *) context)
			{
				RTreeDisconnectBranch(n, i);
				return 0;
			}
		}
		
		return 1;
	}
}

////////////////////////////////////////////////////////////
// Delete a data rectangle from an index structure.
// Pass in a pointer to a RTreeRect, the tid of the record, ptr to ptr to root node.
// Returns 1 if record not found, 0 if success.
// RTreeDeleteRect provides for eliminating the root.
NSInteger _RTreeDeleteRect(RTreeRect *R, void *Context, Node**Nn)
{
	register RTreeRect *r = R;
	register void *tid = Context;
	register Node **nn = Nn;
	register NSInteger i;
	register Node *tmp_nptr;
	ListNode *reInsertList = NULL;
	register ListNode *e;

	NSCParameterAssert(r && nn);
	NSCParameterAssert(*nn);
	NSCParameterAssert(tid >= 0);

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
					_RTreeInsertRect(
						&(tmp_nptr->branch[i].rect),
						tmp_nptr->branch[i].child,
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
			NSCParameterAssert(tmp_nptr);
			RTreeFreeNode(*nn);
			*nn = tmp_nptr;
		}

		return 0;
	}

	return 1;
}
