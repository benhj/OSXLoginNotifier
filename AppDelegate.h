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
    NSStatusItem *_statusItem;
    NSString *_emailAddress;
}

/// Get a user's full name
-(NSString*)fullName:(NSString*)username;

/// Get the image associated with the user
-(NSImage*)userImage:(NSString*)username;

/// Pop up a notification displaying log in or log out event
-(void)showNotification:(NSString*)title
            withMessage:(NSString*)message
            whereUserIs:(NSString*)user;

/// Get space-separated list of logged in users
-(NSString*)getLoggedOnUsers;

/// Check for new users since last update
- (void)checkForLoggedIn:(NSArray*) users;

/// Check for users that have logged out since last update
- (void)checkForLoggedOut:(NSArray*) users;

/// Check for logged in and logged out users 
- (void)checkUsers;

/// When user selects exit in status menu
- (void)processExit:(id)sender;

/// For setting email address
- (void)processSetEmailAddress:(id)sender;

/// For handling when desktop becomes active / inactive
- (void)switchHandler:(NSNotification*) notification;

/// Brings and about dialog to front
- (void)frontAbout:(id)sender;

@end

