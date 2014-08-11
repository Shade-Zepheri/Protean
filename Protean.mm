#import "Protean.h"
#import "headers.h"
#import <UIKit/UIKit.h>
#import <libactivator/libactivator.h>
#import <objcipc/objcipc.h>
#import "PRStatusApps.h"

@interface UIApplication (Protean)
-(id) statusBar;
@end
@interface UIStatusBar
-(void)setShowsOnlyCenterItems:(BOOL)arg1;
- (void)crossfadeTime:(BOOL)arg1 duration:(double)arg2;
@end
@interface BSQRController /* BiteSMS */
+(BOOL)maybeLaunchQRFromURL:(id)url;
+(void)markAsReadFromBulletin:(id)bulletin;
+(BOOL)canLaunchQRFromBulletin:(id)bulletin;
+(BOOL)maybeLaunchQRFromBulletin:(id)bulletin;
+(BOOL)launchQRFromMessage:(id)message;
+(BOOL)receivedBulletin:(id)bulletin;
+(void)receivedFZMessage:(id)message inGroup:(id)group addresses:(id)addresses;
+(BOOL)_handleReceivedMessage:(id)message;
+(void)_showQR:(id)qr;
@end
@interface UIImage (Protean)
+ (UIImage*)imageNamed:(NSString *)imageName inBundle:(NSBundle*)bundle;
- (UIImage*) _flatImageWithColor: (UIColor*) color;
+(UIImage*)kitImageNamed:(NSString*)name;
@end

extern "C" CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void);

#define PLIST_NAME @"/var/mobile/Library/Preferences/com.efrederickson.protean.settings.plist"

//based on http://iphonedevwiki.net/index.php/Libactivator#Dispatching_Events
inline LAEvent *LASendEventWithName(NSString *eventName) {
	LAEvent *event = [LAEvent eventWithName:eventName mode:[LASharedActivator currentEventMode]];
	[LASharedActivator sendEventToListener:event];
	return event;
}
inline LAEvent *LASendEventToListener(NSString *listener) {
	LAEvent *event = [LAEvent eventWithName:@"com.efrederickson.protean.dummy_event" mode:[LASharedActivator currentEventMode]];
	[LASharedActivator sendEvent:event toListenerWithName:listener];
	return event;
}

NSMutableDictionary *LSBitems = [NSMutableDictionary dictionary];
NSMutableArray *mappedIdentifiers = [NSMutableArray array];
int LSBitems_index = 33;

NSDictionary *prefs = nil;

NSMutableDictionary *storedBulletins = [NSMutableDictionary dictionary];

@implementation Protean

+(NSDictionary*) getOrLoadSettings
{
    if (!prefs)
    {
        prefs = [[NSDictionary dictionaryWithContentsOfFile:PLIST_NAME] retain];
        if (prefs == nil)
            prefs = [[NSMutableDictionary dictionary] retain];
    }
    
    
    return prefs;
}

+(BOOL) canHandleTapForItem:(UIStatusBarItem*)item
{
    int type = MSHookIvar<int>(item, "_type");
    
    if (type <= 32) // System item
    {
        if (type == 5)
        {
            return YES;
        }
        
        NSString *ident = [NSString stringWithFormat:@"%d", type];
        
        id mode1 = [Protean getOrLoadSettings][@"tapActions"][ident];
        int mode = mode1 ? [mode1 intValue] : 0;
        
        if (mode == 0)
            return NO;
        else if (mode == 2)
        {
            return YES;
        }
        else
            NSLog(@"[Protean] invalid IconTap action for system item: %d", mode);
    }
    else
    {
        NSString *ident = [Protean mappedIdentifierForItem:type];
        if ([ident hasPrefix:@"com.efrederickson.protean-"])
            ident = [ident substringFromIndex:26];
        
        id mode1 = [Protean getOrLoadSettings][@"tapActions"][ident];
        int mode = mode1 ? [mode1 intValue] : 0;
        
        if (mode == 1 || mode == 2 || mode == 3)
            return YES;
    }
    
    return NO;
}

+(id) HandlerForTapOnItem:(UIStatusBarItem*)item
{
    int type = MSHookIvar<int>(item, "_type");
    
    if (type <= 32) // System item
    {
        /*if (type == 5)
        {
            LASendEventToListener(@"com.pigigaldi.vestigo");
        }*/
        
        NSString *ident = [NSString stringWithFormat:@"%d", type];
        
        id mode1 = [Protean getOrLoadSettings][@"tapActions"][ident];
        int mode = mode1 ? [mode1 intValue] : 0;
        
        if (mode == 0)
            return nil;
        else if (mode == 2)
        {
            // Activator
            LASendEventWithName([NSString stringWithFormat:@"com.efrederickson.protean-%@",ident]);
        }
        else
            NSLog(@"[Protean] invalid IconTap action for system item: %d", mode);
            
    }
    else
    {
        NSString *ident = [Protean mappedIdentifierForItem:type];
        if ([ident hasPrefix:@"com.efrederickson.protean-"])
            ident = [ident substringFromIndex:26];
        
        id mode1 = [Protean getOrLoadSettings][@"tapActions"][ident];
        int mode = mode1 ? [mode1 intValue] : 0;
        
        if (mode == 0)
        {
            return nil;
        }
        else if (mode == 1)
        {
            // Open application
            
            __strong NSDictionary *userInfo = @{@"appId": ident};
            CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), CFSTR("com.efrederickson.protean/launchApp"), nil, (__bridge CFDictionaryRef)userInfo, YES);
        }
        else if (mode == 2)
        {
            // Activator
            LASendEventWithName([NSString stringWithFormat:@"com.efrederickson.protean-%@",ident]);
        }
        else if (mode == 3)
        {
            // Quick Reply
            
            if ([[[NSBundle mainBundle] bundleIdentifier] isEqual:@"com.apple.springboard"] == NO)
                [OBJCIPC sendMessageToSpringBoardWithMessageName:@"com.efrederickson.protean/launchQR" dictionary:@{ @"appId":ident}];
            else
                [Protean launchQR:ident];
        }
        else
            NSLog(@"[Protean] invalid IconTap action: %d", mode);
    }
    
    return nil;
}

+(void) mapIdentifierToItem:(NSString*)identifier
{
    if ([mappedIdentifiers containsObject:identifier])
        return;
    LSBitems[[NSNumber numberWithInt:LSBitems_index++]] = [identifier retain];
    [mappedIdentifiers addObject:identifier];
}

+(void) mapIdentifierToItem:(NSString*)identifier item:(int)type
{
    if ([mappedIdentifiers containsObject:identifier])
        return;
    LSBitems[[NSNumber numberWithInt:type]] = [identifier retain];
    [mappedIdentifiers addObject:identifier];
}

+(NSString*) mappedIdentifierForItem:(int)type
{
    return LSBitems[[NSNumber numberWithInt:type]];
}

+(NSString*)imageNameForIdentifier:(NSString*)identifier
{
    static NSBundle *imageBundle;
    if (!imageBundle) imageBundle = [[NSBundle bundleWithPath:@"/Library/Protean/Images.bundle"] retain];
    
    NSDictionary *dict = [Protean getOrLoadSettings];
    NSString *ret = dict[@"images"][identifier];
    if (ret == nil) return nil;
    
    if ([UIImage imageNamed:[NSString stringWithFormat:@"PR_%@",ret] inBundle:imageBundle])
        return [NSString stringWithFormat:@"PR_%@",ret];
    if ([UIImage kitImageNamed:[NSString stringWithFormat:@"Black_ON_%@",ret]])
        return [NSString stringWithFormat:@"ON_%@",ret];
        
    return ret;
}

+(NSString*)imageNameForIdentifier:(NSString*)identifier withBadgeCount:(int)count
{
    static NSBundle *imageBundle;
    if (!imageBundle) imageBundle = [[NSBundle bundleWithPath:@"/Library/Protean/Images.bundle"] retain];
    
    NSString *baseName = [Protean imageNameForIdentifier:identifier];
    if (!baseName)
        return nil;
    
    if ([UIImage imageNamed:[NSString stringWithFormat:@"%@_Count_%d",baseName,count] inBundle:imageBundle])
        return [NSString stringWithFormat:@"%@_Count_%d",baseName,count];
    else if ([UIImage imageNamed:[NSString stringWithFormat:@"%@_Count_Large",baseName] inBundle:imageBundle])
        return [NSString stringWithFormat:@"%@_Count_Large",baseName];
    else if ([UIImage kitImageNamed:[NSString stringWithFormat:@"Black_ON_Count%d_%@",count>9?10:count,baseName]])
        return [NSString stringWithFormat:@"ON_Count%d_%@",count>9?10:count,baseName];
        
    return baseName;
}

+(void) addBulletin:(BBBulletin*)bulletin forApp:(NSString*)appId
{
    // We are obviously SpringBoard
    
    storedBulletins[appId] = storedBulletins[appId] ?: [NSMutableArray array];
    [(NSMutableArray*)storedBulletins[appId] insertObject:bulletin atIndex:0];
}

+(void) launchQR:(NSString*)app
{
    // Launch QR here
    
    if (!storedBulletins[app] || [storedBulletins[app] count] == 0)
        return;
    
    __strong BBBulletin* bulletin = [[storedBulletins[app] objectAtIndex:0] copy];
    [storedBulletins[app] removeObjectAtIndex:0];
    
    if (!bulletin)
        return;
    
    if ([app isEqual:@"com.apple.MobileSMS"])
    {
        // Auki
        id auki = objc_getClass("KJUARR");
        if (auki)
        {
            [auki doUrThing:bulletin];
            return;
        }
        
        // BiteSMS
        id bitesms = objc_getClass("BSQRController");
        if (bitesms)
        {
            [bitesms maybeLaunchQRFromBulletin:bulletin];
            return;
        }
    }
    
    id couria = objc_getClass("Couria");
    if (couria)
    {
        [[couria sharedInstance] handleBulletin:bulletin];
    }
}

+(void) clearBulletinsForApp:(NSString*)appId
{
    storedBulletins[appId] = [NSMutableArray array];
}
@end

BOOL first = YES;
void reloadSettings(CFNotificationCenterRef center,
                    void *observer,
                    CFStringRef name,
                    const void *object,
                    CFDictionaryRef userInfo)
{
    if (prefs)
        [prefs release];
    prefs = nil;
    [Protean getOrLoadSettings];
    if (!first)
        [PRStatusApps reloadAllImages];
    else
        first = NO;
}

static __attribute__((constructor)) void __protean_init()
{
    if ([[[NSBundle mainBundle] bundleIdentifier] isEqual:@"com.apple.springboard"] == NO)
    {
        [OBJCIPC sendMessageToSpringBoardWithMessageName:@"com.efrederickson.protean/requestUpdate" dictionary:nil replyHandler:^(NSDictionary *response) {
            LSBitems = [response mutableCopy];
        }];
    }
    else
    {
        [OBJCIPC registerIncomingMessageFromAppHandlerForMessageName:@"com.efrederickson.protean/requestUpdate"  handler:^NSDictionary *(NSDictionary *message) {
            return LSBitems;
        }];
        
        
        [OBJCIPC registerIncomingMessageFromAppHandlerForMessageName:@"com.efrederickson.protean/refreshStatusBar"  handler:^NSDictionary *(NSDictionary *message) {
            UIStatusBar *statusBar = (UIStatusBar *)[[UIApplication sharedApplication] statusBar];
            [statusBar setShowsOnlyCenterItems:YES];
            [statusBar setShowsOnlyCenterItems:NO];
            
            CGFloat animationDuration = 0.6;
            [statusBar crossfadeTime:NO duration:animationDuration];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, animationDuration * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [statusBar crossfadeTime:YES duration:animationDuration];
            });
            
            return @{};
        }];
        
        
        [OBJCIPC registerIncomingMessageFromAppHandlerForMessageName:@"com.efrederickson.protean/launchQR"  handler:^NSDictionary *(NSDictionary *message) {
            NSString *app = message[@"appId"];
            if (app)
                [Protean launchQR:app];
            return nil;
        }];
        
    }
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(), NULL, &reloadSettings, CFSTR("com.efrederickson.protean/reloadSettings"), NULL, 0);
    reloadSettings(NULL, NULL, NULL, NULL, NULL);
}