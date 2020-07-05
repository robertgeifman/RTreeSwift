extern NSInteger NODECARD;
extern NSInteger LEAFCARD;

/* balance criteria for node splitting */
/* NOTE: can be changed if needed. */
#define MinNodeFill (NODECARD / 2)
#define MinLeafFill (LEAFCARD / 2)

#define MAXKIDS(n) ((n)->level > 0 ? NODECARD : LEAFCARD)
#define MINFILL(n) ((n)->level > 0 ? MinNodeFill : MinLeafFill)
