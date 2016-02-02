//
//  ALHTTPRequest.h
//  ALPA
//
//  Created by Denis Dovgan on 12/17/15.
//  Copyright © 2015 Factorial Complexity. All rights reserved.
//

typedef enum : NSUInteger {
    ALRequestTypePOST,
    ALRequestTypeGET,
    ALRequestTypePUT,
	ALRequestTypeDELETE,
	ALRequestTypePATCH
} ALRequestType;

typedef enum : NSUInteger {
    ALRequestSerializerTypeDEFAULT = 0,
    ALRequestSerializerTypeJSON
} ALRequestSerializerType;

@protocol ALHTTPRequest <NSObject>

@required
- (void)start;
- (void)cancel;

- (BOOL)running;
- (BOOL)finished;

@end
