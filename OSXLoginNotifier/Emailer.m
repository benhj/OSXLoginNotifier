//
//  Emailer.m
//  OSXLoginNotifier
//
//  Created by Ben Jones on 1/26/15.
//  Copyright (c) 2015 Ben Jones. All rights reserved.
//

#import "Emailer.h"

@implementation Emailer

-(void)sendEmail:(NSString*)subject
     withMessage:(NSString*)message
       toAddress:(NSString*)address {
    
    // redirect stdin to input pipe file handle
    NSPipe *inputPipe = [NSPipe pipe];
    dup2([[inputPipe fileHandleForReading] fileDescriptor], STDIN_FILENO);
    NSFileHandle *inputFile = inputPipe.fileHandleForWriting;
    
    // message data to send
    NSMutableString* theMessage = [[NSMutableString alloc] init];
    [theMessage appendString:@"From: "];
    [theMessage appendString:@"OSXLoginNotifier"];
    [theMessage appendString:@"\n"];
    [theMessage appendString:@"Subject: "];
    [theMessage appendString:subject];
    [theMessage appendString:@"\n\n"];
    [theMessage appendString:message];
    [theMessage appendString:@"\n"];
    [theMessage appendString:@"."];
    NSData* data = [theMessage dataUsingEncoding:NSUTF8StringEncoding];
    NSTask* task = [[NSTask alloc] init];
    NSString* command = @"/usr/sbin/sendmail";
    NSArray* args = [NSArray arrayWithObjects:address,nil];
    
    task.launchPath = command;
    task.arguments = args;
    task.standardInput = inputPipe;
    
    [task launch];
    
    // write data to input pipe and close
    [inputFile writeData:data];
    [inputFile closeFile];

}

@end
