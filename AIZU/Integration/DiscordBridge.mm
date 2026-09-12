#import "DiscordBridge.h"
#import <UIKit/UIKit.h>
#if PRESENCE_DISCORD_SDK
#define DISCORDPP_IMPLEMENTATION
#include <discord_partner_sdk/discordpp.h>
#include <memory>
#endif

static NSError *PresenceError(NSString *message) {
    return [NSError errorWithDomain:@"AIZU.Discord" code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

#if PRESENCE_DISCORD_SDK
// Numeric SDK diagnostics only; do not expose response bodies or auth values.
static NSError *SDKFailure(NSString *stage, const discordpp::ClientResult &result) {
    return PresenceError([NSString stringWithFormat:@"%@ · 유형 %d / HTTP %d / 코드 %d",
        stage, (int)result.Type(), (int)result.Status(), result.ErrorCode()]);
}
#endif

@implementation DiscordBridge {
    NSTimer *_pump;
    NSTimer *_timeout;
    void (^_pending)(NSError *);
    NSUInteger _operation;
    NSString *_appliedToken;
    NSString *_lastConnectionIssue;
#if PRESENCE_DISCORD_SDK
    std::shared_ptr<discordpp::Client> _client;
#endif
}
+ (BOOL)available {
#if PRESENCE_DISCORD_SDK
    return YES;
#else
    return NO;
#endif
}
- (void)finish:(NSError *)error operation:(NSUInteger)operation {
    if (_operation != operation || !_pending) return;
    [_timeout invalidate]; _timeout = nil;
    void (^callback)(NSError *) = _pending;
    _pending = nil;
    callback(error);
}
- (NSUInteger)begin:(void (^)(NSError *))completion {
    NSAssert([NSThread isMainThread], @"DiscordBridge requires the main thread");
    _operation++;
    _pending = [completion copy];
    NSUInteger operation = _operation;
    __weak DiscordBridge *weakSelf = self;
    _timeout = [NSTimer scheduledTimerWithTimeInterval:15 repeats:NO block:^(NSTimer *timer) {
        [weakSelf finish:PresenceError(@"Discord 응답 시간이 초과되었습니다. 연결을 확인해 주세요.") operation:operation];
    }];
    return operation;
}
- (void)connectWithToken:(NSString *)token completion:(void (^)(NSError *))completion {
#if PRESENCE_DISCORD_SDK
    if (_client && _client->GetStatus() == discordpp::Client::Status::Ready && [_appliedToken isEqualToString:token]) { completion(nil); return; }
    [self disconnect];
    _appliedToken = [token copy];
    _client = std::make_shared<discordpp::Client>();
    NSUInteger operation = [self begin:completion];
    __weak DiscordBridge *weakSelf = self;
    _pump = [NSTimer timerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) { discordpp::RunCallbacks(); }];
    _pump.tolerance = 0.02;
    [[NSRunLoop mainRunLoop] addTimer:_pump forMode:NSRunLoopCommonModes];
    _client->SetStatusChangedCallback([weakSelf, operation](discordpp::Client::Status status, discordpp::Client::Error error, int32_t detail) {
        DiscordBridge *ownerForStatus = weakSelf;
        if (ownerForStatus) ownerForStatus->_lastConnectionIssue = nil;
        if (status != discordpp::Client::Status::Ready) {
            DiscordBridge *owner = weakSelf;
            if (owner) owner->_lastConnectionIssue = [NSString stringWithFormat:@"Discord 연결 변경 · 상태 %d / 오류 %d / 상세 %d", (int)status, (int)error, detail];
        }
        if (status == discordpp::Client::Status::Ready) { [weakSelf finish:nil operation:operation]; }
        else if (status == discordpp::Client::Status::Disconnected && error != discordpp::Client::Error::None) {
            [weakSelf finish:PresenceError([NSString stringWithFormat:@"Discord 연결 실패 · 상태 %d / 오류 %d / 상세 %d", (int)status, (int)error, detail]) operation:operation];
        }
    });
    std::weak_ptr<discordpp::Client> weakClient = _client;
    _client->UpdateToken(discordpp::AuthorizationTokenType::Bearer, std::string(token.UTF8String),
        [weakSelf, weakClient, operation](discordpp::ClientResult result) {
            if (!result.Successful()) { [weakSelf finish:SDKFailure(@"Discord 토큰 적용 실패", result) operation:operation]; return; }
            if (auto client = weakClient.lock()) client->Connect();
        });
#else
    completion(PresenceError(@"Discord Social SDK 파일이 필요합니다. 설정의 연결 준비 안내를 확인해 주세요."));
#endif
}
- (void)publishName:(NSString *)name details:(NSString *)details activityType:(NSInteger)activityType startedAt:(uint64_t)milliseconds
         largeImage:(NSString *)image completion:(void (^)(NSError *))completion {
#if PRESENCE_DISCORD_SDK
    if (!_client || _client->GetStatus() != discordpp::Client::Status::Ready) {
        completion(PresenceError(@"Discord 연결이 준비되지 않았습니다.")); return;
    }
    NSUInteger operation = [self begin:completion];
    discordpp::Activity activity;
    switch (activityType) {
        case 2: activity.SetType(discordpp::ActivityTypes::Listening); break;
        case 3: activity.SetType(discordpp::ActivityTypes::Watching); break;
        default: activity.SetType(discordpp::ActivityTypes::Playing); break;
    }
    activity.SetName(std::string(name.UTF8String));
    if (details.length) activity.SetDetails(std::string(details.UTF8String));
    activity.SetState(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone ? "iPhone" : "iPad");
    if (milliseconds > 0) {
        discordpp::ActivityTimestamps timestamps;
        timestamps.SetStart(milliseconds);
        activity.SetTimestamps(timestamps);
    }
    if (image.length) {
        discordpp::ActivityAssets assets;
        assets.SetLargeImage(std::string(image.UTF8String));
        activity.SetAssets(assets);
    }
    __weak DiscordBridge *weakSelf = self;
    _client->UpdateRichPresence(activity, [weakSelf, operation](discordpp::ClientResult result) {
        [weakSelf finish:result.Successful() ? nil : SDKFailure(@"Discord 활동 게시 실패", result) operation:operation];
    });
#else
    completion(PresenceError(@"Discord Social SDK가 이 빌드에 포함되지 않았습니다."));
#endif
}
- (void)clearWithCompletion:(void (^)(NSError *))completion {
#if PRESENCE_DISCORD_SDK
    if (!_client || _client->GetStatus() != discordpp::Client::Status::Ready) {
        completion(PresenceError(@"이전 활동 해제를 위해 Discord에 다시 연결해 주세요.")); return;
    }
    _client->ClearRichPresence();
    // The SDK has no acknowledgement callback. Report only request dispatch,
    // not remote visibility. Give its event loop a bounded opportunity to flush.
    NSUInteger operation = [self begin:completion];
    __weak DiscordBridge *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 350 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [weakSelf finish:nil operation:operation];
    });
#else
    completion(PresenceError(@"이전 활동 해제에는 Discord Social SDK가 필요합니다."));
#endif
}
- (NSString *)connectionIssue {
#if PRESENCE_DISCORD_SDK
    if (_client && _client->GetStatus() == discordpp::Client::Status::Ready) return nil;
#endif
    return _lastConnectionIssue ?: @"Discord 연결이 끊겨 다시 연결합니다.";
}
- (void)disconnect {
    _appliedToken = nil;
    [_pump invalidate]; _pump = nil;
    [_timeout invalidate]; _timeout = nil;
#if PRESENCE_DISCORD_SDK
    if (_client) { _client->Disconnect(); _client.reset(); }
#endif
    if (_pending) {
        void (^callback)(NSError *) = _pending; _pending = nil;
        callback(PresenceError(@"Discord 연결 작업이 종료되었습니다. 다음 실행 때 다시 확인합니다."));
    }
}
@end
