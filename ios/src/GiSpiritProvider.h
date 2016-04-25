// GiSpiritProvider.h
// Copyright (c) 2014-2016 Zhang Yungui, https://github.com/rhcad/vgplay (GPL v3 licensed)

#import <UIKit/UIKit.h>
#import "GiPlayProvider.h"

@class GiImageCache;

@interface GiSpiritProvider : NSObject<GiPlayProvider>

@property(nonatomic, assign) NSMutableArray *owner;
@property(nonatomic, assign) GiImageCache   *imageCache;
@property(nonatomic, readonly)  NSString    *currentName;
@property(nonatomic, readonly)  int         frameIndex;
@property(nonatomic, readonly)  NSString    *name;
@property(nonatomic, copy)  NSString        *format;
@property(nonatomic)        int             frameCount;
@property(nonatomic)        int             repeatCount;
@property(nonatomic)        int             delay;
@property(nonatomic)        int             tag;

+ (GiSpiritProvider *)findSpirit:(NSString *)format :(int)tag :(NSArray *)spirits;

@end
