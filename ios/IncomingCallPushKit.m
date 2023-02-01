#import <PushKit/PushKit.h>
#import "IncomingCallPushKit.h"

#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTUtils.h>

NSString *const IncomingCallRemoteNotificationsRegistered = @"voipRemoteNotificationsRegistered";
NSString *const IncomingCallRemoteNotificationReceived = @"voipRemoteNotificationReceived";

static NSString *RCTCurrentAppBackgroundState()
{
    static NSDictionary *states;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        states = @{
            @(UIApplicationStateActive): @"active",
            @(UIApplicationStateBackground): @"background",
            @(UIApplicationStateInactive): @"inactive"
        };
    });

    if (RCTRunningInAppExtension()) {
        return @"extension";
    }

    return states[@(RCTSharedApplication().applicationState)] ? : @"unknown";
}


@implementation IncomingCallPushKit

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;
static NSMutableDictionary<NSString *, IncomingCallPushNotificationCompletion> *completionHandlers = nil;

+ (NSMutableDictionary *)completionHandlers {
    if (completionHandlers == nil) {
        completionHandlers = [NSMutableDictionary new];
    }
    return completionHandlers;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // --- invoke complete() and remove for all completionHanders
    for (NSString *uuid in [IncomingCallPushKit completionHandlers]) {
        IncomingCallPushNotificationCompletion completion = [[IncomingCallPushKit completionHandlers] objectForKey:uuid];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    }

    [[IncomingCallPushKit completionHandlers] removeAllObjects];
}

- (void)setBridge:(RCTBridge *)bridge
{
    _bridge = bridge;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRemoteNotificationsRegistered:)
                                                 name:IncomingCallRemoteNotificationsRegistered
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRemoteNotificationReceived:)
                                                 name:IncomingCallRemoteNotificationReceived
                                               object:nil];
}

- (NSDictionary<NSString *, id> *)constantsToExport
{
    NSString *currentState = RCTCurrentAppBackgroundState();
    NSLog(@"[IncomingCallPushKit] constantsToExport currentState = %@", currentState);
    return @{@"wakeupByPush": ([currentState  isEqual: @"background"]) ? @"true" : @"false"};
}

- (void)registerUserNotification:(NSDictionary *)permissions
{
    UIUserNotificationType types = UIUserNotificationTypeNone;
    if (permissions) {
        if ([RCTConvert BOOL:permissions[@"alert"]]) {
            types |= UIUserNotificationTypeAlert;
        }
        if ([RCTConvert BOOL:permissions[@"badge"]]) {
            types |= UIUserNotificationTypeBadge;
        }
        if ([RCTConvert BOOL:permissions[@"sound"]]) {
            types |= UIUserNotificationTypeSound;
        }
    } else {
        types = UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound;
    }

    UIApplication *app = RCTSharedApplication();
    UIUserNotificationSettings *notificationSettings =
        [UIUserNotificationSettings settingsForTypes:(NSUInteger)types categories:nil];
    [app registerUserNotificationSettings:notificationSettings];
}

- (void)voipRegistration
{
    NSLog(@"[IncomingCallPushKit] voipRegistration");

    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    dispatch_async(mainQueue, ^{
      // Create a push registry object
      PKPushRegistry * voipRegistry = [[PKPushRegistry alloc] initWithQueue: mainQueue];
      // Set the registry's delegate to AppDelegate
      voipRegistry.delegate = (IncomingCallPushKit *)RCTSharedApplication().delegate;
      // Set the push type to VoIP
      voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    });
}

- (NSDictionary *)checkPermissions
{
    NSUInteger types = [RCTSharedApplication() currentUserNotificationSettings].types;

    return @{
        @"alert": @((types & UIUserNotificationTypeAlert) > 0),
        @"badge": @((types & UIUserNotificationTypeBadge) > 0),
        @"sound": @((types & UIUserNotificationTypeSound) > 0),
    };

}

+ (NSString *)getCurrentAppBackgroundState
{
    return RCTCurrentAppBackgroundState();
}

+ (void)didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type
{
    NSLog(@"[IncomingCallPushKit] didUpdatePushCredentials credentials.token = %@, type = %@", credentials.token, type);

    NSMutableString *hexString = [NSMutableString string];
    NSUInteger voipTokenLength = credentials.token.length;
    const unsigned char *bytes = credentials.token.bytes;
    for (NSUInteger i = 0; i < voipTokenLength; i++) {
        [hexString appendFormat:@"%02x", bytes[i]];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:IncomingCallRemoteNotificationsRegistered
                                                        object:self
                                                      userInfo:@{@"deviceToken" : [hexString copy]}];
}

+ (void)didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type
{
    NSLog(@"[IncomingCallPushKit] didReceiveIncomingPushWithPayload payload.dictionaryPayload = %@, type = %@", payload.dictionaryPayload, type);
    [[NSNotificationCenter defaultCenter] postNotificationName:IncomingCallRemoteNotificationReceived
                                                        object:self
                                                      userInfo:payload.dictionaryPayload];
}

- (void)handleRemoteNotificationsRegistered:(NSNotification *)notification
{
    NSLog(@"[IncomingCallPushKit] handleRemoteNotificationsRegistered notification.userInfo = %@", notification.userInfo);
    [_bridge.eventDispatcher sendDeviceEventWithName:@"voipRemoteNotificationsRegistered"
                                                body:notification.userInfo];
}



- (void)handleRemoteNotificationReceived:(NSNotification *)notification
{
    NSLog(@"[IncomingCallPushKit] handleRemoteNotificationReceived notification.userInfo = %@", notification.userInfo);
    [_bridge.eventDispatcher sendDeviceEventWithName:@"voipRemoteNotificationReceived"
                                                body:notification.userInfo];
}

+ (void)addCompletionHandler:(NSString *)uuid completionHandler:(IncomingCallPushNotificationCompletion)completionHandler
{
    self.completionHandlers[uuid] = completionHandler;
}

+ (void)removeCompletionHandler:(NSString *)uuid
{
    self.completionHandlers[uuid] = nil;
    [self.completionHandlers removeObjectForKey:uuid];
}

RCT_EXPORT_METHOD(onVoipNotificationCompleted:(NSString *)uuid)
{
    IncomingCallPushNotificationCompletion completion = [[IncomingCallPushKit completionHandlers] objectForKey:uuid];
    if (completion) {
        [IncomingCallPushKit removeCompletionHandler: uuid];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"[IncomingCallPushKit] onVoipNotificationCompleted() complete(). uuid = %@", uuid);
            completion();
        });
    } else {
        NSLog(@"[IncomingCallPushKit] onVoipNotificationCompleted() not found. uuid = %@", uuid);
    }
}

RCT_EXPORT_METHOD(requestPermissions:(NSDictionary *)permissions)
{
    if (RCTRunningInAppExtension()) {
        return;
    }
  dispatch_async(dispatch_get_main_queue(), ^{
    [self registerUserNotification:permissions];
  });
}

RCT_EXPORT_METHOD(registerVoipToken)
{
    if (RCTRunningInAppExtension()) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self voipRegistration];
    });
}

RCT_EXPORT_METHOD(checkPermissions:(RCTResponseSenderBlock)callback)
{
    if (RCTRunningInAppExtension()) {
        callback(@[@{@"alert": @NO, @"badge": @NO, @"sound": @NO}]);
        return;
    }

    callback(@[[self checkPermissions]]);
}



+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

@end