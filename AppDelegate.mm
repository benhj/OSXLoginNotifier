//
//  AppDelegate.mm
//  SSHLoginNotifier
//
//  Created by Ben Jones on 1/24/15.
//  Copyright (c) 2015 Ben Jones. All rights reserved.
//

#import "AppDelegate.h"
#import "Emailer.h"
#import <Collaboration/Collaboration.h>

@implementation AppDelegate


-(NSString *)fullName:(NSString*)username {
    CBIdentity *identity = [CBIdentity identityWithName:username authority:[CBIdentityAuthority defaultIdentityAuthority]];
    return identity.fullName;
}

-(NSImage *)userImage:(NSString*)username
{
    CBIdentity *identity = [CBIdentity identityWithName:username authority:[CBIdentityAuthority defaultIdentityAuthority]];
    return [identity image];
}

- (BOOL) endsWithCharacter: (unichar) c
                 forString: (NSString*)str
{
    NSUInteger length = [str length];
    return (length > 0) && ([str characterAtIndex: length - 1] == c);
}

-(void)showNotification:(NSString*)title
            withMessage:(NSString*)message
            whereUserIs:(NSString*)user {
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
            [message appendString:[self fullName:strippedUser]];
            [message appendString:@" (username "];
            [message appendString:strippedUser];
            [message appendString:@")"];
            [message appendString:@"\nhas logged in."];
            
            [self showNotification:@"Logged in event"
                       withMessage:message
                       whereUserIs:strippedUser];
            
            // send email if email address has been set
            if(_emailAddress) {
                Emailer *emailer = [[Emailer alloc] init];
                [emailer sendEmail:@"User logged in event"
                       withMessage:message
                         toAddress:_emailAddress];
            }
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
        //NSLog(@"User: %@", strippedUser);
        comparison.insert(stdUser);
    }
    
    // check if those that used to exist no longer exist
    auto itr = _users.begin();
    while (itr != _users.end())
    {
        if(comparison.find(*itr) == comparison.end()) {
            NSString *nsUser = [NSString stringWithCString:(*itr).c_str()
                                                  encoding:[NSString defaultCStringEncoding]];
            
            itr = _users.erase(itr);
            
            NSMutableString* message = [[NSMutableString alloc] init];
            [message appendString:[self fullName:nsUser]];
            [message appendString:@" (username "];
            [message appendString:nsUser];
            [message appendString:@")"];
            [message appendString:@"\nhas logged off."];
            [self showNotification:@"Logged out event"
                       withMessage:message
                       whereUserIs:nsUser];
            
            // send email if email address has been set
            if(_emailAddress) {
                Emailer *emailer = [[Emailer alloc] init];
                [emailer sendEmail:@"User logged out event"
                       withMessage:message
                         toAddress:_emailAddress];
            }
            
        } else {
            ++itr;
        }
    }
}

- (void)checkUsers {
    
    // Poll for user log-in / log-out event
    while(1) {
        NSString *loggedOnUsers = [self getLoggedOnUsers];
        NSArray *users = [loggedOnUsers componentsSeparatedByString: @" "];
        [self checkForLoggedIn:users];
        [self checkForLoggedOut:users];
        sleep(5);
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    // Set up the icon that is displayed in the status bar
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.title = @"";
    _statusItem.toolTip = @"OSXLoginNotifier";
    _statusItem.image = [NSImage imageNamed:@"statusItemImage"];
    _statusItem.alternateImage = [NSImage imageNamed:@"statusItemImage"];
    _statusItem.highlightMode = YES;
    
    // Menu stuff
    NSMenu *menu = [[NSMenu alloc] init];
    
    // For popping up a dialog of where user want email notifications
    // to be delivered
    [menu addItemWithTitle:@"Email notifications to.."
                    action:@selector(processSetEmailAddress:)
             keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]]; // A thin grey line
    
    // Add a simple 'about' item
    [menu addItemWithTitle:@"About"
                    action:@selector(orderFrontStandardAboutPanel:)
             keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]]; // A thin grey line
    
    // Add an exit item to exit program
    [menu addItemWithTitle:@"Exit"
                    action:@selector(processExit:)
             keyEquivalent:@""];
    _statusItem.menu = menu;

    // Continuously check for user stats; launches a loop that
    // polls every 5 seconds
    [self performSelectorInBackground:@selector(checkUsers) withObject:nil];
    
}

- (void)processExit:(id)sender {
    [NSApp terminate: nil];
}

- (void)processSetEmailAddress:(id)sender {
    _emailAddress = [self input:@"Enter email address"
                   defaultValue:@"username@domain.com"];
    
    if(_emailAddress) {
        // send a test email
        Emailer *emailer = [[Emailer alloc] init];
        [emailer sendEmail:@"Email registration"
               withMessage:@"You have registered this email address to receive notifications"
                 toAddress:_emailAddress];
    }
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    // TODO
}

- (NSString *)input: (NSString *)prompt
       defaultValue: (NSString *)defaultValue {
    NSAlert *alert = [NSAlert alertWithMessageText: prompt
                                     defaultButton:@"OK"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:@""];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [input setStringValue:defaultValue];
    [alert setAccessoryView:input];
    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        [input validateEditing];
        return [input stringValue];
    } else if (button == NSAlertAlternateReturn) {
        return nil;
    } else {
        return nil;
    }
}

@end
