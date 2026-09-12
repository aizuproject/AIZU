#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
// Every method and completion is confined to the main thread.
__attribute__((swift_attr("@MainActor")))
@interface DiscordBridge : NSObject
@property(class, nonatomic, readonly) BOOL available;
- (void)connectWithToken:(NSString *)token completion:(void (^)(NSError * _Nullable))completion NS_SWIFT_NAME(connect(token:completion:));
- (void)publishName:(NSString *)name details:(NSString *)details activityType:(NSInteger)activityType startedAt:(uint64_t)milliseconds
         largeImage:(nullable NSString *)image completion:(void (^)(NSError * _Nullable))completion
    NS_SWIFT_NAME(publish(name:details:activityType:startedAt:largeImage:completion:));
- (void)clearWithCompletion:(void (^)(NSError * _Nullable))completion NS_SWIFT_NAME(clear(completion:));
@property(nonatomic, readonly, nullable) NSString *connectionIssue;
- (void)disconnect;
@end
NS_ASSUME_NONNULL_END
