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
            
            // log to file if file
            [self writeLog:strippedUser withStatus:@"in"];
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
            
            // log to file if file
            [self writeLog:nsUser withStatus:@"out"];
            
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
    _statusItem.button.title = @"";
    _statusItem.button.toolTip = @"OSXLoginNotifier";
    NSImage* img = [NSImage imageNamed:@"statusBarIcon"];
    [img setTemplate:YES];
    _statusItem.button.image = img;
    
    // Menu stuff
    NSMenu *menu = [[NSMenu alloc] init];
    
    // For popping up a dialog of where user want email notifications
    // to be delivered
    [menu addItemWithTitle:@"Email notifications to.."
                    action:@selector(processSetEmailAddress:)
             keyEquivalent:@""];
    
    // For logging of activity to a file
    [menu addItemWithTitle:@"Log activity to.."
                    action:@selector(processLogTo:)
             keyEquivalent:@""];
    
    [menu addItem:[NSMenuItem separatorItem]]; // A thin grey line
    
    // Add a simple 'about' item
    [menu addItemWithTitle:@"About"
                    action:@selector(frontAbout:)
             keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]]; // A thin grey line
    
    // Add an exit item to exit program
    [menu addItemWithTitle:@"Exit"
                    action:@selector(processExit:)
             keyEquivalent:@""];
    _statusItem.menu = menu;
    
    // listen to workspace activation / inactivation event
    [[[NSWorkspace sharedWorkspace] notificationCenter]
     addObserver:self
     selector:@selector(switchHandler:)
     name:NSWorkspaceSessionDidBecomeActiveNotification
     object:nil];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter]
     addObserver:self
     selector:@selector(switchHandler:)
     name:NSWorkspaceSessionDidResignActiveNotification
     object:nil];
    

    // Continuously check for unix style logins / logouts
    [self performSelectorInBackground:@selector(checkUsers) withObject:nil];
    
}

- (void)processExit:(id)sender {
    [NSApp terminate: nil];
}

- (void)processSetEmailAddress:(id)sender {
    _emailAddress = [self input:@"Enter email address"
                   defaultValue:(_emailAddress ? _emailAddress : @"username@domain.com") ];
    
    if(_emailAddress) {
        // send a test email
        Emailer *emailer = [[Emailer alloc] init];
        [emailer sendEmail:@"Email registration"
               withMessage:@"You have registered this email address to receive notifications"
                 toAddress:_emailAddress];
    }
}

- (void)processLogTo:(id)sender {
    _fileString = [self input:@"Enter full file path"
                 defaultValue:(_fileString ? _fileString : @"~/loginActivity.log")];
    if(_fileString) {
        [[NSFileManager defaultManager] createFileAtPath:_fileString contents:nil attributes:nil];
    }
}

-(void)frontAbout:(id)sender{
    
    [NSApp activateIgnoringOtherApps:YES];
    
    [NSApp orderFrontStandardAboutPanel:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    // TODO
}

- (void)writeLog: (NSString*)user
      withStatus: (NSString*)status {
    if(_fileString) {
        // get current date and time
        NSDate * now = [NSDate date];
        NSDateFormatter *outputFormatter = [[NSDateFormatter alloc] init];
        [outputFormatter setDateFormat:@"yyyy-MM-dd hh:mm:ss"];
        NSString *newDateString = [outputFormatter stringFromDate:now];
        NSMutableString *str = [[NSMutableString alloc] init];
        [str appendString:user];
        [str appendString:@" "];
        [str appendString:status];
        [str appendString:@" "];
        [str appendString:newDateString];
        [str appendString:@"\n"];
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:_fileString];
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    }
}

- (NSString *)input: (NSString *)prompt
       defaultValue: (NSString *)defaultValue {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:prompt];
    [alert addButtonWithTitle:@"Ok"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [input setStringValue:defaultValue];
    [alert setAccessoryView:input];
    NSInteger button = [alert runModal];
    if (button == NSAlertFirstButtonReturn) {
        [input validateEditing];
        return [input stringValue];
    } else if (button == NSAlertSecondButtonReturn) {
        return _emailAddress ? _emailAddress : nil;
    } else {
        return nil;
    }
}

- (void) switchHandler:(NSNotification*) notification
{
    if ([[notification name] isEqualToString:
         NSWorkspaceSessionDidResignActiveNotification]) {
        if(_emailAddress) {
            Emailer *emailer = [[Emailer alloc] init];
            NSMutableString* message = [[NSMutableString alloc] init];
            [message appendString:@"Workspace became inactive for user "];
            [message appendString:NSUserName()];
            [emailer sendEmail:@"Workspace inactive notification"
                   withMessage:message
                     toAddress:_emailAddress];
        }
        // log to file if file
        [self writeLog:NSUserName() withStatus:@"I"];
    } else {
        if(_emailAddress) {
            Emailer *emailer = [[Emailer alloc] init];
            NSMutableString* message = [[NSMutableString alloc] init];
            [message appendString:@"Workspace became active for user "];
            [message appendString:NSUserName()];
            [emailer sendEmail:@"Workspace active notification"
                   withMessage:message
                     toAddress:_emailAddress];
        }
        // log to file if file
        [self writeLog:NSUserName() withStatus:@"A"];
    }
}

@end
