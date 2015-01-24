//
//  AppDelegate.mm
//  SSHLoginNotifier
//
//  Created by Ben Jones on 1/24/15.
//  Copyright (c) 2015 Ben Jones. All rights reserved.
//

#import "AppDelegate.h"
#import <Collaboration/Collaboration.h>

@implementation AppDelegate


-(NSImage *)userImage:(NSString*)username
{
    CBIdentity *identity = [CBIdentity identityWithName:username authority:[CBIdentityAuthority defaultIdentityAuthority]];
    return [identity image];
}

-(void)showNotification:(NSString*)title
            withMessage:(NSString*)message
            whereUserIs:(NSString*)user
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title               = title;
    notification.informativeText     = message;
    notification.soundName           = NSUserNotificationDefaultSoundName;
    notification.contentImage        = [self userImage:user];
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

-(NSString*)getLoggedOnUsers {
    
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/users";
    task.standardOutput = pipe;
    
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    return [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    
}

- (void)checkForLoggedIn:(NSArray*) users {
    for(NSString* user in users) {
        
        NSString* strippedUser = user;
        if ([self endsWithCharacter: L'\n'
                          forString: strippedUser]) {
            strippedUser = [user substringToIndex:[user length]-1];
        }
        
        std::string stdUser([strippedUser UTF8String]);
        auto it = _users.find(stdUser);
        if(it == _users.end()) { // not found, so add
            _users.insert(stdUser);
            
            NSMutableString* message = [[NSMutableString alloc] init];
            [message appendString:@"User "];
            [message appendString:strippedUser];
            [message appendString:@" has logged in."];
            
            [self showNotification:@"Logged in event"
                       withMessage:message
                       whereUserIs:strippedUser];
        }
    }
}

- (void)checkForLoggedOut:(NSArray*) users {
    // strip out those that no longer exist
    std::set<std::string> comparison;
    for(NSString* user in users) {
        NSString* strippedUser = user;
        if ([self endsWithCharacter: L'\n'
                          forString: strippedUser]) {
            strippedUser = [user substringToIndex:[user length]-1];
        }
        std::string stdUser([strippedUser UTF8String]);
        NSLog(@"User: %@", strippedUser);
        comparison.insert(stdUser);
    }
    
    // check if those that used to exist no longer exist
    auto itr = _users.begin();
    while (itr != _users.end())
    {
        if(comparison.find(*itr) == comparison.end()) {
            NSString *nsUser = [NSString stringWithCString:(*itr).c_str()
                                                  encoding:[NSString defaultCStringEncoding]];
            
            NSMutableString* message = [[NSMutableString alloc] init];
            [message appendString:@"User "];
            [message appendString:nsUser];
            [message appendString:@" has logged off."];
            [self showNotification:@"Logged out event"
                       withMessage:message
                       whereUserIs:nsUser];
            itr = _users.erase(itr);
        } else {
            ++itr;
        }
    }
}

- (void)checkForNewUser {
    
    // Acquire list of logged on users
    while(1) {
        NSString *loggedOnUsers = [self getLoggedOnUsers];
        NSArray *users = [loggedOnUsers componentsSeparatedByString: @" "];
        [self checkForLoggedIn:users];
        [self checkForLoggedOut:users];
        sleep(5);
    }
}

- (BOOL) endsWithCharacter: (unichar) c
                 forString: (NSString*)str
{
    NSUInteger length = [str length];
    return (length > 0) && ([str characterAtIndex: length - 1] == c);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    [self performSelectorInBackground:@selector(checkForNewUser) withObject:nil];
    
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
