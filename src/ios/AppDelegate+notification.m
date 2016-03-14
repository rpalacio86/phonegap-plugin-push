//
//  AppDelegate+notification.m
//  pushtest
//
//  Created by Robert Easterday on 10/26/12.
//
//

#import "AppDelegate+notification.h"
#import "PushPlugin.h"
#import <objc/runtime.h>

static char launchNotificationsKey;

@implementation AppDelegate (notification)

- (id) getCommandInstance:(NSString*)className
{
    return [self.viewController getCommandInstance:className];
}

// its dangerous to override a method from within a category.
// Instead we will use method swizzling. we set this up in the load call.
+ (void)load
{
    Method original, swizzled;

    original = class_getInstanceMethod(self, @selector(init));
    swizzled = class_getInstanceMethod(self, @selector(swizzled_init));
    method_exchangeImplementations(original, swizzled);
}

- (AppDelegate *)swizzled_init
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createNotificationChecker:)
                                                 name:@"UIApplicationDidFinishLaunchingNotification" object:nil];

    // This actually calls the original init method over in AppDelegate. Equivilent to calling super
    // on an overrided method, this is not recursive, although it appears that way. neat huh?
    return [self swizzled_init];
}

// This code will be called immediately after application:didFinishLaunchingWithOptions:. We need
// to process notifications in cold-start situations
- (void)createNotificationChecker:(NSNotification *)notification
{
    if (notification)
    {
        NSDictionary *launchOptions = [notification userInfo];
        if (launchOptions)
            [self addLaunchNotification:[launchOptions objectForKey: @"UIApplicationLaunchOptionsRemoteNotificationKey"]];
    }
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    PushPlugin *pushHandler = [self getCommandInstance:@"PushNotification"];
    [pushHandler didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    PushPlugin *pushHandler = [self getCommandInstance:@"PushNotification"];
    [pushHandler didFailToRegisterForRemoteNotificationsWithError:error];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    NSLog(@"didReceiveNotification with fetchCompletionHandler");

    // app is in the foreground so call notification callback
    if (application.applicationState == UIApplicationStateActive) {
        NSLog(@"app active");
        PushPlugin *pushHandler = [self getCommandInstance:@"PushNotification"];
        pushHandler.notificationMessage = userInfo;
        pushHandler.isInline = YES;
        [pushHandler notificationReceived];

        completionHandler(UIBackgroundFetchResultNewData);
    }
    // app is in background or in stand by
    else {
        NSLog(@"app in-active");
        //save it for later
        [self addLaunchNotification:userInfo];

        completionHandler(UIBackgroundFetchResultNewData);
    }
}

- (BOOL)userHasRemoteNotificationsEnabled {
    UIApplication *application = [UIApplication sharedApplication];
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        return application.currentUserNotificationSettings.types != UIUserNotificationTypeNone;
    } else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        return application.enabledRemoteNotificationTypes != UIRemoteNotificationTypeNone;
#pragma GCC diagnostic pop
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {

    NSLog(@"active");

    PushPlugin *pushHandler = [self getCommandInstance:@"PushNotification"];
    if (pushHandler.clearBadge) {
        NSLog(@"PushPlugin clearing badge");
        //zero badge
        application.applicationIconBadgeNumber = 0;
    } else {
        NSLog(@"PushPlugin skip clear badge");
    }

    if ([self.launchNotifications count] > 0) {
        for (NSDictionary *launchNotification in self.launchNotifications) {
          pushHandler.isInline = NO;
          pushHandler.notificationMessage = launchNotification;
          [pushHandler performSelectorOnMainThread:@selector(notificationReceived) withObject:pushHandler waitUntilDone:NO];
        }
        self.launchNotifications = nil;
    }
}


- (void)application:(UIApplication *) application handleActionWithIdentifier: (NSString *) identifier
forRemoteNotification: (NSDictionary *) notification completionHandler: (void (^)()) completionHandler {

    NSLog(@"Push Plugin handleActionWithIdentifier %@", identifier);

    if ([self.launchNotifications count] > 0) {
        for (NSDictionary *launchNotification in self.launchNotifications) {
          pushHandler.isInline = NO;
          pushHandler.notificationMessage = launchNotification;
          [pushHandler notificationReceived];
        }
        self.launchNotifications = nil;
    }
    // Must be called when finished
    completionHandler();
}

// The accessors use an Associative Reference since you can't define a iVar in a category
// http://developer.apple.com/library/ios/#documentation/cocoa/conceptual/objectivec/Chapters/ocAssociativeReferences.html
- (NSMutableArray *)obtenerLaunchNotifications
{
    return objc_getAssociatedObject(self, &launchNotificationsKey);
}

- (void)dealloc
{
    self.launchNotifications = nil; // clear the association and release the object
}

- (void)addLaunchNotification:(NSDictionary *)notification
{
  [[self launchNotifications] addObject:notification];
}

- (void)setLaunchNotifications:(NSMutableArray *)launchNotifications
{
  objc_setAssociatedObject(self, &launchNotificationsKey, launchNotifications, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableArray *)launchNotifications
{
  if (![self obtenerLaunchNotifications]) {
    [self setLaunchNotifications:[[NSMutableArray alloc]initWithCapacity:1]];
  }
  return [self obtenerLaunchNotifications];
}

@end
