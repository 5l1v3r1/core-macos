/*
 * RCSMac - Download File Network Operation
 *
 *
 * Created by revenge on 12/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>
#import "NetworkOperation.h"
#import "RESTTransport.h"


@interface DownloadNetworkOperation : NSObject <NetworkOperation>
{
@private
  RESTTransport *mTransport;
  NSMutableArray *mDownloads;
}

@property (readonly, getter=getDownloads) NSMutableArray *mDownloads;

- (id)initWithTransport: (RESTTransport *)aTransport;
- (void)dealloc;

@end