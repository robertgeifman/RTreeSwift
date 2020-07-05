#import "RTreeIndexImpl.h"
#import "RTreeCard.h"

////////////////////////////////////////////////////////////
NSInteger NODECARD = MAXCARD;
NSInteger LEAFCARD = MAXCARD;

////////////////////////////////////////////////////////////
static NSInteger set_max(NSInteger *which, NSInteger new_max)
{
	if(2 > new_max || new_max > MAXCARD)
		return 0;
	*which = new_max;
	return 1;
}

NSInteger RTreeSetNodeMax(NSInteger new_max) 
{ 
	return set_max(&NODECARD, new_max); 
}

NSInteger RTreeSetLeafMax(NSInteger new_max) 
{ 
	return set_max(&LEAFCARD, new_max); 
}

NSInteger RTreeGetNodeMax() 
{ 
	return NODECARD; 
}

NSInteger RTreeGetLeafMax() 
{ 
	return LEAFCARD; 
}
