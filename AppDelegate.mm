//
//  AppDelegate.mm
//  SSHLoginNotifier
//
//  Created by Ben Jones on 1/24/15.
//  Copyright (c) 2015 Ben Jones. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

-(void)showNotification:(NSString*)title
            withMessage:(NSString*)message {
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title               = title;
    notification.informativeText     = message;
    notification.soundName           = NSUserNotificationDefaultSoundName;
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
        std::string stdUser([user UTF8String]);
        auto it = _users.find(stdUser);
        if(it == _users.end()) { // not found, so add
            _users.insert(stdUser);
            
            NSMutableString* message = [[NSMutableString alloc] init];
            [message appendString:@"User "];
            [message appendString:user];
            [message appendString:@" has logged in."];
            
            [self showNotification:@"Logged in event" withMessage:message];
        }
    }
}

- (void)checkForLoggedOut:(NSArray*) users {
    // strip out those that no longer exist
    std::set<std::string> comparison;
    for(NSString* user in users) {
        std::string stdUser([user UTF8String]);
        NSLog(@"User: %@", user);
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
            [self showNotification:@"Logged out event" withMessage:message];
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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    [self performSelectorInBackground:@selector(checkForNewUser) withObject:nil];
    
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
