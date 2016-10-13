#import "VideoPlayerView.h"
#import "RCTRootView.h"
#import "VideoPlayerLayerView.h"

#define degreesToRadians(x) (M_PI * x / 180.0f)

NSString *kTracksKey		= @"tracks";
NSString *kPlayableKey		= @"playable";

static const NSString *ItemStatusContext;

static const CGFloat kStatusBarHeight = 20.f;

@interface VideoPlayerView ()

@property (nonatomic, retain) UIView *view;
@property (weak, nonatomic) UIView *contentView;

@property (nonatomic, strong) AVPlayer *avPlayer;
@property (nonatomic, strong) AVPlayerItem* playerItem;
@property (nonatomic, retain) NSDictionary *trackInformation;

@property (weak, nonatomic) IBOutlet VideoPlayerLayerView *playerView;
@property (weak, nonatomic) IBOutlet UIButton *fullScreenButton;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityView;
@property (weak, nonatomic) IBOutlet UIView *controlsOverlay;

@property (weak, nonatomic) IBOutlet UIView *portraitControlOverlay;
@property (weak, nonatomic) IBOutlet UIButton *portraintPlayButton;

@property (weak, nonatomic) IBOutlet UIView *landscapeControlOverlay;
@property (weak, nonatomic) IBOutlet UIButton *landscapePlayButton;

@property (nonatomic, assign) UIInterfaceOrientation visibleInterfaceOrientation;
@property (nonatomic, assign) BOOL isFullScreen;
@property (nonatomic, assign) CGRect landscapeFrame;
@property (nonatomic, assign) CGRect portraitFrame;
@end

@implementation VideoPlayerView
{
  UIView *_reactView;
}

- (instancetype)init
{
  if ((self = [super init])) {
    [self commonInit];
    [self addObservers];
  }
  return self;
  
}

- (void)dealloc{
  [self removeObservers];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  
  if (CGRectEqualToRect(self.portraitFrame, CGRectZero)) {
    self.contentView.frame = self.bounds;
    self.portraitFrame = self.frame;
    self.landscapeFrame = CGRectMake(0,
                                     0,
                                     self.superview.bounds.size.height,
                                     self.superview.bounds.size.width);
  }
}

- (void)commonInit {
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  UINib *nib = [UINib nibWithNibName:@"VideoPlayerView" bundle:bundle];
  NSArray *nibObjects = [nib instantiateWithOwner:self options:nil];
  _contentView = nibObjects[0];
  if (nil != self.contentView) {
    self.contentView.autoresizingMask =
      UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    [self addSubview:self.contentView];
    
    [self layoutControlsForOrientation:UIInterfaceOrientationPortrait];
  }
}

#pragma mark -- property accessor
- (void)setUrl:(NSString *)url {
  NSURL *videoUrl = [NSURL URLWithString:
                     [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
  if (nil != videoUrl) {
    [self setLoading:true];
    
    AVURLAsset *asset =
    [[AVURLAsset alloc] initWithURL:videoUrl
                            options:@{AVURLAssetPreferPreciseDurationAndTimingKey:
                                        @YES}];
    [asset loadValuesAsynchronouslyForKeys:@[kTracksKey, kPlayableKey]
                         completionHandler:^{
                           NSError *error = nil;
                           AVKeyValueStatus status = [asset statusOfValueForKey:kTracksKey
                                                                          error:&error];
                           if (AVKeyValueStatusLoaded == status) {
                             self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
                             self.avPlayer = [self playerWithPlayerItem:self.playerItem];
                             [self.playerView setPlayer:self.avPlayer];
                           } else {
                             
                           }
                         }];
  }
}

- (void)setPlayerItem:(AVPlayerItem *)playerItem {
  [_playerItem removeObserver:self forKeyPath:@"status"];
  [_playerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
  [_playerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_playerItem];
  _playerItem = playerItem;
  
  if (!playerItem) {
    return;
  }
  [_playerItem addObserver:self forKeyPath:@"status" options:0 context:&ItemStatusContext];
  [_playerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
  [_playerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)setAvPlayer:(AVPlayer *)avPlayer {
  [_avPlayer removeObserver:self forKeyPath:@"status"];
  _avPlayer = avPlayer;
  if (avPlayer) {
    [avPlayer addObserver:self forKeyPath:@"status" options:0 context:nil];
  }
}

#pragma mark - orientaion
typedef struct{
  CGRect viewBounds;
  CGRect statusBounds;
  CGRect parentBounds;
  CGPoint parentOrigin;
}RotateInfo;

- (RotateInfo)landscapeRotateInfo:(CGRect)mainBounds {
  
  RotateInfo landscapeRotateInfo = (RotateInfo){
    .viewBounds = CGRectMake(0,
                             0,
                             CGRectGetWidth(self.landscapeFrame),
                             CGRectGetHeight(self.landscapeFrame)),
    .statusBounds = CGRectMake(0,
                               0,
                               CGRectGetHeight(mainBounds),
                               kStatusBarHeight),
    .parentBounds = CGRectMake(0,
                               0,
                               CGRectGetHeight(mainBounds),
                               CGRectGetWidth(mainBounds)),
    .parentOrigin = CGPointMake(0, 0)
  };
  return landscapeRotateInfo;
}

- (RotateInfo)portraitRotateInfo:(CGRect)mainBounds {
  RotateInfo landscapeRotateInfo = (RotateInfo){
    .viewBounds = CGRectMake(0,
                             0,
                             CGRectGetWidth(self.portraitFrame),
                             CGRectGetHeight(self.portraitFrame)),
    .statusBounds = CGRectMake(0,
                               0,
                               CGRectGetWidth(mainBounds),
                               kStatusBarHeight),
    .parentBounds = mainBounds,
    .parentOrigin = self.portraitFrame.origin
  };
  return landscapeRotateInfo;
}

- (CGFloat)degreesForOrientation:(UIInterfaceOrientation)deviceOrientation {
    switch (deviceOrientation) {
        case UIInterfaceOrientationPortrait:
            return 0;
            break;
        case UIInterfaceOrientationLandscapeRight:
            return 90;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            return -90;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            return 180;
            break;
        default:
            break;
    }
    return 0;
}

- (void)rotate:(UIInterfaceOrientation)deviceOrientation {
  CGFloat degress = [self degreesForOrientation:deviceOrientation];
  CGFloat radians = degreesToRadians(degress);
  CGRect mainBounds = [[UIScreen mainScreen] bounds];
  RotateInfo rotateInfo;
  if (UIInterfaceOrientationIsLandscape(deviceOrientation)) {
    rotateInfo = [self landscapeRotateInfo:mainBounds];
  } else {
    rotateInfo = [self portraitRotateInfo:mainBounds];
  }
  self.superview.transform = CGAffineTransformMakeRotation(radians);
  self.superview.bounds = rotateInfo.parentBounds;
  self.superview.frame = CGRectMake(rotateInfo.parentOrigin.x,
                                         rotateInfo.parentOrigin.y,
                                         CGRectGetWidth(self.superview.frame),
                                         CGRectGetHeight(self.superview.frame));
  
  self.bounds = rotateInfo.viewBounds;
  self.frame = CGRectMake(0,
                          0,
                          CGRectGetWidth(self.frame),
                          CGRectGetHeight(self.frame));
}

-(void)layoutControlsForOrientation:(UIInterfaceOrientation)rotateOrientation {
  if (UIInterfaceOrientationIsLandscape(rotateOrientation)) {
    self.portraitControlOverlay.hidden = true;
    self.landscapeControlOverlay.hidden = false;
  } else {
    self.portraitControlOverlay.hidden = false;
    self.landscapeControlOverlay.hidden = true;
  }
}

- (void)orientationChanged:(NSNotification *)notification {
  UIInterfaceOrientation rotateOrientation = UIInterfaceOrientationPortrait;
  UIDevice *device = notification.object;
  if ([device isKindOfClass:[UIDevice class]]) {
    switch (device.orientation) {
      case UIDeviceOrientationPortrait:
        rotateOrientation = UIInterfaceOrientationPortrait;
        break;
      case UIDeviceOrientationLandscapeLeft:
        rotateOrientation = UIInterfaceOrientationLandscapeRight;
        break;
      case UIDeviceOrientationLandscapeRight:
        rotateOrientation = UIInterfaceOrientationLandscapeLeft;
        break;
      case UIDeviceOrientationPortraitUpsideDown:
        rotateOrientation = UIInterfaceOrientationPortrait;
        break;
      default:
        break;
    }
  }
  [self performOrientationChange:rotateOrientation];
}

- (void)performOrientationChange:(UIInterfaceOrientation)rotateOrientation {
  self.visibleInterfaceOrientation = rotateOrientation;
  
  [UIView animateWithDuration:0.3f animations:^{
    [self rotate:rotateOrientation];
  }];
  [self layoutControlsForOrientation:rotateOrientation];
}

#pragma mark - private function

- (BOOL)isPlaying {
  return (self.avPlayer && self.avPlayer.rate != 0.0);
}

- (void)playContent {
  [self.portraintPlayButton setSelected:true];
  [self.landscapePlayButton setSelected:true];
  [self.avPlayer play];
}

- (void)pauseContent {
  [self.portraintPlayButton setSelected:false];
  [self.landscapePlayButton setSelected:false];
  [self.avPlayer pause];
}

- (AVPlayer*)playerWithPlayerItem:(AVPlayerItem*)playerItem {
  AVPlayer* player = [AVPlayer playerWithPlayerItem:playerItem];
  if ([player respondsToSelector:@selector(setAllowsExternalPlayback:)]) {
    player.allowsExternalPlayback = NO; 
  }
  return player;
}

- (void)playerItemReadyToPlay {
  [self setLoading:false];
}

#pragma mark - Control Display
- (void)setLoading:(BOOL)loading {
  if (loading) {
    self.controlsOverlay.hidden = true;
    self.activityView.hidden = false;
    [self.activityView startAnimating];
  } else {
    self.controlsOverlay.hidden = false;
    self.activityView.hidden = true;
    [self.activityView stopAnimating];
  }
}

#pragma mark - Control Event
- (IBAction)playButtonClicked:(id)sender {
  if ([self isPlaying]) {
    [self pauseContent];
  } else {
    [self playContent];
  }
}

- (IBAction)fullButtonClicked:(id)sender {
  [self.fullScreenButton setSelected:!self.fullScreenButton.isSelected];
  self.isFullScreen = self.fullScreenButton.isSelected;
  
  if (self.isFullScreen) {
    [self performOrientationChange:UIInterfaceOrientationLandscapeRight];
  } else {
    [self performOrientationChange:UIInterfaceOrientationPortrait];
  }
}

#pragma mark - Player Observer
- (void)addObservers {
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter addObserver:self
                    selector:@selector(orientationChanged:)
                        name:UIDeviceOrientationDidChangeNotification
                      object:[UIDevice currentDevice]];
}

- (void)removeObservers {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object change:(NSDictionary *)change
                       context:(void *)context {
  if (object == self.avPlayer) {
    if ([keyPath isEqualToString:@"status"]) {
      switch ([self.avPlayer status]) {
        case AVPlayerStatusReadyToPlay:
          NSLog(@"AVPlayerStatusReadyToPlay");
          if (self.playerItem.status == AVPlayerItemStatusReadyToPlay) {
          }
          break;
        case AVPlayerStatusFailed:
          NSLog(@"AVPlayerStatusFailed");
        default:
          break;
      }
    }
  }
  
  if (object == self.playerItem) {
    if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
      NSLog(@"playbackBufferEmpty: %@",
            self.playerItem.isPlaybackBufferEmpty ? @"yes" : @"no");
    }
    if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
      NSLog(@"playbackLikelyToKeepUp: %@",
            self.playerItem.playbackLikelyToKeepUp ? @"yes" : @"no");
      if (self.playerItem.playbackLikelyToKeepUp) {
        
      }
    }
    if ([keyPath isEqualToString:@"status"]) {
      switch ([self.playerItem status]) {
        case AVPlayerItemStatusReadyToPlay:
          NSLog(@"AVPlayerItemStatusReadyToPlay");
          if ([self.avPlayer status] == AVPlayerStatusReadyToPlay) {
            AVMediaSelectionGroup *audioSelectionGroup =
            [[[self.avPlayer currentItem] asset]
             mediaSelectionGroupForMediaCharacteristic: AVMediaCharacteristicAudible];
            self.trackInformation = [NSDictionary dictionaryWithObjectsAndKeys:
                                     audioSelectionGroup,
                                     AVMediaCharacteristicAudible,
                                     nil];
            
            [self playerItemReadyToPlay];
          }
          break;
        case AVPlayerItemStatusFailed:
          NSLog(@"AVPlayerItemStatusFailed");
        default:
          break;
      }
    }
  }
}
@end
