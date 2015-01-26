//
//  Emailer.h
//  OSXLoginNotifier
//
//  Created by Ben Jones on 1/26/15.
//  Copyright (c) 2015 Ben Jones. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Emailer : NSSharingService

-(void)sendEmail:(NSString*)subject
     withMessage:(NSString*)message
       toAddress:(NSString*)address;

@end
