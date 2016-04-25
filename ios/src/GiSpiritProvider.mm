// GiSpiritProvider.mm
// Copyright (c) 2014-2016 Zhang Yungui, https://github.com/rhcad/vgplay (GPL v3 licensed)

#import "GiSpiritProvider.h"
#import "GiImageCache.h"
#include "gicoreplay.h"

@interface GiSpiritProvider() {
    int     _visible;
    MgShape *_playingShape;
    MgShape *_newShape;
}

@end

@implementation GiSpiritProvider

@synthesize owner, imageCache, currentName, format, name;
@synthesize frameCount, repeatCount, delay, tag;
@synthesize frameIndex = _frameIndex;

- (void)dealloc {
    MgObject::release_pointer(_newShape);
    [super DEALLOC];
}

- (NSString *)currentName {
    return [NSString stringWithFormat:self.format, _frameIndex];
}

- (NSString *)name {
    return [NSString stringWithFormat:@"%d$png:%@", self.tag, self.format];
}

+ (GiSpiritProvider *)findSpirit:(NSString *)format :(int)tag :(NSArray *)spirits {
    for (GiSpiritProvider *spirit : spirits) {
        if (spirit.owner == spirits && spirit.tag == tag
            && [spirit.format isEqualToString:format]) {
            return spirit;
        }
    }
    return nil;
}

- (void)onBackDocChanged:(GiFrame)frame {
    MgShapes* backShapes = MgShapes::fromHandle(frame.backShapes);
    int sid = frame.tag & ~SPIRIT_TAG;
    const MgShape* sp = backShapes->findShape(sid);
    
    _visible = sp ? 1 : -1;
    if (sp) {
        if (_newShape) {
            long changeCount = _newShape->shapec()->getChangeCount();
            if (sp->shapec()->getChangeCount() != changeCount) {
                _newShape->release();
                _newShape = sp->cloneShape();
            }
        } else {
            _newShape = sp->cloneShape();
        }
    }
}

- (void)beforeSubmitShapes:(GiFrame)frame {
    MgShapes* shapes = MgShapes::fromHandle(frame.shapes);
    bool hide = _visible < 0;
    
    if (_newShape && shapes->updateShape(_newShape, true)) {
        _playingShape = _newShape;
        _playingShape->shape()->setFlag(kMgHideContent, hide);
        _newShape = NULL;
    }
    else if (_playingShape && _visible != 0) {
        _playingShape->shape()->setFlag(kMgHideContent, hide);
    }
    _visible = 0;
    [self.imageCache setCurrentImage:self.name newName:self.currentName];
}

- (BOOL)initProvider:(GiFrame *)frame {
    MgShapes* backShapes = MgShapes::fromHandle(frame->backShapes);
    MgShapes* shapes = MgShapes::fromHandle(frame->shapes);
    int sid = frame->tag & ~SPIRIT_TAG;
    const MgShape* sp = backShapes->findShape(sid);
    
    _playingShape = sp ? shapes->addShape(*sp) : NULL;
    if (_playingShape) {
        _playingShape->shape()->setFlag(kMgHideContent, false);
    }
    
    return !!_playingShape;
}

- (int)provideFrame:(GiFrame)frame {
    int index = frame.tick / self.delay % self.frameCount;
    
    if (_visible != 0) {
        return 1;
    }
    if (_playingShape && _frameIndex != index
        && !_playingShape->shapec()->getFlag(kMgHideContent)) {
        _frameIndex = index;
        return 1;
    }
    return 0;
}

- (void)onProvideEnded:(GiFrame)frame {
    if (self.owner) {
        [self.owner removeObject:self];
        self.owner = nil;
    }
    [self.imageCache setCurrentImage:self.name newName:nil];
    [self RELEASEOBJ];
}

@end
