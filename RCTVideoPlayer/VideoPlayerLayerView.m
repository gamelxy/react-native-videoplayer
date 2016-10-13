//
//  VideoPlayerLayerView.m
//  videoPlayerExample
//
//  Created by 陈欢 on 2016/10/12.
//  Copyright © 2016年 Facebook. All rights reserved.
//

#import "VideoPlayerLayerView.h"

@implementation VideoPlayerLayerView

+ (Class)layerClass {
  return [AVPlayerLayer class];
}

- (void)setPlayer:(AVPlayer *)player {
  [(AVPlayerLayer *)[self layer] setPlayer:player];
}

@end
