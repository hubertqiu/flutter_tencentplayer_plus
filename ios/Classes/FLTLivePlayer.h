//
//  FLTVideoPlayer.h
//  flutter_plugin_demo3
//
//  Created by Wei on 2019/5/15.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <GLKit/GLKit.h>
#import "FLTFrameUpdater.h"
#import "TXLiteAVSDK.h"
#import <Flutter/Flutter.h>
#import "FLTPlayerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLTLivePlayer : NSObject<FlutterTexture, FlutterStreamHandler,TXVideoCustomProcessDelegate,TXLivePlayListener, FLTPlayerProtocol>
@property(readonly,nonatomic) TXLivePlayer* txLivePlayer;
@property(nonatomic) FlutterEventChannel* eventChannel;

//ios主动和flutter通信
@property(nonatomic) FlutterEventSink eventSink;
@property(nonatomic, readonly) bool disposed;
@property(nonatomic, readonly) int64_t textureId;

/**
 * 是否循环播放
 */
@property (nonatomic, assign) BOOL loop;
@property(nonatomic)FLTFrameUpdater* frameUpdater;

@end

NS_ASSUME_NONNULL_END
