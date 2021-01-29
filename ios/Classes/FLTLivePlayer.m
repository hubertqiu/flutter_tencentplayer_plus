//
//  FLTVideoPlayer.m
//  flutter_plugin_demo3
//
//  Created by Wei on 2019/5/15.
//

#import "FLTLivePlayer.h"
#import <libkern/OSAtomic.h>



@implementation FLTLivePlayer{
//    CVPixelBufferRef finalPiexelBuffer;
//    CVPixelBufferRef pixelBufferNowRef;
    CVPixelBufferRef volatile _latestPixelBuffer;
    CVPixelBufferRef _lastBuffer;
}

- (instancetype)initWithCall:(FlutterMethodCall *)call frameUpdater:(FLTFrameUpdater *)frameUpdater registry:(NSObject<FlutterTextureRegistry> *)registry messenger:(NSObject<FlutterBinaryMessenger>*)messenger{
    self = [super init];
    _latestPixelBuffer = nil;
     _lastBuffer = nil;
    // NSLog(@"FLTVideo  初始化播放器");
    _textureId = [registry registerTexture:self];
    // NSLog(@"FLTVideo  _textureId %lld",_textureId);
    
    FlutterEventChannel* eventChannel = [FlutterEventChannel
                                         eventChannelWithName:[NSString stringWithFormat:@"flutter_tencentplayer/videoEvents%lld",_textureId]
                                         binaryMessenger:messenger];
    
   
    
    _eventChannel = eventChannel;
    [_eventChannel setStreamHandler:self];
    NSDictionary* argsMap = call.arguments;
    TXLivePlayConfig* playConfig = [[TXLivePlayConfig alloc]init];
    playConfig.connectRetryCount=  3 ;
    playConfig.connectRetryInterval = 3;
    //自动模式
    playConfig.bAutoAdjustCacheTime   = YES;
    playConfig.minAutoAdjustCacheTime = 1;
    playConfig.maxAutoAdjustCacheTime = 5;
//    //极速模式
//    playConfig.bAutoAdjustCacheTime   = YES;
//    playConfig.minAutoAdjustCacheTime = 1;
//    playConfig.maxAutoAdjustCacheTime = 1;
//    //流畅模式
//    playConfig.bAutoAdjustCacheTime   = NO;
//    playConfig.minAutoAdjustCacheTime = 5;
//    playConfig.maxAutoAdjustCacheTime = 5;
    
//**  vodplayer start
//    id headers = argsMap[@"headers"];
//    if (headers!=nil&&headers!=NULL&&![@"" isEqualToString:headers]&&headers!=[NSNull null]) {
//        NSDictionary* headers =  argsMap[@"headers"];
//        playConfig.headers = headers;
//    }
//
//    id cacheFolderPath = argsMap[@"cachePath"];
//    if (cacheFolderPath!=nil&&cacheFolderPath!=NULL&&![@"" isEqualToString:cacheFolderPath]&&cacheFolderPath!=[NSNull null]) {
//        playConfig.cacheFolderPath = cacheFolderPath;
//        playConfig.maxCacheItems = 20;
//    }else{
//        // 设置缓存路径
//        playConfig.cacheFolderPath =[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
//        playConfig.maxCacheItems = 10;
//    }
//
//
//    //[argsMap[@"progressInterval"] intValue] ;
//    BOOL autoPlayArg = [argsMap[@"autoPlay"] boolValue];
//    float startPosition=0;
//
//    id startTime = argsMap[@"startTime"];
//    if(startTime!=nil&&startTime!=NULL&&![@"" isEqualToString:startTime]&&startTime!=[NSNull null]){
//        startPosition =[argsMap[@"startTime"] floatValue];
//    }
    
//**  vodplayer end
    
    frameUpdater.textureId = _textureId;
    _frameUpdater = frameUpdater;
    
    _txLivePlayer = [[TXLivePlayer alloc]init];
    [playConfig setPlayerPixelFormatType:kCVPixelFormatType_32BGRA];
    [_txLivePlayer setConfig:playConfig];
    _txLivePlayer.enableHWAcceleration = YES;
    [_txLivePlayer setDelegate:self];
    [_txLivePlayer setVideoProcessDelegate:self];

    NSString*  url = argsMap[@"uri"];
    int  play_type = [argsMap[@"play_type"] intValue];
    [_txLivePlayer startPlay:url type:(TX_Enum_PlayType)play_type];
    NSLog(@"播放器初始化结束");
    
    return  self;
    
}


#pragma FlutterTexture
- (CVPixelBufferRef)copyPixelBuffer {
    CVPixelBufferRef pixelBuffer = _latestPixelBuffer;
       while (!OSAtomicCompareAndSwapPtrBarrier(pixelBuffer, nil,
                                                (void **)&_latestPixelBuffer)) {
           pixelBuffer = _latestPixelBuffer;
       }
       return pixelBuffer;
}

#pragma 腾讯播放器代理回调方法
- (BOOL)onPlayerPixelBuffer:(CVPixelBufferRef)pixelBuffer{
    
    if (_lastBuffer == nil) {
        _lastBuffer = CVPixelBufferRetain(pixelBuffer);
        CFRetain(pixelBuffer);
    } else if (_lastBuffer != pixelBuffer) {
        CVPixelBufferRelease(_lastBuffer);
        _lastBuffer = CVPixelBufferRetain(pixelBuffer);
        CFRetain(pixelBuffer);
    }

    CVPixelBufferRef newBuffer = pixelBuffer;

    CVPixelBufferRef old = _latestPixelBuffer;
    while (!OSAtomicCompareAndSwapPtrBarrier(old, newBuffer,
                                             (void **)&_latestPixelBuffer)) {
        old = _latestPixelBuffer;
    }

    if (old && old != pixelBuffer) {
        CFRelease(old);
    }
    [self.frameUpdater refreshDisplay];
    return NO;
}

/**
 * 点播事件通知
 *
 * @param player 点播对象
 * @param EvtID 参见TXLiveSDKEventDef.h
 * @param param 参见TXLiveSDKTypeDef.h
 * @see TXVodPlayer
 */
-(void)onPlayEvent:(TXVodPlayer *)player event:(int)EvtID withParam:(NSDictionary *)param{
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if(EvtID==PLAY_EVT_PLAY_BEGIN){
           if(self->_eventSink!=nil){
               self->_eventSink(@{
                   @"event":@"playbegin",
               });
           }
        }else if(EvtID==PLAY_EVT_CHANGE_RESOLUTION){
            if(self->_eventSink!=nil){
                self->_eventSink(@{
                    @"event":@"changeresolution",
                    @"width":[param objectForKey:@"EVT_PARMA1"],
                    @"height":[param objectForKey:@"EVT_PARMA2"]
                });
            }
         }else if(EvtID==PLAY_EVT_PLAY_PROGRESS){
           if(self->_eventSink!=nil){
               self->_eventSink(@{
                   @"event":@"progress"
               });
           }
        }else if(EvtID==PLAY_EVT_PLAY_LOADING){
            if(self->_eventSink!=nil){
                self->_eventSink(@{
                    @"event":@"loading",
                });
            }
            
        }else if(EvtID==PLAY_EVT_PLAY_END){
            if(self->_eventSink!=nil){
                self->_eventSink(@{
                    @"event":@"playend",
                });
            }
            
        }else if(EvtID==PLAY_WARNING_RECV_DATA_LAG){
            if(self->_eventSink!=nil){
                self->_eventSink(@{
                    @"event":@"lag_warning",
                });
            }
            
        }else if(EvtID==PLAY_WARNING_VIDEO_PLAY_LAG){
            if(self->_eventSink!=nil){
                self->_eventSink(@{
                    @"event":@"lag_warning",
                });
            }
            
        }else if(EvtID==PLAY_WARNING_RECONNECT){
            if(self->_eventSink!=nil){
                self->_eventSink(@{
                    @"event":@"lag_warning",
                });
            }
        }else if(EvtID==PLAY_WARNING_VIDEO_DISCONTINUITY){
            if(self->_eventSink!=nil){
                self->_eventSink(@{
                    @"event":@"lag_warning",
                });
            }
        }else if(EvtID==PLAY_ERR_NET_DISCONNECT){
            if(self->_eventSink!=nil){
                self->_eventSink(@{
                    @"event":@"error",
                    @"errorInfo":param[@"EVT_MSG"],
                });
            }
        }else if(EvtID==WARNING_LIVE_STREAM_SERVER_RECONNECT){
            if(self->_eventSink!=nil){
                self->_eventSink(@{
                    @"event":@"error",
                    @"errorInfo":param[@"EVT_MSG"],
                });
            }
        }else {
            if(EvtID<0){
                if(self->_eventSink!=nil){
                    self->_eventSink(@{
                        @"event":@"error",
                        @"errorInfo":param[@"EVT_MSG"],
                    });
                }
            }
        }
        
    });
}

- (void)onNetStatus:(TXVodPlayer *)player withParam:(NSDictionary *)param {
    if(self->_eventSink!=nil){
        self->_eventSink(@{
            @"event":@"netStatus",
            @"netSpeed": param[NET_STATUS_NET_SPEED],
            @"cacheSize": param[NET_STATUS_V_SUM_CACHE_SIZE],
        });
    }
}

#pragma FlutterStreamHandler
- (FlutterError* _Nullable)onCancelWithArguments:(id _Nullable)arguments {
    _eventSink = nil;
    NSLog(@"FLTVideo   停止通信");
    return nil;
}

- (FlutterError* _Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(nonnull FlutterEventSink)events {
    _eventSink = events;
    
    NSLog(@"FLTVideo   开启通信");
    //[self sendInitialized];
    return nil;
}

- (void)dispose {
    _disposed = true;
    [self stopPlay];
    [_txLivePlayer removeVideoWidget];
    _txLivePlayer = nil;
    _frameUpdater = nil;
     NSLog(@"FLTVideo  dispose");
    CVPixelBufferRef old = _latestPixelBuffer;
       while (!OSAtomicCompareAndSwapPtrBarrier(old, nil,
                                                (void **)&_latestPixelBuffer)) {
           old = _latestPixelBuffer;
       }
       if (old) {
           CFRelease(old);
       }

       if (_lastBuffer) {
           CVPixelBufferRelease(_lastBuffer);
           _lastBuffer = nil;
       }
    
//    if(_eventChannel){
//        [_eventChannel setStreamHandler:nil];
//        _eventChannel =nil;
//    }
    
}

-(void)setLoop:(BOOL)loop{
    //
}

- (void)resume{
    [_txLivePlayer resume];
}

-(void)pause{
    [_txLivePlayer pause];
}

- (int64_t)position{
    return 0;
}

- (int64_t)duration{
    return 0;
}

- (void)seekTo:(int)position{
    [_txLivePlayer seek:position];
}

- (void)setStartTime:(CGFloat)startTime{
//
    
}

- (int)stopPlay{
    return [_txLivePlayer stopPlay];
}

- (float)playableDuration{
    return 0;
}

- (int)width{
    return 0;
}

- (int)height{
    return 0;
}

- (void)setRenderMode:(TX_Enum_Type_RenderMode)renderMode{
    [_txLivePlayer setRenderMode:renderMode];
}

- (void)setRenderRotation:(TX_Enum_Type_HomeOrientation)rotation{
    
    [_txLivePlayer setRenderRotation:rotation];
}

- (void)setMute:(BOOL)bEnable{
    [_txLivePlayer setMute:bEnable];
}




- (void)setRate:(float)rate{
//
    
}

- (void)setBitrateIndex:(int)index{
    //
}

- (void)setMirror:(BOOL)isMirror{
    //
}

-(void)snapshot:(void (^)(UIImage * _Nonnull))snapshotCompletionBlock{
    
}
@end
