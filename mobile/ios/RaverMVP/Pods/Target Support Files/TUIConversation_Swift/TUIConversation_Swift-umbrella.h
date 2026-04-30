#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "TUIConversationServiceLoader.h"
#import "TUIConversationServiceLoader_Minimalist.h"

FOUNDATION_EXPORT double TUIConversationVersionNumber;
FOUNDATION_EXPORT const unsigned char TUIConversationVersionString[];

