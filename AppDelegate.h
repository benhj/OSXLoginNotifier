//
//  AppDelegate.h
//  SSHLoginNotifier
//
//  Created by Ben Jones on 1/24/15.
//  Copyright (c) 2015 Ben Jones. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include <set>
#include <string>

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    std::set<std::string> _users;
}

-(NSImage *)userImage:(NSString*)username;
-(void)showNotification:(NSString*)title
            withMessage:(NSString*)message
            whereUserIs:(NSString*)user;
-(NSString*)getLoggedOnUsers;
- (void)checkForLoggedIn:(NSArray*) users;
- (void)checkForLoggedOut:(NSArray*) users;
- (void)checkForNewUser;

@end

