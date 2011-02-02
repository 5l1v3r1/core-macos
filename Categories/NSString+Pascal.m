//
//  NSString+Pascal.m
//  RCSMac
//
//  Created by revenge on 1/24/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NSString+Pascal.h"


@implementation NSString (PascalExtension)

- (NSData *)pascalizeToData
{
  int len = [self length];
  NSMutableData *stringData = [[NSMutableData alloc] init];
  len *= 2; // UTF16
  len += 2; // null terminator
  [stringData appendBytes: &len
                   length: sizeof(int)];
  
  [stringData appendData: [self dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  
  short unicodeNullTerminator = 0x0000;
  [stringData appendBytes: &unicodeNullTerminator
                   length: sizeof(short)];
  
  return [stringData autorelease];
}

@end